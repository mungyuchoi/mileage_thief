#!/usr/bin/env python3

from __future__ import annotations

import argparse
from collections import defaultdict
from datetime import date, datetime
from typing import Any

from firebase_admin import firestore

from build_point_award_candidates import (
    DEFAULT_MAX_NIGHTS,
    Candidate,
    find_default_service_account,
    generate_candidates_for_hotel,
    initialize_firebase,
    load_calendar_days,
    load_hotels,
    as_string,
)


SORTS = ("value", "points", "recent")
DEFAULT_ITEMS_PER_INDEX = 50


class BatchWriter:
    def __init__(self, db: firestore.Client, dry_run: bool, batch_size: int = 450) -> None:
        self.db = db
        self.dry_run = dry_run
        self.batch_size = batch_size
        self._batch = db.batch()
        self._pending = 0
        self.write_count = 0

    def set(self, ref: firestore.DocumentReference, data: dict[str, Any], *, merge: bool = False) -> None:
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Build compact pointAwardIndexes docs from "
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
        "--items-per-index",
        type=int,
        default=DEFAULT_ITEMS_PER_INDEX,
        help="Maximum items stored inside each index document.",
    )
    parser.add_argument(
        "--allow-duplicate-hotels",
        action="store_true",
        help="Allow multiple dates from the same hotel in one index.",
    )
    parser.add_argument(
        "--include-all-scope",
        action="store_true",
        default=True,
        help="Also write all_n{nights}_{sort} docs from this run's hotels.",
    )
    parser.add_argument(
        "--no-all-scope",
        dest="include_all_scope",
        action="store_false",
        help="Only write program-specific scope docs.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of hotels processed, useful for tests.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Read and summarize without writing to Firestore.",
    )
    return parser.parse_args()


def sort_key(candidate: Candidate, sort_name: str) -> tuple[Any, ...]:
    payload = candidate.payload
    if sort_name == "points":
        return (
            payload.get("pointsTotal") or 10**12,
            -(payload.get("valueScore") or 0),
            payload.get("checkInDate") or "",
            payload.get("name") or "",
        )
    if sort_name == "recent":
        return (
            payload.get("checkInDate") or "",
            -(payload.get("valueScore") or 0),
            payload.get("pointsTotal") or 10**12,
            payload.get("name") or "",
        )
    return (
        -(payload.get("valueScore") or 0),
        payload.get("pointsTotal") or 10**12,
        payload.get("checkInDate") or "",
        payload.get("name") or "",
    )


def compact_item(candidate: Candidate) -> dict[str, Any]:
    payload = candidate.payload
    return {
        "candidateId": candidate.candidate_id,
        "hotelId": payload.get("hotelId"),
        "programId": payload.get("programId"),
        "brand": payload.get("brand"),
        "name": payload.get("name"),
        "city": payload.get("city"),
        "country": payload.get("country"),
        "address": payload.get("address"),
        "imageUrl": payload.get("imageUrl"),
        "rating": payload.get("rating"),
        "guestFavorite": payload.get("guestFavorite"),
        "loyaltyProgram": payload.get("loyaltyProgram"),
        "propertyCode": payload.get("propertyCode"),
        "officialUrl": payload.get("officialUrl"),
        "checkInDate": payload.get("checkInDate"),
        "checkOutDate": payload.get("checkOutDate"),
        "nights": payload.get("nights"),
        "pointsTotal": payload.get("pointsTotal"),
        "cashTotalKrw": payload.get("cashTotalKrw"),
        "pointsPerNight": payload.get("pointsPerNight"),
        "cashPerNightKrw": payload.get("cashPerNightKrw"),
        "krwPerPoint": payload.get("krwPerPoint"),
        "valueScore": payload.get("valueScore"),
        "confidence": payload.get("confidence"),
        "calendarSourceRunId": payload.get("calendarSourceRunId"),
    }


def select_items(
    candidates: list[Candidate],
    sort_name: str,
    limit: int,
    allow_duplicate_hotels: bool,
) -> list[dict[str, Any]]:
    selected: list[Candidate] = []
    seen_hotels: set[str] = set()

    for candidate in sorted(candidates, key=lambda item: sort_key(item, sort_name)):
        hotel_id = candidate.hotel_id
        if not allow_duplicate_hotels and hotel_id in seen_hotels:
            continue
        seen_hotels.add(hotel_id)
        selected.append(candidate)
        if len(selected) >= limit:
            break

    return [compact_item(candidate) for candidate in selected]


def scope_for_candidate(candidate: Candidate) -> str:
    return as_string(candidate.payload.get("programId"))


def write_sync_run(
    db: firestore.Client,
    args: argparse.Namespace,
    run_id: str,
    hotel_count: int,
    candidate_count: int,
    index_count: int,
) -> None:
    db.collection("pointHotelSyncRuns").document(run_id).set(
        {
            "runId": run_id,
            "trigger": "manual",
            "status": "success",
            "type": "pointAwardIndexes",
            "programIds": [] if args.program_id.lower() == "all" else [args.program_id.lower()],
            "hotelIds": args.hotel_id,
            "hotelProcessed": hotel_count,
            "candidateObserved": candidate_count,
            "indexUpserted": index_count,
            "itemsPerIndex": args.items_per_index,
            "startedAt": firestore.SERVER_TIMESTAMP,
            "finishedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def main() -> None:
    args = parse_args()
    if args.min_nights <= 0 or args.max_nights < args.min_nights:
        raise ValueError("--min-nights and --max-nights must be a positive range")
    if args.items_per_index <= 0:
        raise ValueError("--items-per-index must be positive")

    db = initialize_firebase(args.service_account)
    from_date = date.fromisoformat(args.from_date)
    to_date = date.fromisoformat(args.to_date) if args.to_date else None
    run_id = f"award_index_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    hotels = load_hotels(db, args.program_id, set(args.hotel_id), args.limit)
    writer = BatchWriter(db, dry_run=args.dry_run)
    scoped_candidates: dict[str, list[Candidate]] = defaultdict(list)
    candidate_count = 0

    print(
        f"[indexes] runId={run_id} hotels={len(hotels)} program={args.program_id} "
        f"nights={args.min_nights}-{args.max_nights} itemsPerIndex={args.items_per_index} "
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
        print(f"[indexes] {hotel_id} days={len(days)} candidates={len(candidates)}")
        candidate_count += len(candidates)
        for candidate in candidates:
            program_scope = scope_for_candidate(candidate)
            if program_scope:
                scoped_candidates[program_scope].append(candidate)
            if args.include_all_scope:
                scoped_candidates["all"].append(candidate)

    index_count = 0
    for scope, candidates in sorted(scoped_candidates.items()):
        for nights in range(args.min_nights, args.max_nights + 1):
            nights_candidates = [
                candidate for candidate in candidates if candidate.nights == nights
            ]
            for sort_name in SORTS:
                index_id = f"{scope}_n{nights}_{sort_name}"
                items = select_items(
                    nights_candidates,
                    sort_name,
                    args.items_per_index,
                    args.allow_duplicate_hotels,
                )
                payload = {
                    "indexId": index_id,
                    "scope": scope,
                    "programId": None if scope == "all" else scope,
                    "nights": nights,
                    "sort": sort_name,
                    "count": len(items),
                    "candidateObserved": len(nights_candidates),
                    "itemsPerIndex": args.items_per_index,
                    "items": items,
                    "sourceRunId": run_id,
                    "status": "active",
                    "stale": False,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                }
                writer.set(
                    db.collection("pointAwardIndexes").document(index_id),
                    payload,
                    merge=False,
                )
                index_count += 1
                print(
                    f"[indexes] pointAwardIndexes/{index_id} "
                    f"items={len(items)} observed={len(nights_candidates)}"
                )

    writer.commit()
    if not args.dry_run:
        write_sync_run(db, args, run_id, len(hotels), candidate_count, index_count)

    print(
        f"[indexes] done indexes={index_count} candidatesObserved={candidate_count} "
        f"writes={writer.write_count}"
    )


if __name__ == "__main__":
    main()
