from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:  # pragma: no cover - dry-run with --source-file can run without it.
    firebase_admin = None
    credentials = None
    firestore = None


ROOT_DIR = Path(__file__).resolve().parents[2]
ENV_DIR = ROOT_DIR / "env"
SEOUL = timezone(timedelta(hours=9))

PROGRAMS = {"marriott", "hilton", "hyatt", "ihg"}
SOURCE_COLLECTION = "hotel_award_sources"
PROPERTY_COLLECTION = "hotel_award_properties"
JOB_COLLECTION = "hotel_award_crawl_jobs"
RUN_COLLECTION = "hotel_award_crawl_runs"
ALERT_COLLECTION_GROUP = "hotel_award_alerts"

JOB_TYPES = ("master", "popular", "alert", "urgent", "backfill")
JOB_WINDOW_HOURS = {
    "master": 24 * 7,
    "popular": 24,
    "alert": 12,
    "urgent": 4,
    "backfill": 24 * 3,
}
JOB_PRIORITIES = {
    "master": 30,
    "popular": 60,
    "alert": 80,
    "urgent": 100,
    "backfill": 20,
}
DEFAULT_DATE_OFFSETS = {
    "master": [30],
    "popular": [7, 14, 21, 30, 45, 60, 90],
    "backfill": [30, 60, 90, 120, 180],
}
DEFAULT_NIGHTS = {
    "master": [1],
    "popular": [1, 2, 5],
    "backfill": [1, 2],
}
POPULAR_REGION_KEYS = {
    "KR_SEOUL",
    "KR_JEJU",
    "JP_TOKYO",
    "JP_OSAKA",
    "JP_FUKUOKA",
    "SG_SINGAPORE",
    "TH_THAILAND",
    "VN_VIETNAM",
}


@dataclass(frozen=True)
class HotelSource:
    source_id: str
    program_id: str
    property_id: str
    source_url: str
    official_url: str
    hotel_name: str = ""
    brand: str = ""
    region_key: str = ""
    city_name: str = ""
    country_code: str = ""
    is_active: bool = True
    is_popular: bool = False


@dataclass(frozen=True)
class CrawlJob:
    id: str
    job_type: str
    program_id: str
    property_id: str
    source_url: str
    official_url: str
    check_in_date: str
    nights: int
    priority: int
    dedupe_key: str
    dedupe_bucket: str
    dedupe_window_hours: int
    scheduled_for: datetime
    source_id: str = ""
    hotel_name: str = ""
    brand: str = ""
    region_key: str = ""
    city_name: str = ""
    country_code: str = ""
    reason: str = ""
    alert_refs: tuple[str, ...] = ()

    def to_firestore(self, *, actor_uid: str) -> dict[str, Any]:
        return {
            "jobType": self.job_type,
            "status": "queued",
            "priority": self.priority,
            "programId": self.program_id,
            "propertyId": self.property_id,
            "sourceId": self.source_id,
            "sourceUrl": self.source_url,
            "officialUrl": self.official_url,
            "hotelName": self.hotel_name,
            "brand": self.brand,
            "regionKey": self.region_key,
            "cityName": self.city_name,
            "countryCode": self.country_code,
            "checkInDate": self.check_in_date,
            "nights": self.nights,
            "dedupeKey": self.dedupe_key,
            "dedupeBucket": self.dedupe_bucket,
            "dedupeWindowHours": self.dedupe_window_hours,
            "scheduledFor": self.scheduled_for,
            "reason": self.reason,
            "alertRefs": list(self.alert_refs),
            "attemptCount": 0,
            "createdAt": server_timestamp(),
            "updatedAt": server_timestamp(),
            "createdBy": actor_uid,
        }

    def to_json(self) -> dict[str, Any]:
        data = self.to_firestore(actor_uid="dry_run")
        data["id"] = self.id
        data["scheduledFor"] = self.scheduled_for.isoformat()
        data["createdAt"] = None
        data["updatedAt"] = None
        return data


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build due hotel award crawl jobs for Ubuntu cron.",
    )
    parser.add_argument("--mode", choices=(*JOB_TYPES, "all"), default="popular")
    parser.add_argument("--program", choices=sorted(PROGRAMS))
    parser.add_argument("--region", action="append", default=[])
    parser.add_argument("--source-file", help="Optional local hotel_award_sources JSON.")
    parser.add_argument("--date-offsets", help="Comma-separated day offsets from --now.")
    parser.add_argument("--nights", help="Comma-separated night counts.")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--now", help="ISO timestamp. Defaults to current Seoul time.")
    parser.add_argument("--service-account", default="")
    parser.add_argument("--actor-uid", default="task_build_hotel_award_jobs")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    now = parse_now(args.now)
    db = maybe_initialize_firestore(args)

    sources = load_sources(db, args)
    source_index = {source.property_id: source for source in sources}
    jobs: list[CrawlJob] = []
    for mode in selected_modes(args.mode):
        if mode == "master":
            jobs.extend(build_source_jobs("master", sources, args=args, now=now))
        elif mode == "popular":
            popular_sources = [
                source
                for source in sources
                if source.is_popular or source.region_key in POPULAR_REGION_KEYS
            ]
            jobs.extend(build_source_jobs("popular", popular_sources, args=args, now=now))
        elif mode == "backfill":
            backfill_sources = [
                source
                for source in sources
                if not source.is_popular and source.region_key not in POPULAR_REGION_KEYS
            ]
            jobs.extend(build_source_jobs("backfill", backfill_sources, args=args, now=now))
        elif mode in {"alert", "urgent"}:
            jobs.extend(load_alert_jobs(db, mode=mode, source_index=source_index, now=now))

    jobs = collapse_duplicate_jobs(jobs)
    jobs.sort(key=lambda job: (-job.priority, job.check_in_date, job.hotel_name, job.id))
    if args.limit > 0:
        jobs = jobs[: args.limit]

    if args.dry_run:
        print(
            json.dumps(
                {
                    "mode": args.mode,
                    "now": now.isoformat(),
                    "sourceCount": len(sources),
                    "jobCount": len(jobs),
                    "jobsByType": count_by_type(jobs),
                    "jobs": [job.to_json() for job in jobs],
                },
                ensure_ascii=False,
                indent=2,
            ),
        )
        return 0

    if db is None:
        raise RuntimeError("Firestore is required when not using --dry-run.")

    run_ref = db.collection(RUN_COLLECTION).document()
    run_ref.set(
        {
            "startedAt": server_timestamp(),
            "mode": "builder",
            "builderMode": args.mode,
            "actorUid": args.actor_uid,
            "dryRun": False,
        },
    )
    result = write_jobs(db, jobs, actor_uid=args.actor_uid)
    run_ref.set({"finishedAt": server_timestamp(), **result}, merge=True)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


def selected_modes(mode: str) -> tuple[str, ...]:
    return JOB_TYPES if mode == "all" else (mode,)


def build_source_jobs(
    job_type: str,
    sources: list[HotelSource],
    *,
    args: argparse.Namespace,
    now: datetime,
) -> list[CrawlJob]:
    offsets = parse_int_list(args.date_offsets) or DEFAULT_DATE_OFFSETS[job_type]
    nights_list = parse_int_list(args.nights) or DEFAULT_NIGHTS[job_type]
    region_filters = set(args.region)
    jobs: list[CrawlJob] = []
    for source in sources:
        if args.program and source.program_id != args.program:
            continue
        if region_filters and source.region_key not in region_filters:
            continue
        if not source.is_active:
            continue
        for offset in offsets:
            check_in = now + timedelta(days=offset)
            for nights in nights_list:
                jobs.append(
                    make_job(
                        job_type=job_type,
                        source=source,
                        check_in=check_in,
                        nights=max(nights, 1),
                        now=now,
                        reason=f"{job_type}_cadence",
                    ),
                )
    return jobs


def load_alert_jobs(
    db,
    *,
    mode: str,
    source_index: dict[str, HotelSource],
    now: datetime,
) -> list[CrawlJob]:
    if db is None:
        return []
    jobs: list[CrawlJob] = []
    today = now.date()
    query = db.collection_group(ALERT_COLLECTION_GROUP)
    for doc in query.stream():
        data = doc.to_dict() or {}
        if data.get("isActive") is False:
            continue
        if data.get("pushEnabled") is False:
            continue
        conditions = data.get("conditions") if isinstance(data.get("conditions"), dict) else {}
        property_id = as_string(conditions.get("propertyId") or data.get("propertyId"))
        program_id = as_string(conditions.get("programId") or data.get("programId")).lower()
        check_in = parse_date(conditions.get("checkInDate") or data.get("checkInDate"))
        if not property_id or not program_id or check_in is None:
            continue
        days_until = (check_in.date() - today).days
        if days_until < 0:
            continue
        target_mode = "urgent" if days_until <= 7 else "alert"
        if target_mode != mode:
            continue

        base_source = source_index.get(property_id)
        source = HotelSource(
            source_id=base_source.source_id if base_source else "",
            program_id=program_id,
            property_id=property_id,
            source_url=as_string(
                conditions.get("sourceUrl")
                or conditions.get("officialUrl")
                or data.get("sourceUrl")
                or data.get("officialUrl")
                or (base_source.source_url if base_source else ""),
            ),
            official_url=as_string(
                conditions.get("officialUrl")
                or data.get("officialUrl")
                or (base_source.official_url if base_source else ""),
            ),
            hotel_name=as_string(
                conditions.get("hotelName")
                or data.get("hotelName")
                or (base_source.hotel_name if base_source else ""),
            ),
            brand=as_string(
                conditions.get("brand")
                or data.get("brand")
                or (base_source.brand if base_source else ""),
            ),
            region_key=as_string(
                conditions.get("regionKey")
                or data.get("regionKey")
                or (base_source.region_key if base_source else ""),
            ),
            city_name=as_string(
                conditions.get("cityName")
                or data.get("cityName")
                or (base_source.city_name if base_source else ""),
            ),
            country_code=as_string(
                conditions.get("countryCode")
                or data.get("countryCode")
                or (base_source.country_code if base_source else ""),
            ),
        )
        jobs.append(
            make_job(
                job_type=mode,
                source=source,
                check_in=check_in,
                nights=max(as_int(conditions.get("nights") or data.get("nights"), 1), 1),
                now=now,
                reason=f"user_{mode}_alert",
                alert_refs=(doc.reference.path,),
            ),
        )
    return jobs


def make_job(
    *,
    job_type: str,
    source: HotelSource,
    check_in: datetime,
    nights: int,
    now: datetime,
    reason: str,
    alert_refs: tuple[str, ...] = (),
) -> CrawlJob:
    check_in_date = date_key(check_in)
    property_id = source.property_id or stable_id(f"{source.program_id}:{source.source_url}")
    dedupe_key = "_".join([source.program_id, property_id, check_in_date, str(nights)])
    window_hours = JOB_WINDOW_HOURS[job_type]
    bucket = bucket_start(now, window_hours)
    job_id = stable_id(f"{job_type}:{dedupe_key}:{bucket.isoformat()}")
    return CrawlJob(
        id=job_id,
        job_type=job_type,
        program_id=source.program_id,
        property_id=property_id,
        source_id=source.source_id,
        source_url=source.source_url or source.official_url,
        official_url=source.official_url or source.source_url,
        hotel_name=source.hotel_name,
        brand=source.brand,
        region_key=source.region_key,
        city_name=source.city_name,
        country_code=source.country_code,
        check_in_date=check_in_date,
        nights=nights,
        priority=JOB_PRIORITIES[job_type],
        dedupe_key=dedupe_key,
        dedupe_bucket=bucket.isoformat(),
        dedupe_window_hours=window_hours,
        scheduled_for=now,
        reason=reason,
        alert_refs=alert_refs,
    )


def collapse_duplicate_jobs(jobs: list[CrawlJob]) -> list[CrawlJob]:
    merged: dict[str, CrawlJob] = {}
    for job in jobs:
        existing = merged.get(job.id)
        if existing is None:
            merged[job.id] = job
            continue
        alert_refs = tuple(sorted(set((*existing.alert_refs, *job.alert_refs))))
        merged[job.id] = CrawlJob(
            **{
                **existing.__dict__,
                "priority": max(existing.priority, job.priority),
                "alert_refs": alert_refs,
            },
        )
    return list(merged.values())


def write_jobs(db, jobs: list[CrawlJob], *, actor_uid: str) -> dict[str, Any]:
    created = 0
    duplicate = 0
    for job in jobs:
        ref = db.collection(JOB_COLLECTION).document(job.id)
        existing = ref.get()
        if existing.exists:
            duplicate += 1
            if job.alert_refs:
                ref.set(
                    {
                        "alertRefs": firestore.ArrayUnion(list(job.alert_refs)),
                        "updatedAt": server_timestamp(),
                    },
                    merge=True,
                )
            continue
        ref.set(job.to_firestore(actor_uid=actor_uid))
        created += 1
    return {
        "candidateCount": len(jobs),
        "createdCount": created,
        "duplicateCount": duplicate,
        "jobsByType": count_by_type(jobs),
    }


def load_sources(db, args: argparse.Namespace) -> list[HotelSource]:
    sources: list[HotelSource] = []
    if db is not None:
        for doc in db.collection(PROPERTY_COLLECTION).stream():
            data = doc.to_dict() or {}
            sources.append(source_from_map(data, doc.id))
        for doc in db.collection(SOURCE_COLLECTION).stream():
            data = doc.to_dict() or {}
            sources.append(source_from_map(data, doc.id))
    if args.source_file:
        raw = json.loads(Path(args.source_file).expanduser().read_text(encoding="utf-8"))
        items = raw if isinstance(raw, list) else raw.get("sources", [])
        sources.extend(source_from_map(item, str(index)) for index, item in enumerate(items) if isinstance(item, dict))
    unique: dict[str, HotelSource] = {}
    for source in sources:
        if source.program_id not in PROGRAMS or not source.source_url:
            continue
        key = source.property_id or source.source_id or source.source_url
        unique[key] = source
    return list(unique.values())


def source_from_map(data: dict[str, Any], doc_id: str) -> HotelSource:
    program_id = as_string(data.get("programId") or data.get("program")).lower()
    source_url = as_string(data.get("sourceUrl") or data.get("officialUrl") or data.get("url"))
    official_url = as_string(data.get("officialUrl") or source_url)
    property_id = as_string(data.get("propertyId") or data.get("chainPropertyId") or doc_id)
    return HotelSource(
        source_id=as_string(data.get("sourceId") or data.get("id") or doc_id),
        program_id=program_id,
        property_id=property_id,
        source_url=source_url,
        official_url=official_url,
        hotel_name=as_string(data.get("hotelName") or data.get("name")),
        brand=as_string(data.get("brand")),
        region_key=as_string(data.get("regionKey")),
        city_name=as_string(data.get("cityName")),
        country_code=as_string(data.get("countryCode")).upper(),
        is_active=data.get("isActive") is not False and as_string(data.get("status")).lower() != "disabled",
        is_popular=as_bool(data.get("isPopular"))
        or as_int(data.get("popularityScore")) > 0
        or as_string(data.get("priorityTier")).lower() in {"popular", "top", "hot"},
    )


def maybe_initialize_firestore(args: argparse.Namespace):
    try:
        return initialize_firestore(args.service_account)
    except Exception as exc:  # noqa: BLE001 - dry-run/source-file should still be usable.
        if not args.dry_run:
            raise
        print(f"Firestore unavailable in dry-run: {exc}", file=sys.stderr)
        return None


def initialize_firestore(service_account_path: str):
    if firebase_admin is None or credentials is None or firestore is None:
        raise RuntimeError("firebase_admin is required for Firestore access.")
    path = Path(service_account_path).expanduser() if service_account_path else None
    if path is None or not path.exists():
        candidates = [
            *sorted(ENV_DIR.glob("mileage*firebase-adminsdk*.json")),
            *sorted(ENV_DIR.glob("mileage*.json")),
            *sorted(ENV_DIR.glob("*firebase-adminsdk*.json")),
        ]
        if not candidates:
            raise FileNotFoundError(f"No Firebase service account JSON found in {ENV_DIR}")
        path = candidates[0]
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(path)))
    return firestore.client()


def count_by_type(jobs: list[CrawlJob]) -> dict[str, int]:
    counts = {job_type: 0 for job_type in JOB_TYPES}
    for job in jobs:
        counts[job.job_type] = counts.get(job.job_type, 0) + 1
    return {key: value for key, value in counts.items() if value > 0}


def parse_now(value: str) -> datetime:
    if not value:
        return datetime.now(SEOUL)
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=SEOUL)


def parse_date(value: Any) -> datetime | None:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=SEOUL)
    text = as_string(value)
    if not text:
        return None
    try:
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", text):
            return datetime.fromisoformat(text).replace(tzinfo=SEOUL)
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=SEOUL)
    except ValueError:
        return None


def parse_int_list(value: str | None) -> list[int]:
    if not value:
        return []
    return [int(part) for part in re.split(r"[,\s]+", value) if part.strip()]


def bucket_start(now: datetime, window_hours: int) -> datetime:
    utc_now = now.astimezone(timezone.utc)
    window_seconds = window_hours * 3600
    bucket = int(utc_now.timestamp()) // window_seconds
    return datetime.fromtimestamp(bucket * window_seconds, timezone.utc)


def date_key(value: datetime) -> str:
    return value.astimezone(SEOUL).strftime("%Y-%m-%d")


def stable_id(value: str) -> str:
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:24]


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


def as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    if isinstance(value, (int, float)):
        return value > 0
    return False


def server_timestamp():
    return firestore.SERVER_TIMESTAMP if firestore is not None else None


if __name__ == "__main__":
    raise SystemExit(main())
