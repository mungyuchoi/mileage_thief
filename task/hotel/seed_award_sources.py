from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:  # pragma: no cover - --dry-run can run without Firebase deps.
    firebase_admin = None
    credentials = None
    firestore = None


ROOT_DIR = Path(__file__).resolve().parents[2]
ENV_DIR = ROOT_DIR / "env"
SOURCE_COLLECTION = "hotel_award_sources"
DEFAULT_ACTOR_UID = "task_seed_hotel_award_sources"
SEED_SOURCE = "manual_representative_korean_award_seed_2026_05"


SEED_SOURCES: list[dict[str, Any]] = [
    {
        "propertyId": "marriott_seljw",
        "chainPropertyId": "seljw",
        "programId": "marriott",
        "hotelName": "JW Marriott Hotel Seoul",
        "brand": "JW Marriott",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.marriott.com/en-us/hotels/seljw-jw-marriott-hotel-seoul/",
        "officialUrl": "https://www.marriott.com/en-us/hotels/seljw-jw-marriott-hotel-seoul/",
    },
    {
        "propertyId": "marriott_sellc",
        "chainPropertyId": "sellc",
        "programId": "marriott",
        "hotelName": "Josun Palace, a Luxury Collection Hotel, Seoul Gangnam",
        "brand": "The Luxury Collection",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.marriott.com/en-us/hotels/sellc-josun-palace-a-luxury-collection-hotel-seoul-gangnam/overview/",
        "officialUrl": "https://www.marriott.com/en-us/hotels/sellc-josun-palace-a-luxury-collection-hotel-seoul-gangnam/overview/",
    },
    {
        "propertyId": "marriott_selwi",
        "chainPropertyId": "selwi",
        "programId": "marriott",
        "hotelName": "The Westin Josun Seoul",
        "brand": "Westin",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.marriott.com/en-us/hotels/selwi-the-westin-josun-seoul/overview/",
        "officialUrl": "https://www.marriott.com/en-us/hotels/selwi-the-westin-josun-seoul/overview/",
    },
    {
        "propertyId": "marriott_cjuju",
        "chainPropertyId": "cjuju",
        "programId": "marriott",
        "hotelName": "JW Marriott Jeju Resort & Spa",
        "brand": "JW Marriott",
        "regionKey": "KR_JEJU",
        "cityName": "Seogwipo",
        "countryCode": "KR",
        "sourceUrl": "https://www.marriott.com/en-us/hotels/cjuju-jw-marriott-jeju-resort-and-spa/overview/",
        "officialUrl": "https://www.marriott.com/en-us/hotels/cjuju-jw-marriott-jeju-resort-and-spa/overview/",
    },
    {
        "propertyId": "hyatt_selrs",
        "chainPropertyId": "selrs",
        "programId": "hyatt",
        "hotelName": "Grand Hyatt Seoul",
        "brand": "Grand Hyatt",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.hyatt.com/grand-hyatt/en-US/selrs-grand-hyatt-seoul",
        "officialUrl": "https://www.hyatt.com/grand-hyatt/en-US/selrs-grand-hyatt-seoul",
    },
    {
        "propertyId": "hyatt_selph",
        "chainPropertyId": "selph",
        "programId": "hyatt",
        "hotelName": "Park Hyatt Seoul",
        "brand": "Park Hyatt",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.hyatt.com/park-hyatt/en-US/selph-park-hyatt-seoul",
        "officialUrl": "https://www.hyatt.com/park-hyatt/en-US/selph-park-hyatt-seoul",
    },
    {
        "propertyId": "hyatt_cjugh",
        "chainPropertyId": "cjugh",
        "programId": "hyatt",
        "hotelName": "Grand Hyatt Jeju",
        "brand": "Grand Hyatt",
        "regionKey": "KR_JEJU",
        "cityName": "Jeju",
        "countryCode": "KR",
        "sourceUrl": "https://www.hyatt.com/en-US/hotel/south-korea/grand-hyatt-jeju/cjugh",
        "officialUrl": "https://www.hyatt.com/en-US/hotel/south-korea/grand-hyatt-jeju/cjugh",
    },
    {
        "propertyId": "hilton_selcici",
        "chainPropertyId": "selcici",
        "programId": "hilton",
        "hotelName": "Conrad Seoul",
        "brand": "Conrad",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.hilton.com/en/hotels/selcici-conrad-seoul/",
        "officialUrl": "https://www.hilton.com/en/hotels/selcici-conrad-seoul/",
    },
    {
        "propertyId": "ihg_seoha",
        "chainPropertyId": "seoha",
        "programId": "ihg",
        "hotelName": "InterContinental Grand Seoul Parnas",
        "brand": "InterContinental",
        "regionKey": "KR_SEOUL",
        "cityName": "Seoul",
        "countryCode": "KR",
        "sourceUrl": "https://www.ihg.com/intercontinental/hotels/us/en/seoul/seoha/hoteldetail",
        "officialUrl": "https://www.ihg.com/intercontinental/hotels/us/en/seoul/seoha/hoteldetail",
    },
    {
        "propertyId": "hilton_fukhihi",
        "chainPropertyId": "fukhihi",
        "programId": "hilton",
        "hotelName": "Hilton Fukuoka Sea Hawk",
        "brand": "Hilton",
        "regionKey": "JP_FUKUOKA",
        "cityName": "Fukuoka",
        "countryCode": "JP",
        "sourceUrl": "https://www.hilton.com/en/hotels/fukhihi-hilton-fukuoka-sea-hawk/",
        "officialUrl": "https://www.hilton.com/en/hotels/fukhihi-hilton-fukuoka-sea-hawk/",
    },
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Seed representative hotel award sources into Firestore.",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--service-account", default="")
    parser.add_argument("--actor-uid", default=DEFAULT_ACTOR_UID)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--only-missing",
        action="store_true",
        default=True,
        help="Create missing docs only. This is the default.",
    )
    mode.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite seed-managed fields on existing docs.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payloads = [seed_payload(item, actor_uid=args.actor_uid) for item in SEED_SOURCES]
    if args.dry_run:
        print(
            json.dumps(
                {
                    "collection": SOURCE_COLLECTION,
                    "mode": "overwrite" if args.overwrite else "only_missing",
                    "count": len(payloads),
                    "sources": payloads,
                },
                ensure_ascii=False,
                indent=2,
                default=str,
            ),
        )
        return 0

    db = initialize_firestore(args.service_account)
    result = write_sources(
        db,
        payloads,
        actor_uid=args.actor_uid,
        overwrite=args.overwrite,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    return 0


def seed_payload(source: dict[str, Any], *, actor_uid: str) -> dict[str, Any]:
    now = firestore.SERVER_TIMESTAMP if firestore is not None else datetime.now(timezone.utc).isoformat()
    return {
        **source,
        "sourceId": source["propertyId"],
        "isActive": True,
        "isPopular": True,
        "priorityTier": "popular",
        "sourceType": "official_hotel_page",
        "seedSource": SEED_SOURCE,
        "updatedAt": now,
        "updatedBy": actor_uid,
    }


def write_sources(
    db,
    sources: list[dict[str, Any]],
    *,
    actor_uid: str,
    overwrite: bool,
) -> dict[str, Any]:
    batch = db.batch()
    created = 0
    updated = 0
    skipped = 0
    skipped_ids: list[str] = []

    for source in sources:
        doc_id = source["propertyId"]
        ref = db.collection(SOURCE_COLLECTION).document(doc_id)
        existing = ref.get()
        if existing.exists and not overwrite:
            skipped += 1
            skipped_ids.append(doc_id)
            continue

        payload = dict(source)
        if not existing.exists:
            payload["createdAt"] = firestore.SERVER_TIMESTAMP
            payload["createdBy"] = actor_uid
            created += 1
        else:
            updated += 1
        batch.set(ref, payload, merge=True)

    batch.commit()
    return {
        "collection": SOURCE_COLLECTION,
        "mode": "overwrite" if overwrite else "only_missing",
        "candidateCount": len(sources),
        "createdCount": created,
        "updatedCount": updated,
        "skippedCount": skipped,
        "skippedIds": skipped_ids,
    }


def initialize_firestore(service_account_path: str):
    if firebase_admin is None or credentials is None or firestore is None:
        raise RuntimeError("firebase_admin is required when not using --dry-run.")
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


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        raise SystemExit(130)
