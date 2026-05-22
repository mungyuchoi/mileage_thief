from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore


ROOT_DIR = Path(__file__).resolve().parents[4]
ENV_DIR = ROOT_DIR / "env"
DEFAULT_INPUT = ROOT_DIR / "task" / "point" / "hotel" / "marriott" / "marriott_cjuju_hotel_meta_live.json"


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
        description="Upload parsed point hotel metadata into Firestore.",
    )
    parser.add_argument(
        "--input",
        default=str(DEFAULT_INPUT),
        help="Parsed hotel metadata JSON from parse_marriott_hotel.js.",
    )
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Firebase service account JSON.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print target document without writing.",
    )
    return parser.parse_args()


def initialize_firebase(service_account_path: str) -> firestore.Client:
    service_account = Path(service_account_path).resolve()
    if not service_account.exists():
        raise FileNotFoundError(f"Service account file not found: {service_account}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(service_account))
        firebase_admin.initialize_app(cred)
    return firestore.client()


def clean_map(value: dict[str, Any]) -> dict[str, Any]:
    return {key: item for key, item in value.items() if item is not None}


def build_hotel_doc(hotel: dict[str, Any], exists: bool) -> dict[str, Any]:
    rating = hotel.get("rating")
    sort_score = int(float(rating) * 100) if isinstance(rating, (int, float)) else 0
    doc = clean_map(
        {
            "hotelId": hotel["hotelId"],
            "programId": hotel.get("programId", "marriott"),
            "loyaltyProgram": hotel.get("loyaltyProgram", "Marriott Bonvoy"),
            "propertyCode": hotel.get("propertyCode"),
            "name": hotel.get("name"),
            "city": hotel.get("city"),
            "country": hotel.get("country"),
            "address": hotel.get("address"),
            "geo": hotel.get("geo"),
            "brand": hotel.get("brand"),
            "officialUrl": hotel.get("officialUrl"),
            "phone": hotel.get("phone"),
            "checkInTime": hotel.get("checkInTime"),
            "checkOutTime": hotel.get("checkOutTime"),
            "reviewCount": hotel.get("reviewCount"),
            "rating": rating,
            "guestFavorite": hotel.get("guestFavorite", False),
            "imageUrl": hotel.get("imageUrl"),
            "galleryUrls": hotel.get("galleryUrls", []),
            "mapUrl": hotel.get("mapUrl"),
            "description": hotel.get("description"),
            "amenities": hotel.get("amenities", []),
            "amenityKeys": hotel.get("amenityKeys", []),
            "amenityDetails": hotel.get("amenityDetails", []),
            "detailSections": hotel.get("detailSections", []),
            "searchTokens": hotel.get("searchTokens", []),
            "sortScore": sort_score,
            "status": "active",
            "metadataSource": hotel.get("source"),
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
    if not exists:
        doc["createdAt"] = firestore.SERVER_TIMESTAMP
    return doc


def upload_hotel(db: firestore.Client, hotel: dict[str, Any], dry_run: bool) -> None:
    hotel_id = hotel.get("hotelId")
    if not hotel_id:
        raise ValueError("hotelId is required in parsed hotel JSON.")

    program_doc = {
        "programId": "marriott",
        "label": "메리어트",
        "programName": "Marriott Bonvoy",
        "brandKeywords": [
            "marriott",
            "jw marriott",
            "westin",
            "sheraton",
            "ritz",
            "st. regis",
            "le meridien",
        ],
        "displayOrder": 10,
        "isActive": True,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }

    hotel_ref = db.collection("pointHotels").document(hotel_id)
    exists = hotel_ref.get().exists
    hotel_doc = build_hotel_doc(hotel, exists)

    if dry_run:
        print(json.dumps({"pointHotelPrograms/marriott": program_doc}, ensure_ascii=False, indent=2, default=str))
        print(json.dumps({f"pointHotels/{hotel_id}": hotel_doc}, ensure_ascii=False, indent=2, default=str))
        return

    db.collection("pointHotelPrograms").document("marriott").set(program_doc, merge=True)
    hotel_ref.set(hotel_doc, merge=True)
    print(f"[upload] pointHotels/{hotel_id}")


def main() -> None:
    args = parse_args()
    input_path = Path(args.input).resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"Input JSON not found: {input_path}")

    hotel = json.loads(input_path.read_text(encoding="utf-8"))
    db = initialize_firebase(args.service_account)
    upload_hotel(db, hotel, args.dry_run)


if __name__ == "__main__":
    main()
