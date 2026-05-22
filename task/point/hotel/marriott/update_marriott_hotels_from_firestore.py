#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from upload_point_hotel import find_default_service_account, initialize_firebase


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True)

ROOT_DIR = Path(__file__).resolve().parents[4]
TASK_DIR = ROOT_DIR / "task" / "point" / "hotel" / "marriott"
RUNNER = TASK_DIR / "run_marriott_hotel_parser_cdp.sh"
DEFAULT_OUTPUT_ROOT = Path("/tmp") / "marriott-hotel-meta-runs"


@dataclass(frozen=True)
class PointHotelTarget:
    hotel_id: str
    official_url: str
    name: str
    property_code: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Read Marriott point hotels from Firestore, parse each officialUrl, "
            "and upload refreshed hotel metadata back to Firestore."
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
        "--output-dir",
        default="",
        help="Where parsed JSON files should be written. Defaults to /tmp/marriott-hotel-meta-runs/<runId>.",
    )
    parser.add_argument(
        "--wait-ms",
        type=int,
        default=8000,
        help="Browser wait time after each hotel page load.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print Firestore targets. Does not open Marriott or upload.",
    )
    parser.add_argument(
        "--dry-run-upload",
        action="store_true",
        help="Parse each hotel but print upload payload instead of writing Firestore.",
    )
    parser.add_argument(
        "--no-login",
        action="store_true",
        help="Do not pass --login to the Marriott parser.",
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


def read_targets(args: argparse.Namespace) -> list[PointHotelTarget]:
    db = initialize_firebase(args.service_account)
    hotel_id_filter = set(args.hotel_id)
    targets: list[PointHotelTarget] = []

    for snapshot in db.collection("pointHotels").stream():
        data = snapshot.to_dict() or {}
        hotel_id = str(data.get("hotelId") or snapshot.id)
        if hotel_id_filter and hotel_id not in hotel_id_filter:
            continue
        if data.get("programId") != args.program_id:
            continue
        if data.get("status", "active") not in {"active", "pending"}:
            continue

        official_url = normalize_url(data.get("officialUrl") or data.get("officiaUrl"))
        if not official_url:
            print(f"[skip] {hotel_id}: officialUrl is missing")
            continue

        targets.append(
            PointHotelTarget(
                hotel_id=hotel_id,
                official_url=official_url,
                name=str(data.get("name") or ""),
                property_code=str(data.get("propertyCode") or ""),
            )
        )

    targets.sort(key=lambda item: item.hotel_id)
    if args.limit > 0:
        targets = targets[: args.limit]
    return targets


def output_dir_for(args: argparse.Namespace) -> Path:
    if args.output_dir:
        return Path(args.output_dir).expanduser().resolve()
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return DEFAULT_OUTPUT_ROOT / run_id


def print_targets(targets: list[PointHotelTarget]) -> None:
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


def update_one(target: PointHotelTarget, args: argparse.Namespace, output_dir: Path) -> int:
    output_path = output_dir / f"{target.hotel_id}_hotel_meta.json"
    command = [
        str(RUNNER),
        "--url",
        target.official_url,
        "--output",
        str(output_path),
        "--wait-ms",
        str(args.wait_ms),
    ]
    if not args.no_login:
        command.append("--login")
    command.append("--dry-run-upload" if args.dry_run_upload else "--upload")

    print(f"[update] {target.hotel_id} {target.name or target.official_url}")
    print(f"[output] {output_path}")
    result = subprocess.run(command, cwd=str(ROOT_DIR), check=False)
    return result.returncode


def main() -> None:
    args = parse_args()
    if not RUNNER.exists():
        raise FileNotFoundError(f"Marriott parser runner not found: {RUNNER}")

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
            print(f"[failed] {target.hotel_id} returnCode={return_code}")
            if args.stop_on_error:
                break

    if failures:
        print(f"[summary] failed={len(failures)} hotels={', '.join(failures)}")
        raise SystemExit(1)
    print(f"[summary] updated={len(targets)} outputDir={output_dir}")


if __name__ == "__main__":
    main()
