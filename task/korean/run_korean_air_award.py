#!/usr/bin/env python3

from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - Python 3.8 fallback.
    ZoneInfo = None  # type: ignore[assignment]


ROOT_DIR = Path(__file__).resolve().parents[2]
TASK_DIR = ROOT_DIR / "task" / "korean"
CAPTURE_RUNNER = TASK_DIR / "run_korean_air_capture.sh"
UPLOADER = TASK_DIR / "upload_korean_air_award.py"
DEFAULT_OUTPUT_ROOT = Path("/tmp") / "korean-air-runs"

DEFAULT_ROUTES = [
    "ICN-PQC",
    "ICN-HKT",
    "ICN-CXR",
    "ICN-LAX",
    "ICN-JFK",
    "ICN-HNL",
    "ICN-BCN",
    "ICN-DPS",
    "ICN-FCO",
    "ICN-CDG",
    "ICN-SYD",
]


def now_in_seoul() -> datetime:
    if ZoneInfo:
        return datetime.now(ZoneInfo("Asia/Seoul"))
    return datetime.now()


def default_start_date() -> str:
    return now_in_seoul().date().isoformat()


def default_run_stamp() -> tuple[str, str, str]:
    now_utc = datetime.now(timezone.utc)
    run_slot = now_utc.strftime("%Y%m%dT%H%M%SZ")
    run_id = now_utc.strftime("run_%Y%m%d_%H%M%S")
    timestamp_key = now_in_seoul().strftime("%Y%m%d%H%M")
    return run_id, run_slot, timestamp_key


def parse_args() -> argparse.Namespace:
    run_id, run_slot, timestamp_key = default_run_stamp()
    parser = argparse.ArgumentParser(
        description="Capture Korean Air award availability and upload dan snapshots/posts.",
    )
    parser.add_argument(
        "--route",
        action="append",
        default=[],
        help="Route to collect, e.g. ICN-PQC. Can be passed multiple times.",
    )
    parser.add_argument(
        "--limit-routes",
        type=int,
        default=0,
        help="Limit the selected route list. Useful for smoke tests.",
    )
    parser.add_argument(
        "--start-date",
        default=default_start_date(),
        help="First date to keep, YYYY-MM-DD. Defaults to today in Asia/Seoul.",
    )
    parser.add_argument(
        "--days-ahead",
        type=int,
        default=360,
        help="Last kept date is start-date + days-ahead.",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Defaults to /tmp/korean-air-runs/<runSlot>.",
    )
    parser.add_argument("--run-id", default=run_id, help="Run id written to output and Firestore.")
    parser.add_argument("--run-slot", default=run_slot, help="Run slot used for output directory names.")
    parser.add_argument(
        "--timestamp-key",
        default=timestamp_key,
        help="Snapshot collection id. Defaults to current Asia/Seoul yyyyMMddHHmm.",
    )
    parser.add_argument(
        "--request-delay-ms",
        type=int,
        default=3000,
        help="Delay between Korean Air API requests.",
    )
    parser.add_argument(
        "--wait-ms",
        type=int,
        default=4000,
        help="Wait after opening the login page before filling credentials.",
    )
    parser.add_argument(
        "--login-timeout-ms",
        type=int,
        default=45000,
        help="Login wait timeout passed to the capture script.",
    )
    parser.add_argument(
        "--no-login",
        action="store_true",
        help="Reuse the current CDP browser session without logging in.",
    )
    parser.add_argument(
        "--headful",
        action="store_true",
        help="Ask Playwright to use visible browser when not connected over CDP.",
    )
    parser.add_argument(
        "--dry-run-upload",
        action="store_true",
        help="Capture data but print Firestore writes instead of uploading.",
    )
    parser.add_argument(
        "--skip-post-upload",
        action="store_true",
        help="Upload dan snapshots but do not write posts.",
    )
    parser.add_argument(
        "--capture-only",
        action="store_true",
        help="Only capture JSON. Do not run the uploader.",
    )
    return parser.parse_args()


def normalize_route(value: str) -> str:
    parts = [part.strip().upper() for part in value.split("-") if part.strip()]
    if len(parts) == 1 and len(parts[0]) == 3:
        return f"ICN-{parts[0]}"
    if len(parts) != 2 or any(len(part) != 3 or not part.isalpha() for part in parts):
        raise ValueError(f"Invalid route: {value}. Use ICN-PQC.")
    return f"{parts[0]}-{parts[1]}"


def selected_routes(args: argparse.Namespace) -> list[str]:
    routes = [normalize_route(route) for route in args.route] if args.route else list(DEFAULT_ROUTES)
    deduped = list(dict.fromkeys(routes))
    if args.limit_routes > 0:
        deduped = deduped[: args.limit_routes]
    return deduped


def output_dir_for(args: argparse.Namespace) -> Path:
    if args.output_dir:
        return Path(args.output_dir).expanduser().resolve()
    return DEFAULT_OUTPUT_ROOT / args.run_slot


def run_command(command: list[str]) -> int:
    print("[cmd] " + " ".join(command))
    result = subprocess.run(command, cwd=str(ROOT_DIR), check=False)
    return result.returncode


def main() -> None:
    args = parse_args()
    if not CAPTURE_RUNNER.exists():
        raise FileNotFoundError(f"Capture runner not found: {CAPTURE_RUNNER}")
    if not UPLOADER.exists():
        raise FileNotFoundError(f"Uploader not found: {UPLOADER}")

    routes = selected_routes(args)
    output_dir = output_dir_for(args)
    raw_dir = output_dir / "raw"
    output_dir.mkdir(parents=True, exist_ok=True)
    raw_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "korean_air_award.json"

    capture_command = [
        str(CAPTURE_RUNNER),
        "--start-date",
        args.start_date,
        "--days-ahead",
        str(args.days_ahead),
        "--timestamp-key",
        args.timestamp_key,
        "--run-id",
        args.run_id,
        "--run-slot",
        args.run_slot,
        "--output",
        str(output_path),
        "--raw-dir",
        str(raw_dir),
        "--request-delay-ms",
        str(args.request_delay_ms),
        "--wait-ms",
        str(args.wait_ms),
        "--login-timeout-ms",
        str(args.login_timeout_ms),
    ]
    for route in routes:
        capture_command.extend(["--route", route])
    if args.no_login:
        capture_command.append("--no-login")
    if args.headful:
        capture_command.append("--headful")

    print(f"[routes] {', '.join(routes)}")
    print(f"[output] {output_path}")
    capture_code = run_command(capture_command)
    if capture_code != 0:
        raise SystemExit(capture_code)

    if args.capture_only:
        print(f"[summary] captureOnly output={output_path}")
        return

    upload_command = [
        sys.executable,
        str(UPLOADER),
        "--input",
        str(output_path),
    ]
    if args.dry_run_upload:
        upload_command.append("--dry-run")
    if args.skip_post_upload:
        upload_command.append("--skip-post-upload")

    upload_code = run_command(upload_command)
    if upload_code != 0:
        raise SystemExit(upload_code)
    print(f"[summary] done outputDir={output_dir}")


if __name__ == "__main__":
    main()
