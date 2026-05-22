#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import date, datetime
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore


ROOT_DIR = Path(__file__).resolve().parents[3]
ENV_DIR = ROOT_DIR / "env"
DEFAULT_INPUT = ROOT_DIR / "task" / "point" / "marriott" / "output" / "marriott_calendar.json"
SOURCE_PROVIDER = "marriott_adf"


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
        description="Upload a normalized Marriott point/cash calendar payload into Firestore.",
    )
    parser.add_argument(
        "--input",
        default=str(DEFAULT_INPUT),
        help="Normalized JSON from capture_marriott_calendar.js.",
    )
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Firebase service account JSON.",
    )
    parser.add_argument(
        "--preview-days",
        type=int,
        default=14,
        help="Number of days copied to pointHotels.calendarPreview.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print Firestore writes without uploading.",
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


def as_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return None
    try:
        parsed = int(round(float(value)))
    except (TypeError, ValueError):
        return None
    return parsed if parsed > 0 else None


def as_bool(value: Any) -> bool:
    return bool(value)


def compact_day(entry: dict[str, Any]) -> dict[str, Any]:
    points = as_int(entry.get("p") or entry.get("points") or entry.get("pointsPerNight"))
    cash = as_int(entry.get("c") or entry.get("cash") or entry.get("cashPerNightKrw"))
    available = as_bool(entry.get("a") if "a" in entry else points is not None)
    if points is None:
        available = False
    value = round(cash / points, 2) if points and cash else None
    return {
        "a": available,
        "p": points,
        "c": cash,
        "v": value,
    }


def write_day(entry: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    day = compact_day(entry)
    day.update(
        {
            "src": payload.get("sourceProvider") or SOURCE_PROVIDER,
            "rid": payload["runId"],
            "at": firestore.SERVER_TIMESTAMP,
        }
    )
    return day


def comparable_day(entry: dict[str, Any] | None) -> dict[str, Any]:
    if not isinstance(entry, dict):
        return {"a": False, "p": None, "c": None, "v": None}
    return compact_day(entry)


def year_date(year_key: str, day_key: str) -> date:
    if len(day_key) != 5 or not day_key.startswith("d"):
        raise ValueError(f"Invalid day key: {day_key}")
    month = int(day_key[1:3])
    day = int(day_key[3:5])
    return date(int(year_key), month, day)


def iso_from_key(year_key: str, day_key: str) -> str:
    return year_date(year_key, day_key).isoformat()


def day_key_from_iso(value: str) -> str:
    return f"d{value[5:7]}{value[8:10]}"


def canonical_hash(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def year_stats(year_key: str, days: dict[str, dict[str, Any]]) -> dict[str, Any]:
    if not days:
        return {
            "availableCount": 0,
            "minPoints": None,
            "maxPoints": None,
            "minCashKrw": None,
            "maxCashKrw": None,
            "firstDate": None,
            "lastDate": None,
        }

    normalized = {key: comparable_day(value) for key, value in days.items()}
    valid_keys = sorted(key for key in normalized if key.startswith("d"))
    points = [value["p"] for value in normalized.values() if value.get("p")]
    cash = [value["c"] for value in normalized.values() if value.get("c")]
    return {
        "availableCount": sum(1 for value in normalized.values() if value.get("a")),
        "minPoints": min(points) if points else None,
        "maxPoints": max(points) if points else None,
        "minCashKrw": min(cash) if cash else None,
        "maxCashKrw": max(cash) if cash else None,
        "firstDate": iso_from_key(year_key, valid_keys[0]) if valid_keys else None,
        "lastDate": iso_from_key(year_key, valid_keys[-1]) if valid_keys else None,
    }


def merge_plain_days(
    previous_days: dict[str, Any],
    new_days: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    merged = {key: comparable_day(value) for key, value in previous_days.items() if isinstance(value, dict)}
    for key, value in new_days.items():
        merged[key] = comparable_day(value)
    return merged


def changed_days(
    previous_days: dict[str, Any],
    new_days: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    changed: dict[str, dict[str, Any]] = {}
    for key, new_entry in sorted(new_days.items()):
        old_plain = comparable_day(previous_days.get(key))
        new_plain = comparable_day(new_entry)
        if old_plain != new_plain:
            changed[key] = {
                "old": old_plain,
                "new": new_plain,
            }
    return changed


def collect_all_days_by_date(
    years: dict[str, dict[str, dict[str, Any]]],
) -> dict[str, dict[str, Any]]:
    by_date: dict[str, dict[str, Any]] = {}
    for year_key, days in years.items():
        for day_key, entry in days.items():
            by_date[iso_from_key(year_key, day_key)] = comparable_day(entry)
    return by_date


def build_current_award(
    payload: dict[str, Any],
    all_days_by_date: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    range_start = str(payload.get("rangeStart") or "")
    candidates = [
        (day.get("p") or 10**12, check_in, day)
        for check_in, day in all_days_by_date.items()
        if check_in >= range_start and day.get("a") and day.get("p")
    ]
    if not candidates:
        return {
            "available": False,
            "pointsPerNight": None,
            "cashPerNightKrw": None,
            "krwPerPoint": None,
            "sourceProvider": payload.get("sourceProvider") or SOURCE_PROVIDER,
            "sourceRunId": payload["runId"],
            "checkedAt": firestore.SERVER_TIMESTAMP,
        }

    cash_backed_candidates = [item for item in candidates if item[2].get("c")]
    _, check_in, day = sorted(cash_backed_candidates or candidates)[0]
    return {
        "available": True,
        "checkInDate": check_in,
        "nights": payload.get("nights", 1),
        "pointsPerNight": day.get("p"),
        "cashPerNightKrw": day.get("c"),
        "krwPerPoint": day.get("v"),
        "currency": payload.get("currency", "KRW"),
        "sourceProvider": payload.get("sourceProvider") or SOURCE_PROVIDER,
        "sourceRunId": payload["runId"],
        "checkedAt": firestore.SERVER_TIMESTAMP,
    }


def build_calendar_preview(
    payload: dict[str, Any],
    all_days_by_date: dict[str, dict[str, Any]],
    preview_days: int,
) -> list[dict[str, Any]]:
    start = datetime.strptime(payload["rangeStart"], "%Y-%m-%d").date()
    preview: list[dict[str, Any]] = []
    for offset in range(preview_days):
        check_in = date.fromordinal(start.toordinal() + offset).isoformat()
        day = all_days_by_date.get(check_in, {"a": False, "p": None, "c": None, "v": None})
        preview.append(
            {
                "dateKey": check_in,
                "available": day.get("a", False),
                "pointsPerNight": day.get("p"),
                "cashPerNightKrw": day.get("c"),
                "krwPerPoint": day.get("v"),
                "sourceRunId": payload["runId"],
            }
        )
    return preview


def json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [json_safe(item) for item in value]
    if value is firestore.SERVER_TIMESTAMP:
        return "serverTimestamp"
    try:
        json.dumps(value)
    except TypeError:
        return str(value)
    return value


def upload_payload(
    db: firestore.Client | None,
    payload: dict[str, Any],
    preview_days: int,
    dry_run: bool,
) -> None:
    hotel_id = payload["hotelId"]
    years_payload = payload.get("years") or {}
    if not isinstance(years_payload, dict) or not years_payload:
        raise ValueError("payload.years is required")

    hotel_ref = db.collection("pointHotels").document(hotel_id) if db else None
    merged_years: dict[str, dict[str, dict[str, Any]]] = {}
    write_plan: dict[str, Any] = {}

    for year_key, raw_days in sorted(years_payload.items()):
        if not isinstance(raw_days, dict):
            continue

        year_ref = hotel_ref.collection("calendarYears").document(year_key) if hotel_ref else None
        previous_doc = (year_ref.get().to_dict() if year_ref else {}) or {}
        previous_days = previous_doc.get("days", {}) if isinstance(previous_doc, dict) else {}
        if not isinstance(previous_days, dict):
            previous_days = {}

        plain_days = {key: comparable_day(value) for key, value in raw_days.items()}
        write_days = {key: write_day(value, payload) for key, value in raw_days.items()}
        merged_days = merge_plain_days(previous_days, plain_days)
        merged_years[year_key] = merged_days
        changes = changed_days(previous_days, plain_days)
        stats = year_stats(year_key, merged_days)

        year_doc = {
            "hotelId": hotel_id,
            "programId": payload.get("programId", "marriott"),
            "propertyCode": payload.get("propertyCode"),
            "yearKey": year_key,
            "occupancyKey": payload.get("occupancyKey", "r1_a2"),
            "rooms": payload.get("rooms", 1),
            "adults": payload.get("adults", 2),
            "nights": payload.get("nights", 1),
            "currency": payload.get("currency", "KRW"),
            "days": write_days,
            **stats,
            "latestRunId": payload["runId"],
            "lastCheckedAt": firestore.SERVER_TIMESTAMP,
            "lastChangedAt": firestore.SERVER_TIMESTAMP if changes else previous_doc.get("lastChangedAt"),
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "stale": False,
        }
        run_doc = {
            "hotelId": hotel_id,
            "programId": payload.get("programId", "marriott"),
            "propertyCode": payload.get("propertyCode"),
            "yearKey": year_key,
            "runSlot": payload["runSlot"],
            "runId": payload["runId"],
            "sourceProvider": payload.get("sourceProvider") or SOURCE_PROVIDER,
            "occupancyKey": payload.get("occupancyKey", "r1_a2"),
            "rooms": payload.get("rooms", 1),
            "adults": payload.get("adults", 2),
            "nights": payload.get("nights", 1),
            "currency": payload.get("currency", "KRW"),
            "rangeStart": payload.get("rangeStart"),
            "rangeEnd": payload.get("rangeEnd"),
            "observedCount": len(plain_days),
            "changedCount": len(changes),
            "changedDays": changes,
            "rawHash": canonical_hash(plain_days),
            "createdAt": firestore.SERVER_TIMESTAMP,
        }

        write_plan[f"pointHotels/{hotel_id}/calendarYears/{year_key}"] = year_doc
        write_plan[f"pointHotels/{hotel_id}/calendarYearRuns/{year_key}_{payload['runSlot']}"] = run_doc

        if not dry_run and year_ref:
            year_ref.set(year_doc, merge=True)
            hotel_ref.collection("calendarYearRuns").document(f"{year_key}_{payload['runSlot']}").set(
                run_doc,
                merge=True,
            )
            print(
                f"[upload] pointHotels/{hotel_id}/calendarYears/{year_key} "
                f"observed={len(plain_days)} changed={len(changes)}"
            )

    all_days_by_date = collect_all_days_by_date(merged_years)
    parent_doc = {
        "currentAward": build_current_award(payload, all_days_by_date),
        "calendarPreview": build_calendar_preview(payload, all_days_by_date, preview_days),
        "pointCalendarSource": payload.get("sourceProvider") or SOURCE_PROVIDER,
        "pointCalendarRunId": payload["runId"],
        "pointCalendarUpdatedAt": firestore.SERVER_TIMESTAMP,
    }
    write_plan[f"pointHotels/{hotel_id}"] = parent_doc

    if dry_run:
        print(json.dumps(json_safe(write_plan), ensure_ascii=False, indent=2))
        return

    if hotel_ref:
        hotel_ref.set(parent_doc, merge=True)
        print(f"[upload] pointHotels/{hotel_id} currentAward/calendarPreview")


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).expanduser().resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"Input JSON not found: {input_path}")

    payload = json.loads(input_path.read_text(encoding="utf-8"))
    db = None if args.dry_run else initialize_firebase(args.service_account)
    upload_payload(db, payload, args.preview_days, args.dry_run)


if __name__ == "__main__":
    main()
