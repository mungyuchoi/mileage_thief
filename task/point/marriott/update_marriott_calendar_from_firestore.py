#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

from upload_marriott_calendar import find_default_service_account, initialize_firebase

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - Python 3.8 fallback.
    ZoneInfo = None  # type: ignore[assignment]


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)

ROOT_DIR = Path(__file__).resolve().parents[3]
TASK_DIR = ROOT_DIR / "task" / "point" / "marriott"
RUNNER = TASK_DIR / "run_marriott_calendar_capture.sh"
UPLOADER = TASK_DIR / "upload_marriott_calendar.py"
DEFAULT_OUTPUT_ROOT = Path("/tmp") / "marriott-calendar-runs"


@dataclass(frozen=True)
class MarriottCalendarTarget:
    hotel_id: str
    property_code: str
    name: str
    official_url: str


def today_in_seoul() -> str:
    if ZoneInfo:
        return datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()
    return datetime.now(timezone.utc).date().isoformat()


def default_run_stamp() -> tuple[str, str]:
    now = datetime.now(timezone.utc)
    run_slot = now.strftime("%Y%m%dT%H%M%SZ")
    run_id = now.strftime("run_%Y%m%d_%H%M%S")
    return run_id, run_slot


def parse_args() -> argparse.Namespace:
    run_id, run_slot = default_run_stamp()
    parser = argparse.ArgumentParser(
        description=(
            "Read active Marriott pointHotels, collect one year of point/cash "
            "calendar data, and upload calendarYears/calendarYearRuns."
        ),
    )
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Firebase service account JSON. Defaults to env/*firebase-adminsdk*.json.",
    )
    parser.add_argument(
        "--program-id",
        default="marriott",
        help="Only update pointHotels with this programId.",
    )
    parser.add_argument(
        "--hotel-id",
        action="append",
        default=[],
        help="Optional hotelId filter. Can be passed multiple times.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional max number of hotels to update.",
    )
    parser.add_argument(
        "--start-date",
        default=today_in_seoul(),
        help="First check-in date, inclusive. Defaults to today's date in Asia/Seoul.",
    )
    parser.add_argument(
        "--days-ahead",
        type=int,
        default=365,
        help="Number of check-in dates to collect.",
    )
    parser.add_argument(
        "--window-days",
        type=int,
        default=31,
        help="Marriott GraphQL request chunk size.",
    )
    parser.add_argument(
        "--modes",
        default="points,cash",
        help="Comma-separated modes passed to the capture script.",
    )
    parser.add_argument(
        "--currency",
        default="KRW",
        help="Cash currency requested from Marriott.",
    )
    parser.add_argument(
        "--rooms",
        type=int,
        default=1,
        help="Number of rooms.",
    )
    parser.add_argument(
        "--adults",
        type=int,
        default=2,
        help="Number of adults.",
    )
    parser.add_argument(
        "--nights",
        type=int,
        default=1,
        help="Length of stay in nights.",
    )
    parser.add_argument(
        "--run-id",
        default=run_id,
        help="Run id written to Firestore.",
    )
    parser.add_argument(
        "--run-slot",
        default=run_slot,
        help="Run slot written to calendarYearRuns document ids.",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Defaults to /tmp/marriott-calendar-runs/<runSlot>.",
    )
    parser.add_argument(
        "--wait-ms",
        type=int,
        default=8000,
        help="Browser wait time after opening the calendar page.",
    )
    parser.add_argument(
        "--request-delay-ms",
        type=int,
        default=1500,
        help="Delay between Marriott GraphQL requests.",
    )
    parser.add_argument(
        "--retry-count",
        type=int,
        default=2,
        help="Retry count for blocked or temporary Marriott responses.",
    )
    parser.add_argument(
        "--retry-delay-ms",
        type=int,
        default=15000,
        help="Delay before retrying blocked or temporary Marriott responses.",
    )
    parser.add_argument(
        "--no-stop-at-blocked",
        action="store_true",
        help="Keep requesting after 401/403/429 responses. Default stops and uploads the successful prefix.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print Firestore targets. Does not open Marriott or upload.",
    )
    parser.add_argument(
        "--dry-run-upload",
        action="store_true",
        help="Capture Marriott data but print Firestore writes instead of uploading.",
    )
    parser.add_argument(
        "--no-login",
        action="store_true",
        help="Do not pass --login to the Marriott capture script.",
    )
    parser.add_argument(
        "--headful",
        action="store_true",
        help="Ask Playwright to use a visible browser when not connected over CDP.",
    )
    parser.add_argument(
        "--stop-on-error",
        action="store_true",
        help="Stop the batch at the first failed hotel.",
    )
    return parser.parse_args()


def normalize_url(value: Any) -> str:
    if not isinstance(value, str):
        return ""
    value = value.strip()
    if not value:
        return ""
    if value.startswith("//"):
        return f"https:{value}"
    if value.startswith("/"):
        return f"https://www.marriott.com{value}"
    return value


def property_code_from_url(value: str) -> str:
    match = re.search(r"/hotels/([a-z0-9]+)-", value, flags=re.IGNORECASE)
    return match.group(1).upper() if match else ""


def normalize_property_code(data: dict[str, Any]) -> str:
    code = str(data.get("propertyCode") or data.get("property_code") or "").strip().upper()
    if code:
        return code
    return property_code_from_url(normalize_url(data.get("officialUrl") or data.get("officiaUrl")))


def build_calendar_url(property_code: str, currency: str) -> str:
    params = {
        "isRateCalendar": "true",
        "propertyCode": property_code,
        "isSearch": "true",
        "currency": currency,
        "showFullPrice": "false",
        "costTab": "total",
        "isAdultsOnly": "false",
        "useRewardsPoints": "true",
    }
    return f"https://www.marriott.com/search/availabilityCalendar.mi?{urlencode(params)}"


def read_targets(args: argparse.Namespace) -> list[MarriottCalendarTarget]:
    db = initialize_firebase(args.service_account)
    hotel_id_filter = set(args.hotel_id)
    targets: list[MarriottCalendarTarget] = []

    for snapshot in db.collection("pointHotels").stream():
        data = snapshot.to_dict() or {}
        hotel_id = str(data.get("hotelId") or snapshot.id)
        if hotel_id_filter and hotel_id not in hotel_id_filter:
            continue
        if data.get("programId") != args.program_id:
            continue
        if data.get("status", "active") != "active":
            continue

        property_code = normalize_property_code(data)
        if not property_code:
            print(f"[skip] {hotel_id}: propertyCode is missing")
            continue

        targets.append(
            MarriottCalendarTarget(
                hotel_id=hotel_id,
                property_code=property_code,
                name=str(data.get("name") or ""),
                official_url=normalize_url(data.get("officialUrl") or data.get("officiaUrl")),
            )
        )

    targets.sort(key=lambda item: item.hotel_id)
    if args.limit > 0:
        targets = targets[: args.limit]
    return targets


def output_dir_for(args: argparse.Namespace) -> Path:
    if args.output_dir:
        return Path(args.output_dir).expanduser().resolve()
    return DEFAULT_OUTPUT_ROOT / args.run_slot


def print_targets(targets: list[MarriottCalendarTarget]) -> None:
    rows = [
        {
            "hotelId": target.hotel_id,
            "propertyCode": target.property_code,
            "name": target.name,
            "officialUrl": target.official_url,
        }
        for target in targets
    ]
    print(json.dumps(rows, ensure_ascii=False, indent=2))


def update_one(target: MarriottCalendarTarget, args: argparse.Namespace, output_dir: Path) -> int:
    output_path = output_dir / f"{target.hotel_id}_calendar.json"
    raw_dir = output_dir / "raw" / target.hotel_id
    calendar_url = build_calendar_url(target.property_code, args.currency)

    capture_command = [
        str(RUNNER),
        "--hotel-id",
        target.hotel_id,
        "--program-id",
        args.program_id,
        "--property-id",
        target.property_code,
        "--url",
        calendar_url,
        "--start-date",
        args.start_date,
        "--days-ahead",
        str(args.days_ahead),
        "--window-days",
        str(args.window_days),
        "--modes",
        args.modes,
        "--currency",
        args.currency,
        "--rooms",
        str(args.rooms),
        "--adults",
        str(args.adults),
        "--nights",
        str(args.nights),
        "--run-id",
        args.run_id,
        "--run-slot",
        args.run_slot,
        "--output",
        str(output_path),
        "--raw-dir",
        str(raw_dir),
        "--wait-ms",
        str(args.wait_ms),
        "--request-delay-ms",
        str(args.request_delay_ms),
        "--retry-count",
        str(args.retry_count),
        "--retry-delay-ms",
        str(args.retry_delay_ms),
    ]
    if not args.no_login:
        capture_command.append("--login")
    if args.headful:
        capture_command.append("--headful")
    if args.no_stop_at_blocked:
        capture_command.append("--no-stop-at-blocked")

    print(f"[capture] {target.hotel_id} propertyCode={target.property_code} name={target.name}")
    print(f"[output] {output_path}")
    capture_result = subprocess.run(capture_command, cwd=str(ROOT_DIR), check=False)
    if capture_result.returncode != 0:
        print(f"[capture-failed] {target.hotel_id} returnCode={capture_result.returncode}")
        return capture_result.returncode

    upload_command = [
        sys.executable,
        str(UPLOADER),
        "--input",
        str(output_path),
        "--service-account",
        args.service_account,
    ]
    if args.dry_run_upload:
        upload_command.append("--dry-run")

    upload_result = subprocess.run(upload_command, cwd=str(ROOT_DIR), check=False)
    if upload_result.returncode != 0:
        print(f"[upload-failed] {target.hotel_id} returnCode={upload_result.returncode}")
    return upload_result.returncode


def main() -> None:
    args = parse_args()
    if not RUNNER.exists():
        raise FileNotFoundError(f"Marriott capture runner not found: {RUNNER}")
    if not UPLOADER.exists():
        raise FileNotFoundError(f"Marriott uploader not found: {UPLOADER}")

    targets = read_targets(args)
    print(f"[targets] count={len(targets)} programId={args.program_id}")
    if args.dry_run:
        print_targets(targets)
        return
    if not targets:
        return

    output_dir = output_dir_for(args)
    output_dir.mkdir(parents=True, exist_ok=True)

    failures: list[str] = []
    for index, target in enumerate(targets, start=1):
        print(f"[progress] {index}/{len(targets)}")
        return_code = update_one(target, args, output_dir)
        if return_code != 0:
            failures.append(target.hotel_id)
            if args.stop_on_error:
                break

    if failures:
        print(f"[summary] failed={len(failures)} hotels={', '.join(failures)}")
        raise SystemExit(1)
    print(f"[summary] updated={len(targets)} outputDir={output_dir}")


if __name__ == "__main__":
    main()
