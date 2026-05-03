from __future__ import annotations

import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1.base_document import DocumentSnapshot


SOURCE_USER_ID = "khIQygcAgIWWNFNwf2JHnSir0Y22"
TARGET_USER_ID = "mt6HglOh7wQzQ5HxcLpGStpjU0J3"
EXPECTED_SOURCE_EMAIL = "jaewook9726@gmail.com"
EXPECTED_TARGET_EMAIL = "jjw97226@gmail.com"
ROOT_COLLECTION = "users"
PRESERVE_FIELDS = ("email", "displayName", "fcmToken", "documentId", "uid")
INVALID_PATH_CHARS = re.compile(r'[<>"/\\|?*\x00-\x1F]')


def find_default_service_account() -> Path:
    env_dir = Path(__file__).resolve().parents[1] / "env"
    matches = sorted(env_dir.glob("mileage*.json"))
    if matches:
        return matches[0]
    return env_dir / "mileagethief-firebase-adminsdk-8gdf2-49e348f31e.json"


def default_backup_dir() -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return Path(__file__).resolve().parent / "user_transfer_backups" / timestamp


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Back up two Firestore users, clear the target user's descendant data, "
            "and copy the source user's data into the target user while preserving "
            "target identity fields."
        ),
    )
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Path to Firebase service account json.",
    )
    parser.add_argument(
        "--backup-dir",
        default=str(default_backup_dir()),
        help="Directory where fresh source and target backups will be written.",
    )
    parser.add_argument(
        "--source-user-id",
        default=SOURCE_USER_ID,
        help="Firestore user document id to copy from.",
    )
    parser.add_argument(
        "--target-user-id",
        default=TARGET_USER_ID,
        help="Firestore user document id to replace.",
    )
    parser.add_argument(
        "--expected-source-email",
        default=EXPECTED_SOURCE_EMAIL,
        help="Abort unless the source user has this email. Pass an empty string to skip.",
    )
    parser.add_argument(
        "--expected-target-email",
        default=EXPECTED_TARGET_EMAIL,
        help="Abort unless the target user has this email. Pass an empty string to skip.",
    )
    parser.add_argument(
        "--preserve-field",
        action="append",
        default=None,
        help=(
            "Target top-level field to preserve. Can be repeated. "
            f"Defaults to: {', '.join(PRESERVE_FIELDS)}"
        ),
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Actually write to Firestore. Without this flag the script only prints a dry run.",
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


def deserialize_value(value: Any, db: firestore.Client) -> Any:
    if isinstance(value, list):
        return [deserialize_value(item, db) for item in value]
    if not isinstance(value, dict):
        return value
    if "__type__" not in value:
        return {str(k): deserialize_value(v, db) for k, v in value.items()}

    value_type = str(value.get("__type__") or "")
    if value_type == "bytes":
        return bytes.fromhex(str(value.get("hex") or ""))
    if value_type in {"datetime", "DatetimeWithNanoseconds"}:
        return parse_iso_datetime(str(value["value"]))
    if value_type in {"GeoPoint", "GeoPointWithNanoseconds"}:
        return firestore.GeoPoint(value["latitude"], value["longitude"])
    if "DocumentReference" in value_type:
        return db.document(str(value["path"]))
    return value.get("value")


def parse_iso_datetime(raw_value: str) -> datetime:
    normalized = raw_value.replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        match = re.match(r"^(.*\.\d{6})\d+([+-]\d\d:\d\d)?$", normalized)
        if match:
            return datetime.fromisoformat("".join(part or "" for part in match.groups()))
        raise


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
    return cleaned or "user"


def write_backup(output_dir: Path, user_doc: DocumentSnapshot) -> tuple[Path, dict[str, Any]]:
    output_dir.mkdir(parents=True, exist_ok=True)
    safe_file_name = safe_path_name(user_doc.id)
    payload = export_document(user_doc)
    payload["backupMeta"] = {
        "userId": user_doc.id,
        "safeFileName": f"{safe_file_name}.json",
        "createdAt": datetime.now().isoformat(timespec="seconds"),
    }

    file_path = output_dir / f"{safe_file_name}.json"
    file_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return file_path, payload


def count_descendant_docs(payload: dict[str, Any]) -> int:
    total = 0
    for docs in payload.get("subcollections", {}).values():
        total += len(docs)
        for doc in docs:
            total += count_descendant_docs(doc)
    return total


def collection_counts(payload: dict[str, Any]) -> dict[str, int]:
    return {
        collection_id: len(docs)
        for collection_id, docs in payload.get("subcollections", {}).items()
    }


def require_user(db: firestore.Client, user_id: str) -> DocumentSnapshot:
    snapshot = db.collection(ROOT_COLLECTION).document(user_id).get()
    if not snapshot.exists:
        raise ValueError(f"User not found: {ROOT_COLLECTION}/{user_id}")
    return snapshot


def validate_email(user_doc: DocumentSnapshot, expected_email: str, label: str) -> None:
    if not expected_email:
        return
    actual_email = (user_doc.to_dict() or {}).get("email")
    if actual_email != expected_email:
        raise ValueError(
            f"{label} email mismatch for {user_doc.reference.path}: "
            f"expected {expected_email!r}, got {actual_email!r}"
        )


def build_target_user_data(
    source_payload: dict[str, Any],
    target_payload: dict[str, Any],
    db: firestore.Client,
    target_user_id: str,
    preserve_fields: tuple[str, ...],
) -> tuple[dict[str, Any], dict[str, Any]]:
    source_data = deserialize_value(source_payload.get("data") or {}, db)
    target_data = deserialize_value(target_payload.get("data") or {}, db)

    preserved = {
        field: target_data[field]
        for field in preserve_fields
        if field in target_data
    }

    if "uid" in preserve_fields and ("uid" in source_data or "uid" in target_data):
        preserved["uid"] = target_data.get("uid") or target_user_id
    if "documentId" in preserve_fields and "documentId" not in preserved and "documentId" in source_data:
        preserved["documentId"] = target_user_id

    next_data = {
        key: value
        for key, value in source_data.items()
        if key not in preserve_fields
    }
    next_data.update(preserved)
    return next_data, preserved


class BatchWriter:
    def __init__(self, db: firestore.Client, dry_run: bool, batch_limit: int = 400) -> None:
        self.db = db
        self.dry_run = dry_run
        self.batch_limit = batch_limit
        self.batch = db.batch()
        self.pending = 0
        self.set_count = 0
        self.delete_count = 0

    def set(self, doc_ref: firestore.DocumentReference, data: dict[str, Any]) -> None:
        self.set_count += 1
        if self.dry_run:
            return
        self.batch.set(doc_ref, data)
        self._mark_pending()

    def delete(self, doc_ref: firestore.DocumentReference) -> None:
        self.delete_count += 1
        if self.dry_run:
            return
        self.batch.delete(doc_ref)
        self._mark_pending()

    def _mark_pending(self) -> None:
        self.pending += 1
        if self.pending >= self.batch_limit:
            self.commit()

    def commit(self) -> None:
        if self.dry_run or self.pending == 0:
            return
        self.batch.commit()
        self.batch = self.db.batch()
        self.pending = 0


def queue_delete_document_tree(
    doc_ref: firestore.DocumentReference,
    writer: BatchWriter,
) -> None:
    for collection_ref in doc_ref.collections():
        for child_doc in collection_ref.stream():
            queue_delete_document_tree(child_doc.reference, writer)
    writer.delete(doc_ref)


def queue_delete_descendants(
    doc_ref: firestore.DocumentReference,
    writer: BatchWriter,
) -> None:
    for collection_ref in doc_ref.collections():
        for child_doc in collection_ref.stream():
            queue_delete_document_tree(child_doc.reference, writer)


def queue_restore_subcollections(
    parent_ref: firestore.DocumentReference,
    payload: dict[str, Any],
    db: firestore.Client,
    writer: BatchWriter,
) -> None:
    for collection_id, docs in payload.get("subcollections", {}).items():
        for doc_payload in docs:
            child_ref = parent_ref.collection(collection_id).document(str(doc_payload["id"]))
            child_data = deserialize_value(doc_payload.get("data") or {}, db)
            writer.set(child_ref, child_data)
            queue_restore_subcollections(child_ref, doc_payload, db, writer)


def transfer_user_data(
    db: firestore.Client,
    source_payload: dict[str, Any],
    target_payload: dict[str, Any],
    target_user_id: str,
    preserve_fields: tuple[str, ...],
    execute: bool,
) -> dict[str, int]:
    target_ref = db.collection(ROOT_COLLECTION).document(target_user_id)
    next_data, preserved = build_target_user_data(
        source_payload,
        target_payload,
        db,
        target_user_id,
        preserve_fields,
    )

    writer = BatchWriter(db, dry_run=not execute)
    queue_delete_descendants(target_ref, writer)
    writer.set(target_ref, next_data)
    queue_restore_subcollections(target_ref, source_payload, db, writer)
    writer.commit()

    print("\n=== Transfer plan ===")
    print(f"mode: {'execute' if execute else 'dry-run'}")
    print(f"target: {target_ref.path}")
    print(f"preserved fields: {', '.join(sorted(preserved.keys())) or '(none)'}")
    print(f"target top-level field count after transfer: {len(next_data)}")
    print(f"target descendant docs queued for delete: {writer.delete_count}")
    print(f"source docs queued for upload, including target root: {writer.set_count}")

    return {
        "deleted_docs": writer.delete_count,
        "written_docs": writer.set_count,
        "top_level_fields": len(next_data),
    }


def main() -> None:
    args = parse_args()
    db = initialize_firebase(args.service_account)
    backup_dir = Path(args.backup_dir).resolve()
    preserve_fields = tuple(args.preserve_field or PRESERVE_FIELDS)

    source_doc = require_user(db, args.source_user_id)
    target_doc = require_user(db, args.target_user_id)
    validate_email(source_doc, args.expected_source_email, "source")
    validate_email(target_doc, args.expected_target_email, "target")

    source_backup_path, source_payload = write_backup(backup_dir, source_doc)
    target_backup_path, target_payload = write_backup(backup_dir, target_doc)

    print("=== Backups ===")
    print(f"source: {source_backup_path}")
    print(f"target: {target_backup_path}")

    print("\n=== Current data ===")
    print(f"source top collections: {collection_counts(source_payload)}")
    print(f"target top collections: {collection_counts(target_payload)}")
    print(f"source descendant docs: {count_descendant_docs(source_payload)}")
    print(f"target descendant docs: {count_descendant_docs(target_payload)}")

    transfer_user_data(
        db=db,
        source_payload=source_payload,
        target_payload=target_payload,
        target_user_id=args.target_user_id,
        preserve_fields=preserve_fields,
        execute=args.execute,
    )

    if not args.execute:
        print("\nNo Firestore writes were made. Re-run with --execute to apply this transfer.")


if __name__ == "__main__":
    main()
