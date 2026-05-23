#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_query import FieldFilter


ROOT_DIR = Path(__file__).resolve().parents[2]
ENV_DIR = ROOT_DIR / "env"
DEFAULT_MAX_NIGHTS = 7
STALE_SKIP_WARNING = (
    "[candidates] no candidates generated; skipped stale marking to avoid hiding existing data"
)


@dataclass(frozen=True)
class CalendarDay:
    date_key: str
    available: bool
    points: int
    cash_krw: int
    krw_per_point: float | None
    source_run_id: str
    year_key: str
    day_key: str


@dataclass(frozen=True)
class Candidate:
    candidate_id: str
    hotel_id: str
    check_in: date
    nights: int
    payload: dict[str, Any]


class BatchWriter:
    def __init__(self, db: firestore.Client, dry_run: bool, batch_size: int = 450) -> None:
        self.db = db
        self.dry_run = dry_run
        self.batch_size = batch_size
        self._batch = db.batch()
        self._pending = 0
        self.write_count = 0

    def set(self, ref: firestore.DocumentReference, data: dict[str, Any], *, merge: bool = True) -> None:
        self.write_count += 1
        if self.dry_run:
            return
        self._batch.set(ref, data, merge=merge)
        self._pending += 1
        if self._pending >= self.batch_size:
            self.commit()

    def commit(self) -> None:
        if self.dry_run or self._pending == 0:
            return
        self._batch.commit()
        self._batch = self.db.batch()
        self._pending = 0


def find_default_service_account() -> Path:
    candidates = [
        *sorted(ENV_DIR.glob("mileage*firebase-adminsdk*.json")),
        *sorted(ENV_DIR.glob("mileage*.json")),
        *sorted(ENV_DIR.glob("*firebase-adminsdk*.json")),
    ]
    if not candidates:
        raise FileNotFoundError(f"No Firebase service account JSON found in {ENV_DIR}")
    return candidates[0]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build denormalized pointAwardCandidates from "
            "pointHotels/{hotelId}/calendarYears."
        ),
    )
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Firebase service account JSON.",
    )
    parser.add_argument(
        "--program-id",
        default="marriott",
        help="Program filter. Use 'all' to include every active point hotel.",
    )
    parser.add_argument(
        "--hotel-id",
        action="append",
        default=[],
        help="Specific pointHotels document ID to process. Repeatable.",
    )
    parser.add_argument(
        "--min-nights",
        type=int,
        default=1,
        help="Smallest stay length to precompute.",
    )
    parser.add_argument(
        "--max-nights",
        type=int,
        default=DEFAULT_MAX_NIGHTS,
        help="Largest stay length to precompute.",
    )
    parser.add_argument(
        "--from-date",
        default=date.today().isoformat(),
        help="Earliest check-in date in yyyy-mm-dd.",
    )
    parser.add_argument(
        "--to-date",
        default="",
        help="Latest check-in date in yyyy-mm-dd. Empty means no cap.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of hotels processed, useful for tests.",
    )
    parser.add_argument(
        "--no-stale-mark",
        action="store_true",
        help="Do not mark old candidates inactive.",
    )
    parser.add_argument(
        "--stale-on-empty",
        action="store_true",
        help="Allow stale marking even if this run generated zero candidates.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Read and summarize without writing to Firestore.",
    )
    return parser.parse_args()


def initialize_firebase(service_account_path: str) -> firestore.Client:
    service_account = Path(service_account_path).expanduser().resolve()
    if not service_account.exists():
        raise FileNotFoundError(f"Service account file not found: {service_account}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(service_account))
        firebase_admin.initialize_app(cred)
    return firestore.client()


def as_string(value: Any, fallback: str = "") -> str:
    if value is None:
        return fallback
    text = str(value).strip()
    return text if text else fallback


def as_int(value: Any) -> int:
    if value is None or value == "" or isinstance(value, bool):
        return 0
    try:
        parsed = int(round(float(value)))
    except (TypeError, ValueError):
        return 0
    return parsed if parsed > 0 else 0


def as_float(value: Any) -> float:
    if value is None or value == "" or isinstance(value, bool):
        return 0.0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def as_bool(value: Any, fallback: bool = False) -> bool:
    return value if isinstance(value, bool) else fallback


def as_map(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return {str(key): item for key, item in value.items()}
    return {}


def iso_from_day_key(year_key: str, day_key: str) -> str:
    if len(day_key) != 5 or not day_key.startswith("d"):
        raise ValueError(f"Invalid day key: {day_key}")
    return date(int(year_key), int(day_key[1:3]), int(day_key[3:5])).isoformat()


def program_id_for_hotel(hotel: dict[str, Any]) -> str:
    haystack = " ".join(
        [
            as_string(hotel.get("programId")),
            as_string(hotel.get("loyaltyProgram")),
            as_string(hotel.get("brand")),
            as_string(hotel.get("officialUrl")),
            as_string(hotel.get("propertyCode")),
        ]
    ).lower()
    if "marriott" in haystack or "bonvoy" in haystack:
        return "marriott"
    if "hilton" in haystack:
        return "hilton"
    if "hyatt" in haystack:
        return "hyatt"
    if "ihg" in haystack or "holiday inn" in haystack:
        return "ihg"
    if "accor" in haystack:
        return "accor"
    return as_string(hotel.get("programId")).lower()


def tokenize(*values: Any) -> list[str]:
    tokens: list[str] = []
    seen: set[str] = set()
    for value in values:
        for token in re.findall(r"[0-9a-zA-Z가-힣]+", as_string(value).lower()):
            if len(token) < 2 or token in seen:
                continue
            seen.add(token)
            tokens.append(token)
            if len(tokens) >= 40:
                return tokens
    return tokens


def load_hotels(
    db: firestore.Client,
    program_id: str,
    hotel_ids: set[str],
    limit: int,
) -> list[firestore.DocumentSnapshot]:
    docs = list(
        db.collection("pointHotels")
        .where(filter=FieldFilter("status", "==", "active"))
        .stream()
    )
    selected: list[firestore.DocumentSnapshot] = []
    normalized_program = program_id.lower()

    for doc in docs:
        data = doc.to_dict() or {}
        doc_hotel_id = as_string(data.get("hotelId"), doc.id)
        if hotel_ids and doc.id not in hotel_ids and doc_hotel_id not in hotel_ids:
            continue
        if normalized_program != "all" and program_id_for_hotel(data) != normalized_program:
            continue
        selected.append(doc)
        if limit and len(selected) >= limit:
            break

    return selected


def load_calendar_days(
    db: firestore.Client,
    hotel_id: str,
) -> dict[str, CalendarDay]:
    by_date: dict[str, CalendarDay] = {}
    year_docs = db.collection("pointHotels").document(hotel_id).collection("calendarYears").stream()

    for doc in year_docs:
        year = doc.to_dict() or {}
        if year.get("stale") is True:
            continue
        year_key = as_string(year.get("yearKey"), doc.id)
        days = as_map(year.get("days"))
        for day_key, raw_day in days.items():
            if not day_key.startswith("d"):
                continue
            day = as_map(raw_day)
            try:
                date_key = iso_from_day_key(year_key, day_key)
            except ValueError:
                continue
            points = as_int(day.get("p") or day.get("points") or day.get("pointsPerNight"))
            cash = as_int(day.get("c") or day.get("cash") or day.get("cashPerNightKrw"))
            value = day.get("v")
            by_date[date_key] = CalendarDay(
                date_key=date_key,
                available=as_bool(day.get("a"), fallback=points > 0),
                points=points,
                cash_krw=cash,
                krw_per_point=round(as_float(value), 2) if value is not None else None,
                source_run_id=as_string(day.get("rid") or year.get("latestRunId")),
                year_key=year_key,
                day_key=day_key,
            )

    return by_date


def award_adjusted_points(program_id: str, brand: str, nightly_points: list[int]) -> int:
    total = sum(nightly_points)
    if total <= 0:
        return 0

    eligible = program_id in {"marriott", "hilton"} or "hilton" in brand.lower()
    free_nights = len(nightly_points) // 5 if eligible else 0
    if free_nights <= 0:
        return total
    return total - sum(sorted(nightly_points)[:free_nights])


def build_candidate(
    hotel_doc: firestore.DocumentSnapshot,
    hotel: dict[str, Any],
    days: dict[str, CalendarDay],
    check_in: date,
    nights: int,
    generator_run_id: str,
) -> Candidate | None:
    hotel_id = as_string(hotel.get("hotelId"), hotel_doc.id)
    program_id = program_id_for_hotel(hotel)
    brand = as_string(hotel.get("brand"))
    nightly_days: list[CalendarDay] = []

    for offset in range(nights):
        stay_date = (check_in + timedelta(days=offset)).isoformat()
        day = days.get(stay_date)
        if day is None or not day.available or day.points <= 0 or day.cash_krw <= 0:
            return None
        nightly_days.append(day)

    nightly_points = [day.points for day in nightly_days]
    points_total = award_adjusted_points(program_id, brand, nightly_points)
    cash_total = sum(day.cash_krw for day in nightly_days)
    if points_total <= 0 or cash_total <= 0:
        return None

    krw_per_point = round(cash_total / points_total, 2)
    check_out = check_in + timedelta(days=nights)
    candidate_id = f"{hotel_id}_{check_in.isoformat()}_{nights}"
    source_run_ids = sorted({day.source_run_id for day in nightly_days if day.source_run_id})
    image_url = as_string(hotel.get("imageUrl"))
    gallery_urls = hotel.get("galleryUrls") if isinstance(hotel.get("galleryUrls"), list) else []
    if not image_url and gallery_urls:
        image_url = as_string(gallery_urls[0])

    payload = {
        "candidateId": candidate_id,
        "hotelId": hotel_id,
        "programId": program_id,
        "brand": brand,
        "name": as_string(hotel.get("name")),
        "city": as_string(hotel.get("city")),
        "country": as_string(hotel.get("country")),
        "address": as_string(hotel.get("address")),
        "imageUrl": image_url,
        "rating": as_float(hotel.get("rating")),
        "guestFavorite": as_bool(hotel.get("guestFavorite"), fallback=as_float(hotel.get("rating")) >= 4.5),
        "loyaltyProgram": as_string(hotel.get("loyaltyProgram")),
        "propertyCode": as_string(hotel.get("propertyCode")),
        "officialUrl": as_string(hotel.get("officialUrl")),
        "searchTokens": tokenize(
            hotel.get("name"),
            hotel.get("city"),
            hotel.get("country"),
            hotel.get("address"),
            brand,
            hotel.get("loyaltyProgram"),
            hotel.get("propertyCode"),
        ),
        "checkInDate": check_in.isoformat(),
        "checkOutDate": check_out.isoformat(),
        "nights": nights,
        "available": True,
        "pointsTotal": points_total,
        "cashTotalKrw": cash_total,
        "pointsPerNight": round(points_total / nights),
        "cashPerNightKrw": round(cash_total / nights),
        "krwPerPoint": krw_per_point,
        "valueScore": round(krw_per_point * 100),
        "confidence": 0.95,
        "sourceRunId": generator_run_id,
        "calendarSourceRunId": source_run_ids[-1] if source_run_ids else "",
        "calendarSourceRunIds": source_run_ids,
        "status": "active",
        "stale": False,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    return Candidate(
        candidate_id=candidate_id,
        hotel_id=hotel_id,
        check_in=check_in,
        nights=nights,
        payload=payload,
    )


def generate_candidates_for_hotel(
    hotel_doc: firestore.DocumentSnapshot,
    days: dict[str, CalendarDay],
    min_nights: int,
    max_nights: int,
    from_date: date,
    to_date: date | None,
    generator_run_id: str,
) -> list[Candidate]:
    hotel = hotel_doc.to_dict() or {}
    date_keys = sorted(days.keys())
    candidates: list[Candidate] = []

    for date_key in date_keys:
        check_in = date.fromisoformat(date_key)
        if check_in < from_date:
            continue
        if to_date is not None and check_in > to_date:
            continue
        for nights in range(min_nights, max_nights + 1):
            candidate = build_candidate(
                hotel_doc,
                hotel,
                days,
                check_in,
                nights,
                generator_run_id,
            )
            if candidate is not None:
                candidates.append(candidate)

    return candidates


def mark_stale_candidates(
    db: firestore.Client,
    writer: BatchWriter,
    generated_ids: set[str],
    program_id: str,
    selected_hotel_ids: set[str],
    generator_run_id: str,
) -> int:
    query = db.collection("pointAwardCandidates").where(
        filter=FieldFilter("status", "==", "active")
    )
    if program_id.lower() != "all":
        query = query.where(filter=FieldFilter("programId", "==", program_id.lower()))

    stale_count = 0
    for doc in query.stream():
        data = doc.to_dict() or {}
        hotel_id = as_string(data.get("hotelId"))
        if selected_hotel_ids and hotel_id not in selected_hotel_ids and doc.id.split("_", 1)[0] not in selected_hotel_ids:
            continue
        if doc.id in generated_ids:
            continue
        writer.set(
            doc.reference,
            {
                "available": False,
                "status": "inactive",
                "stale": True,
                "staleAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "staleSourceRunId": generator_run_id,
            },
            merge=True,
        )
        stale_count += 1

    return stale_count


def write_sync_run(
    db: firestore.Client,
    args: argparse.Namespace,
    run_id: str,
    hotel_count: int,
    candidate_count: int,
    stale_count: int,
) -> None:
    db.collection("pointHotelSyncRuns").document(run_id).set(
        {
            "runId": run_id,
            "trigger": "manual",
            "status": "success",
            "type": "pointAwardCandidates",
            "programIds": [] if args.program_id.lower() == "all" else [args.program_id.lower()],
            "hotelIds": args.hotel_id,
            "hotelProcessed": hotel_count,
            "candidateUpserted": candidate_count,
            "staleMarked": stale_count,
            "startedAt": firestore.SERVER_TIMESTAMP,
            "finishedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def main() -> None:
    args = parse_args()
    if args.min_nights <= 0 or args.max_nights < args.min_nights:
        raise ValueError("--min-nights and --max-nights must be a positive range")

    db = initialize_firebase(args.service_account)
    from_date = date.fromisoformat(args.from_date)
    to_date = date.fromisoformat(args.to_date) if args.to_date else None
    run_id = f"candidate_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    hotel_filters = set(args.hotel_id)

    hotels = load_hotels(db, args.program_id, hotel_filters, args.limit)
    writer = BatchWriter(db, dry_run=args.dry_run)
    generated_ids: set[str] = set()
    candidate_count = 0

    print(
        f"[candidates] runId={run_id} hotels={len(hotels)} "
        f"program={args.program_id} nights={args.min_nights}-{args.max_nights} "
        f"from={from_date.isoformat()} to={to_date.isoformat() if to_date else 'open'} "
        f"dryRun={args.dry_run}"
    )

    for hotel_doc in hotels:
        hotel = hotel_doc.to_dict() or {}
        hotel_id = as_string(hotel.get("hotelId"), hotel_doc.id)
        days = load_calendar_days(db, hotel_id)
        candidates = generate_candidates_for_hotel(
            hotel_doc,
            days,
            args.min_nights,
            args.max_nights,
            from_date,
            to_date,
            run_id,
        )
        print(
            f"[candidates] {hotel_id} days={len(days)} "
            f"generated={len(candidates)}"
        )
        for candidate in candidates:
            ref = db.collection("pointAwardCandidates").document(candidate.candidate_id)
            writer.set(ref, candidate.payload, merge=True)
            generated_ids.add(candidate.candidate_id)
            candidate_count += 1

    stale_count = 0
    selected_hotel_ids = {
        as_string((doc.to_dict() or {}).get("hotelId"), doc.id)
        for doc in hotels
    }
    selected_hotel_ids.update(hotel_filters)

    if not args.no_stale_mark:
        if generated_ids or args.stale_on_empty:
            stale_count = mark_stale_candidates(
                db,
                writer,
                generated_ids,
                args.program_id,
                selected_hotel_ids,
                run_id,
            )
        else:
            print(STALE_SKIP_WARNING)

    writer.commit()

    if not args.dry_run:
        write_sync_run(db, args, run_id, len(hotels), candidate_count, stale_count)

    sample_ids = sorted(generated_ids)[:10]
    print(
        f"[candidates] done upsert={candidate_count} staleMarked={stale_count} "
        f"writes={writer.write_count}"
    )
    if sample_ids:
        print("[candidates] sampleIds=" + ", ".join(sample_ids))


if __name__ == "__main__":
    main()
