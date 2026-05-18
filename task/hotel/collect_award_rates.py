from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from html import unescape
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import requests

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    from google.cloud.firestore_v1.base_query import FieldFilter
except ImportError:  # pragma: no cover - dry-run can run without Firebase deps.
    firebase_admin = None
    credentials = None
    firestore = None
    FieldFilter = None


ROOT_DIR = Path(__file__).resolve().parents[2]
ENV_DIR = ROOT_DIR / "env"
REQUEST_TIMEOUT_SECONDS = 30
DEFAULT_USER_AGENT = (
    "MileCatchHotelAwardPoC/0.1 "
    "(contact: milecatch; purpose: property-award research)"
)

PROGRAMS = {"marriott", "hilton", "hyatt", "ihg"}
JOB_TYPES = {"master", "popular", "alert", "urgent", "backfill"}
JOB_COLLECTION = "hotel_award_crawl_jobs"
RUN_COLLECTION = "hotel_award_crawl_runs"
BOOKING_PATH_BLOCKLIST = {
    "marriott": [
        "/reservation/",
        "/search/",
        "/aries-search/",
        "/availabilitysearch",
    ],
    "hilton": ["/search/", "/book/", "/find-hotels/"],
    "hyatt": ["/search/", "/book/", "/reservation/"],
    "ihg": ["/hotels/us/en/reservation", "/reservation/", "/roomrate"],
}


@dataclass(frozen=True)
class Source:
    program: str
    url: str
    region_key: str = ""
    city_name: str = ""
    country_code: str = ""
    property_id: str = ""
    hotel_name: str = ""
    brand: str = ""
    source_id: str = ""


@dataclass(frozen=True)
class ParsedHotel:
    property_id: str
    program: str
    source_url: str
    name: str
    brand: str
    city_name: str
    country_code: str
    region_key: str
    address: str
    image_url: str
    points_total: int
    cash_total_krw: int | None
    cash_total_usd: float | None
    availability_status: str
    confidence: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect hotel award property/rate snapshots for MileCatch.",
    )
    parser.add_argument("--program", choices=sorted(PROGRAMS))
    parser.add_argument("--url", action="append", default=[])
    parser.add_argument("--source-file")
    parser.add_argument("--date", default=_date_key(datetime.now() + timedelta(days=30)))
    parser.add_argument("--nights", type=int, default=1)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument(
        "--job-id",
        help="Run one Firestore hotel_award_crawl_jobs document.",
    )
    parser.add_argument(
        "--job-batch",
        choices=["queued"],
        help="Run queued Firestore crawl jobs due now.",
    )
    parser.add_argument(
        "--job-type",
        action="append",
        choices=sorted(JOB_TYPES),
        default=[],
        help="Restrict --job-batch to one or more job types.",
    )
    parser.add_argument(
        "--job-file",
        help="Run jobs from a JSON file produced by build_award_crawl_jobs.py --dry-run.",
    )
    parser.add_argument(
        "--max-queued-scan",
        type=int,
        default=250,
        help="Maximum queued Firestore docs to scan before local sorting.",
    )
    parser.add_argument(
        "--domain-delay-seconds",
        type=float,
        default=0,
        help="Optional delay between job fetches for cron runs.",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--service-account", default="")
    parser.add_argument("--actor-uid", default="task_collect_hotel_awards")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.job_id or args.job_batch or args.job_file:
        return run_job_mode(args)
    return run_manual_sources(args)


def run_manual_sources(args: argparse.Namespace) -> int:
    sources = load_sources(args)
    if args.limit > 0:
        sources = sources[: args.limit]
    if not sources:
        print("No sources. Pass --url with --program or --source-file.", file=sys.stderr)
        return 2

    parsed = collect_sources(sources)
    payload = build_payload(parsed, date_key=args.date, nights=max(args.nights, 1))
    if args.dry_run:
        print(json.dumps(payload, ensure_ascii=False, indent=2, default=str))
        return 0

    db = initialize_firestore(args.service_account)
    write_payload(db, payload, actor_uid=args.actor_uid)
    print(
        f"Wrote {len(payload['properties'])} properties and "
        f"{len(payload['snapshots'])} snapshots.",
    )
    return 0


def load_sources(args: argparse.Namespace) -> list[Source]:
    sources: list[Source] = []
    if args.source_file:
        raw = json.loads(Path(args.source_file).read_text(encoding="utf-8"))
        for item in raw if isinstance(raw, list) else raw.get("sources", []):
            if not isinstance(item, dict):
                continue
            program = as_string(
                item.get("programId") or item.get("program") or args.program,
            ).lower()
            url = as_string(
                item.get("sourceUrl") or item.get("officialUrl") or item.get("url"),
            )
            if program and url:
                sources.append(
                    Source(
                        program=program,
                        url=url,
                        region_key=as_string(item.get("regionKey")),
                        city_name=as_string(item.get("cityName")),
                        country_code=as_string(item.get("countryCode")),
                        property_id=as_string(item.get("propertyId")),
                        hotel_name=as_string(
                            item.get("hotelName") or item.get("name"),
                        ),
                        brand=as_string(item.get("brand")),
                        source_id=as_string(item.get("sourceId") or item.get("id")),
                    ),
                )

    for url in args.url:
        if not args.program:
            raise ValueError("--program is required when using --url.")
        sources.append(Source(program=args.program, url=url))
    return sources


def collect_sources(sources: list[Source]) -> list[ParsedHotel]:
    parsed: list[ParsedHotel] = []
    for source in sources:
        if source.program not in PROGRAMS:
            print(f"Skip unsupported program: {source.program}", file=sys.stderr)
            continue
        if is_blocked_source(source):
            print(f"Skip blocked/unsupported source: {source.url}", file=sys.stderr)
            continue
        try:
            html = fetch_html(source.url)
            parsed.append(parse_hotel_page(source, html))
        except Exception as exc:  # noqa: BLE001 - diagnostic script.
            print(f"Failed {source.url}: {exc}", file=sys.stderr)
    return parsed


def collect_source_strict(source: Source) -> ParsedHotel:
    html = fetch_html(source.url)
    return parse_hotel_page(source, html)


def is_blocked_source(source: Source) -> bool:
    parsed = urlparse(source.url)
    host = parsed.netloc.lower()
    path = parsed.path.lower()
    if "roompoints.com" in host:
        return True
    return any(fragment in path for fragment in BOOKING_PATH_BLOCKLIST[source.program])


def fetch_html(url: str) -> str:
    response = requests.get(
        url,
        timeout=REQUEST_TIMEOUT_SECONDS,
        headers={
            "User-Agent": DEFAULT_USER_AGENT,
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "ko,en;q=0.8",
        },
    )
    response.raise_for_status()
    return response.text


def parse_hotel_page(source: Source, html: str) -> ParsedHotel:
    json_ld = parse_json_ld(html)
    name = (
        source.hotel_name
        or first_string(json_ld, ["name"])
        or meta_content(html, "og:title")
        or title_text(html)
        or "Hotel"
    )
    image = (
        first_string(json_ld, ["image", "url"])
        or meta_content(html, "og:image")
        or ""
    )
    address = address_text(json_ld) or meta_content(html, "description")
    city = source.city_name or first_string(json_ld, ["addressLocality"])
    country = source.country_code or first_string(json_ld, ["addressCountry"])
    brand = source.brand or infer_brand(source.program, name, html)
    points_total = infer_points_total(html)
    cash_krw, cash_usd = infer_cash_total(html)
    confidence = 0.85 if points_total and (cash_krw or cash_usd) else 0.45
    property_id = source.property_id or stable_id(f"{source.program}:{source.url}")

    return ParsedHotel(
        property_id=property_id,
        program=source.program,
        source_url=source.url,
        name=clean_text(name),
        brand=clean_text(brand),
        city_name=clean_text(city),
        country_code=clean_text(country).upper(),
        region_key=clean_text(source.region_key),
        address=clean_text(address),
        image_url=image.strip(),
        points_total=points_total,
        cash_total_krw=cash_krw,
        cash_total_usd=cash_usd,
        availability_status="available" if points_total > 0 else "unknown",
        confidence=confidence,
    )


def parse_json_ld(html: str) -> dict[str, Any]:
    for match in re.finditer(
        r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
        html,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        raw = unescape(match.group(1)).strip()
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if isinstance(data, list):
            for item in data:
                if isinstance(item, dict):
                    return item
        if isinstance(data, dict):
            graph = data.get("@graph")
            if isinstance(graph, list):
                for item in graph:
                    if isinstance(item, dict) and item.get("name"):
                        return item
            return data
    return {}


def meta_content(html: str, key: str) -> str:
    patterns = [
        rf'<meta[^>]+property=["\']{re.escape(key)}["\'][^>]+content=["\']([^"\']+)["\']',
        rf'<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']{re.escape(key)}["\']',
        rf'<meta[^>]+name=["\']{re.escape(key)}["\'][^>]+content=["\']([^"\']+)["\']',
    ]
    for pattern in patterns:
        match = re.search(pattern, html, flags=re.IGNORECASE)
        if match:
            return unescape(match.group(1)).strip()
    return ""


def title_text(html: str) -> str:
    match = re.search(r"<title[^>]*>(.*?)</title>", html, flags=re.I | re.S)
    return unescape(match.group(1)).strip() if match else ""


def first_string(data: Any, keys: list[str]) -> str:
    if not isinstance(data, dict):
        return ""
    for key in keys:
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
        if isinstance(value, dict):
            nested = first_string(value, keys)
            if nested:
                return nested
        if isinstance(value, list):
            for item in value:
                if isinstance(item, str) and item.strip():
                    return item.strip()
                nested = first_string(item, keys)
                if nested:
                    return nested
    return ""


def address_text(data: dict[str, Any]) -> str:
    address = data.get("address") if isinstance(data, dict) else None
    if isinstance(address, str):
        return address
    if not isinstance(address, dict):
        return ""
    parts = [
        address.get("streetAddress"),
        address.get("addressLocality"),
        address.get("addressRegion"),
        address.get("addressCountry"),
    ]
    return ", ".join(str(part).strip() for part in parts if str(part or "").strip())


def infer_brand(program: str, name: str, html: str) -> str:
    text = f"{name} {html[:5000]}".lower()
    brand_hints = {
        "marriott": ["ritz-carlton", "st. regis", "jw marriott", "westin", "sheraton"],
        "hilton": ["waldorf", "conrad", "hilton", "doubletree", "curio"],
        "hyatt": ["park hyatt", "andaz", "grand hyatt", "hyatt regency"],
        "ihg": ["intercontinental", "kimpton", "voco", "crowne plaza", "holiday inn"],
    }
    for hint in brand_hints.get(program, []):
        if hint in text:
            return hint.title()
    return program.title()


def infer_points_total(html: str) -> int:
    candidates: list[int] = []
    for match in re.finditer(
        r"(?<![\d.])(\d{1,3}(?:,\d{3})+|\d{4,7})\s*(?:points|pts|포인트)",
        html,
        flags=re.IGNORECASE,
    ):
        value = int(match.group(1).replace(",", ""))
        if 1000 <= value <= 500000:
            candidates.append(value)
    return min(candidates) if candidates else 0


def infer_cash_total(html: str) -> tuple[int | None, float | None]:
    krw_candidates: list[int] = []
    usd_candidates: list[float] = []
    for match in re.finditer(r"(?:₩|KRW\s*)(\d[\d,]{4,})", html, flags=re.I):
        value = int(match.group(1).replace(",", ""))
        if 10000 <= value <= 10000000:
            krw_candidates.append(value)
    for match in re.finditer(r"(?:\$|USD\s*)(\d[\d,]*(?:\.\d+)?)", html, flags=re.I):
        value = float(match.group(1).replace(",", ""))
        if 30 <= value <= 20000:
            usd_candidates.append(value)
    return (
        min(krw_candidates) if krw_candidates else None,
        min(usd_candidates) if usd_candidates else None,
    )


def build_payload(
    parsed: list[ParsedHotel],
    *,
    date_key: str,
    nights: int,
) -> dict[str, list[dict[str, Any]]]:
    check_in = datetime.fromisoformat(date_key)
    check_out = check_in + timedelta(days=nights)
    properties: list[dict[str, Any]] = []
    snapshots: list[dict[str, Any]] = []
    for hotel in parsed:
        properties.append(
            {
                "id": hotel.property_id,
                "programId": hotel.program,
                "name": hotel.name,
                "brand": hotel.brand,
                "regionKey": hotel.region_key,
                "countryCode": hotel.country_code,
                "cityName": hotel.city_name,
                "address": hotel.address,
                "imageUrls": [hotel.image_url] if hotel.image_url else [],
                "officialUrl": hotel.source_url,
                "source": "official_page_poc",
            },
        )
        if hotel.points_total <= 0 and not hotel.cash_total_krw and not hotel.cash_total_usd:
            continue
        snapshot_id = f"{hotel.program}_{hotel.property_id}_{date_key}_{nights}"
        snapshots.append(
            {
                "id": snapshot_id,
                "propertyId": hotel.property_id,
                "programId": hotel.program,
                "hotelName": hotel.name,
                "brand": hotel.brand,
                "regionKey": hotel.region_key,
                "countryCode": hotel.country_code,
                "cityName": hotel.city_name,
                "address": hotel.address,
                "imageUrl": hotel.image_url,
                "officialUrl": hotel.source_url,
                "checkInDate": _date_key(check_in),
                "checkOutDate": _date_key(check_out),
                "nights": nights,
                "pointsTotal": hotel.points_total,
                "pointsPerNight": round(hotel.points_total / nights)
                if hotel.points_total
                else 0,
                "cashTotalKrw": hotel.cash_total_krw,
                "cashTotalUsd": hotel.cash_total_usd,
                "availabilityStatus": hotel.availability_status,
                "source": "official_page_poc",
                "sourceUrl": hotel.source_url,
                "confidence": hotel.confidence,
            },
        )
    return {"properties": properties, "snapshots": snapshots}


def initialize_firestore(service_account_path: str):
    if firebase_admin is None or credentials is None or firestore is None:
        raise RuntimeError("firebase_admin is required when not using --dry-run.")
    path = Path(service_account_path).expanduser() if service_account_path else None
    if path is None or not path.exists():
        candidates = sorted(ENV_DIR.glob("*firebase-adminsdk*.json"))
        if not candidates:
            raise FileNotFoundError("No Firebase service account JSON found.")
        path = candidates[0]
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(path)))
    return firestore.client()


def write_payload(db, payload: dict[str, list[dict[str, Any]]], *, actor_uid: str) -> None:
    batch = db.batch()
    now = firestore.SERVER_TIMESTAMP
    for prop in payload["properties"]:
        doc_id = prop.pop("id")
        ref = db.collection("hotel_award_properties").document(doc_id)
        batch.set(ref, {**prop, "updatedAt": now, "updatedBy": actor_uid}, merge=True)
    for snapshot in payload["snapshots"]:
        doc_id = snapshot.pop("id")
        ref = db.collection("hotel_award_snapshots").document(doc_id)
        batch.set(
            ref,
            {
                **snapshot,
                "fetchedAt": now,
                "expiresAt": datetime.now(timezone.utc) + timedelta(hours=24),
                "updatedBy": actor_uid,
            },
            merge=True,
        )
    batch.commit()


def run_job_mode(args: argparse.Namespace) -> int:
    db = None if args.dry_run and args.job_file else initialize_firestore(args.service_account)
    run_ref = None
    if db is not None and not args.dry_run:
        run_ref = db.collection(RUN_COLLECTION).document()
        run_ref.set(
            {
                "startedAt": server_timestamp(),
                "mode": "collector",
                "jobId": args.job_id or "",
                "jobBatch": args.job_batch or "",
                "jobTypes": args.job_type,
                "actorUid": args.actor_uid,
                "dryRun": False,
            },
        )

    if args.job_file:
        jobs = load_jobs_from_file(args.job_file)
        if args.limit > 0:
            jobs = jobs[: args.limit]
        job_items = [(job, None) for job in jobs]
    elif args.job_id:
        if db is None:
            raise RuntimeError("--job-id requires Firestore.")
        doc = db.collection(JOB_COLLECTION).document(args.job_id).get()
        if not doc.exists:
            print(f"Job not found: {args.job_id}", file=sys.stderr)
            return 2
        job_items = [(with_doc_id(doc.to_dict() or {}, doc.id), doc.reference)]
    else:
        if db is None:
            raise RuntimeError("--job-batch requires Firestore.")
        docs = load_queued_job_docs(
            db,
            job_types=set(args.job_type),
            limit=args.limit,
            max_scan=max(args.max_queued_scan, args.limit or 0, 1),
        )
        job_items = [(with_doc_id(doc.to_dict() or {}, doc.id), doc.reference) for doc in docs]

    results: list[dict[str, Any]] = []
    for index, (job, job_ref) in enumerate(job_items):
        if job_ref is not None and not args.dry_run:
            if not claim_job(job_ref, job, actor_uid=args.actor_uid):
                results.append(
                    {
                        "jobId": job.get("id", ""),
                        "status": "skipped",
                        "reason": "not_queued",
                    },
                )
                continue
        results.append(process_job(job, args=args, db=db, job_ref=job_ref))
        if args.domain_delay_seconds > 0 and index < len(job_items) - 1:
            time.sleep(args.domain_delay_seconds)

    summary = summarize_results(results)
    if run_ref is not None:
        run_ref.set(
            {
                "finishedAt": server_timestamp(),
                **summary,
            },
            merge=True,
        )
    print(json.dumps({"summary": summary, "results": results}, ensure_ascii=False, indent=2, default=str))
    return 1 if summary["failedCount"] > 0 else 0


def load_jobs_from_file(path: str) -> list[dict[str, Any]]:
    raw = json.loads(Path(path).expanduser().read_text(encoding="utf-8"))
    if isinstance(raw, list):
        items = raw
    elif isinstance(raw, dict):
        items = raw.get("jobs") or raw.get("queuedJobs") or raw.get("results") or []
    else:
        items = []
    jobs: list[dict[str, Any]] = []
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        job = dict(item)
        if "job" in job and isinstance(job["job"], dict):
            job = dict(job["job"])
        job.setdefault("id", as_string(job.get("id")) or f"job_file_{index}")
        jobs.append(job)
    return jobs


def load_queued_job_docs(
    db,
    *,
    job_types: set[str],
    limit: int,
    max_scan: int,
) -> list[Any]:
    now = datetime.now(timezone.utc)
    query = db.collection(JOB_COLLECTION)
    if FieldFilter is not None:
        query = query.where(filter=FieldFilter("status", "==", "queued"))
    else:
        query = query.where("status", "==", "queued")
    docs = list(query.limit(max_scan).stream())
    due_docs = []
    for doc in docs:
        data = doc.to_dict() or {}
        if job_types and as_string(data.get("jobType")) not in job_types:
            continue
        scheduled_for = as_datetime(data.get("scheduledFor")) or now
        if scheduled_for > now:
            continue
        due_docs.append(doc)
    due_docs.sort(key=lambda doc: queued_sort_key(doc.to_dict() or {}))
    return due_docs[:limit] if limit > 0 else due_docs


def queued_sort_key(data: dict[str, Any]) -> tuple[int, datetime]:
    priority = as_int(data.get("priority"))
    scheduled_for = as_datetime(data.get("scheduledFor")) or datetime.now(timezone.utc)
    return (-priority, scheduled_for)


def claim_job(job_ref, job: dict[str, Any], *, actor_uid: str) -> bool:
    latest = job_ref.get()
    latest_data = latest.to_dict() or {}
    if as_string(latest_data.get("status")) != "queued":
        return False
    job_ref.update(
        {
            "status": "running",
            "lockedAt": server_timestamp(),
            "lockedBy": actor_uid,
            "updatedAt": server_timestamp(),
            "attemptCount": firestore.Increment(1),
        },
    )
    job["status"] = "running"
    return True


def process_job(
    job: dict[str, Any],
    *,
    args: argparse.Namespace,
    db,
    job_ref,
) -> dict[str, Any]:
    job_id = as_string(job.get("id"))
    job_type = as_string(job.get("jobType"))
    source = source_from_job(job)
    date_key = job_date_key(job, fallback=args.date)
    nights = max(as_int(job.get("nights"), fallback=args.nights), 1)

    result: dict[str, Any] = {
        "jobId": job_id,
        "jobType": job_type,
        "propertyId": source.property_id,
        "programId": source.program,
        "checkInDate": date_key,
        "nights": nights,
    }

    skip_reason = job_skip_reason(source)
    if skip_reason:
        mark_job_finished(job_ref, "skipped", {"skipReason": skip_reason})
        return {**result, "status": "skipped", "reason": skip_reason}

    try:
        parsed = [collect_source_strict(source)]
        payload = build_payload(parsed, date_key=date_key, nights=nights)
        enrich_payload_with_job(payload, job)
        property_count = len(payload["properties"])
        snapshot_count = len(payload["snapshots"])
        if args.dry_run:
            return {
                **result,
                "status": "dry_run",
                "propertyCount": property_count,
                "snapshotCount": snapshot_count,
                "payload": payload,
            }
        if db is None:
            raise RuntimeError("Firestore is required when not using --dry-run.")
        write_payload(db, payload, actor_uid=args.actor_uid)
        mark_job_finished(
            job_ref,
            "done",
            {
                "propertyCount": property_count,
                "snapshotCount": snapshot_count,
                "lastFetchedAt": server_timestamp(),
            },
        )
        return {
            **result,
            "status": "done",
            "propertyCount": property_count,
            "snapshotCount": snapshot_count,
        }
    except Exception as exc:  # noqa: BLE001 - cron diagnostics should survive one bad job.
        message = str(exc)
        mark_job_finished(job_ref, "failed", {"lastError": message})
        print(f"Failed job {job_id or source.url}: {message}", file=sys.stderr)
        return {**result, "status": "failed", "error": message}


def mark_job_finished(job_ref, status: str, fields: dict[str, Any]) -> None:
    if job_ref is None:
        return
    job_ref.set(
        {
            "status": status,
            "finishedAt": server_timestamp(),
            "updatedAt": server_timestamp(),
            **fields,
        },
        merge=True,
    )


def summarize_results(results: list[dict[str, Any]]) -> dict[str, int]:
    return {
        "jobCount": len(results),
        "doneCount": sum(1 for item in results if item.get("status") == "done"),
        "dryRunCount": sum(1 for item in results if item.get("status") == "dry_run"),
        "skippedCount": sum(1 for item in results if item.get("status") == "skipped"),
        "failedCount": sum(1 for item in results if item.get("status") == "failed"),
        "propertyCount": sum(as_int(item.get("propertyCount")) for item in results),
        "snapshotCount": sum(as_int(item.get("snapshotCount")) for item in results),
    }


def source_from_job(job: dict[str, Any]) -> Source:
    conditions = job.get("conditions") if isinstance(job.get("conditions"), dict) else {}

    def field(name: str) -> Any:
        return job.get(name) if job.get(name) not in (None, "") else conditions.get(name)

    return Source(
        program=as_string(field("programId") or field("program")).lower(),
        url=as_string(field("sourceUrl") or field("officialUrl") or field("url")),
        region_key=as_string(field("regionKey")),
        city_name=as_string(field("cityName")),
        country_code=as_string(field("countryCode")),
        property_id=as_string(field("propertyId")),
        hotel_name=as_string(field("hotelName") or field("name")),
        brand=as_string(field("brand")),
        source_id=as_string(field("sourceId")),
    )


def job_skip_reason(source: Source) -> str:
    if not source.program or source.program not in PROGRAMS:
        return "unsupported_program"
    if not source.url:
        return "missing_source_url"
    if is_blocked_source(source):
        return "blocked_source"
    return ""


def job_date_key(job: dict[str, Any], *, fallback: str) -> str:
    value = job.get("checkInDate") or job.get("checkIn") or job.get("date")
    if isinstance(value, datetime):
        return _date_key(value)
    text = as_string(value)
    return text[:10] if text else fallback


def enrich_payload_with_job(
    payload: dict[str, list[dict[str, Any]]],
    job: dict[str, Any],
) -> None:
    for collection in ("properties", "snapshots"):
        for item in payload[collection]:
            item["crawlJobId"] = as_string(job.get("id"))
            item["crawlJobType"] = as_string(job.get("jobType"))
            if as_string(job.get("sourceId")):
                item["sourceId"] = as_string(job.get("sourceId"))


def with_doc_id(data: dict[str, Any], doc_id: str) -> dict[str, Any]:
    copy = dict(data)
    copy.setdefault("id", doc_id)
    return copy


def server_timestamp():
    return firestore.SERVER_TIMESTAMP


def stable_id(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:20]


def clean_text(value: str) -> str:
    return re.sub(r"\s+", " ", unescape(value or "")).strip()


def as_string(value: Any, fallback: str = "") -> str:
    if value is None:
        return fallback
    if isinstance(value, str):
        return value.strip()
    return str(value).strip()


def as_int(value: Any, fallback: int = 0) -> int:
    if isinstance(value, bool):
        return fallback
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        match = re.search(r"-?\d+", value.replace(",", ""))
        return int(match.group(0)) if match else fallback
    return fallback


def as_datetime(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, str) and value.strip():
        text = value.strip().replace("Z", "+00:00")
        try:
            parsed = datetime.fromisoformat(text)
            return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
        except ValueError:
            return None
    return None


def _date_key(value: datetime) -> str:
    return value.strftime("%Y-%m-%d")


if __name__ == "__main__":
    raise SystemExit(main())
