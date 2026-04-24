from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_document import DocumentSnapshot


DEFAULT_SERVICE_ACCOUNT = Path(__file__).resolve().parents[1] / "env" / "mileagethief-firebase-adminsdk-8gdf2-1aed24e38a.json"
DEFAULT_OUTPUT_DIR = Path(__file__).resolve().parents[1] / "task" / "gift_backups"
INVALID_PATH_CHARS = re.compile(r'[<>"/\\|?*\x00-\x1F]')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download all Firestore data for users where hasGift == true.",
    )
    parser.add_argument(
        "--service-account",
        default=str(DEFAULT_SERVICE_ACCOUNT),
        help="Path to Firebase service account json.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory to write backup files into.",
    )
    parser.add_argument(
        "--user-id",
        help="Only download one user uid.",
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


def serialize_value(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, bytes):
        return {"__type__": "bytes", "hex": value.hex()}
    if hasattr(value, "isoformat"):
        try:
            return {"__type__": type(value).__name__, "value": value.isoformat()}
        except TypeError:
            pass
    if isinstance(value, dict):
        return {str(k): serialize_value(v) for k, v in value.items()}
    if isinstance(value, list):
        return [serialize_value(item) for item in value]
    if isinstance(value, tuple):
        return [serialize_value(item) for item in value]
    if hasattr(value, "latitude") and hasattr(value, "longitude"):
        return {
            "__type__": type(value).__name__,
            "latitude": value.latitude,
            "longitude": value.longitude,
        }
    if hasattr(value, "path"):
        return {"__type__": type(value).__name__, "path": value.path}
    return {"__type__": type(value).__name__, "value": str(value)}


def export_document(document: DocumentSnapshot) -> dict[str, Any]:
    payload = {
        "id": document.id,
        "path": document.reference.path,
        "data": serialize_value(document.to_dict() or {}),
        "subcollections": {},
    }

    for collection in document.reference.collections():
        docs = []
        for sub_doc in collection.stream():
            docs.append(export_document(sub_doc))
        payload["subcollections"][collection.id] = docs

    return payload


def safe_path_name(raw_name: str) -> str:
    cleaned = raw_name.strip().replace(":", "[]")
    cleaned = INVALID_PATH_CHARS.sub("_", cleaned)
    cleaned = cleaned.rstrip(" .")
    if not cleaned:
        cleaned = "user"
    return cleaned


def iter_target_users(db: firestore.Client, user_id: str | None) -> list[DocumentSnapshot]:
    users_ref = db.collection("users")
    if user_id:
        snapshot = users_ref.document(user_id).get()
        if not snapshot.exists:
            raise ValueError(f"User not found: {user_id}")
        data = snapshot.to_dict() or {}
        if data.get("hasGift") is not True:
            raise ValueError(f"User {user_id} does not have hasGift == true")
        return [snapshot]

    return list(users_ref.where("hasGift", "==", True).stream())


def write_backup(output_dir: Path, user_doc: DocumentSnapshot) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_file_name = safe_path_name(user_doc.id)

    payload = export_document(user_doc)
    payload["backupMeta"] = {
        "userId": user_doc.id,
        "safeFileName": f"{safe_file_name}.json",
    }
    file_path = output_dir / f"{safe_file_name}.json"
    file_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return file_path


def main() -> None:
    args = parse_args()
    db = initialize_firebase(args.service_account)
    output_dir = Path(args.output_dir).resolve()

    users = iter_target_users(db, args.user_id)
    if not users:
        print("No users found with hasGift == true")
        return

    print(f"Found {len(users)} user(s) to export")
    for user_doc in users:
        file_path = write_backup(output_dir, user_doc)
        print(f"[OK] {user_doc.id} -> {file_path}")


if __name__ == "__main__":
    main()
