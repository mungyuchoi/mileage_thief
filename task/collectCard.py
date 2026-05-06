from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote

import firebase_admin
import requests
from firebase_admin import credentials, firestore, storage
from google.cloud.firestore_v1 import transactional


ROOT_DIR = Path(__file__).resolve().parents[1]
ENV_DIR = ROOT_DIR / "env"

CARD_GORILLA_API_BASE = "https://api.card-gorilla.com:8080/v1"
CARD_IMAGE_BUCKET = "mileagethief.firebasestorage.app"
CARD_GORILLA_MAX_IMPORT_ID = 100000
MAX_CHUNK_SIZE = 50
DEFAULT_ACTOR_UID = "task_collect_card"
REQUEST_TIMEOUT_SECONDS = 30

MISSING = object()


def find_default_service_account() -> Path:
    candidates = [
        *sorted(ENV_DIR.glob("mileage*firebase-adminsdk*.json")),
        *sorted(ENV_DIR.glob("mileage*.json")),
        *sorted(ENV_DIR.glob("*firebase-adminsdk*.json")),
    ]
    if not candidates:
        raise FileNotFoundError(
            f"No Firebase service account JSON found in {ENV_DIR}"
        )
    return candidates[0]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Collect CardGorilla card details and upload them to "
            "Firestore cards/catalog/cardProducts in 50-card chunks."
        ),
    )
    parser.add_argument("start_id", type=int, help="First CardGorilla card ID.")
    parser.add_argument("end_id", type=int, help="Last CardGorilla card ID.")
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Path to Firebase service account JSON.",
    )
    parser.add_argument(
        "--actor-uid",
        default=DEFAULT_ACTOR_UID,
        help="Value saved to actorUid/updatedByUid fields.",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=MAX_CHUNK_SIZE,
        help="Cards per import run. Values above 50 are capped to 50.",
    )
    parser.add_argument(
        "--skip-images",
        action="store_true",
        help="Do not copy card images into Firebase Storage.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch and normalize cards without writing Firestore/Storage.",
    )
    return parser.parse_args()


def initialize_firebase(service_account_path: str) -> firestore.Client:
    service_account = Path(service_account_path).resolve()
    if not service_account.exists():
        raise FileNotFoundError(f"Service account file not found: {service_account}")

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(service_account))
        firebase_admin.initialize_app(cred, {"storageBucket": CARD_IMAGE_BUCKET})
    return firestore.client()


def card_catalog_ref(db: firestore.Client):
    return db.collection("cards").document("catalog")


def server_timestamp():
    return firestore.SERVER_TIMESTAMP


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def as_id_string(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, bool):
        return ""
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float) and math.isfinite(value):
        return str(int(value)) if value.is_integer() else str(value)
    return ""


def as_optional_string(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    trimmed = value.strip()
    return trimmed if trimmed else None


def as_optional_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)) and math.isfinite(value):
        return float(value)
    if isinstance(value, str) and value.strip():
        try:
            return float(value.replace(",", ""))
        except ValueError:
            return None
    return None


def require_card_text(value: Any, field_name: str) -> str:
    text = value.strip() if isinstance(value, str) else ""
    if not text:
        raise ValueError(f"{field_name}은 필수입니다.")
    return text[:200]


def is_plain_object(value: Any) -> bool:
    return isinstance(value, dict)


def sanitize_card_json_value(value: Any, depth: int = 0) -> Any:
    if depth > 6:
        raise ValueError("카드 정보가 너무 깊습니다.")
    if value is None:
        return None
    if isinstance(value, str):
        return value.strip()[:20000]
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        if not math.isfinite(value):
            raise ValueError("숫자 값이 올바르지 않습니다.")
        return value
    if isinstance(value, list):
        if len(value) > 200:
            raise ValueError("목록 항목이 너무 많습니다.")
        return [sanitize_card_json_value(item, depth + 1) for item in value]
    if isinstance(value, dict):
        if len(value) > 120:
            raise ValueError("카드 정보 항목이 너무 많습니다.")
        output: dict[str, Any] = {}
        for key, nested_value in value.items():
            normalized_key = str(key).strip()
            if not normalized_key:
                continue
            if normalized_key in {"__proto__", "constructor", "prototype"}:
                continue
            output[normalized_key] = sanitize_card_json_value(
                nested_value,
                depth + 1,
            )
        return output
    raise ValueError("지원하지 않는 카드 정보 값입니다.")


def card_hash(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def normalize_card_image_url(value: Any) -> str | None:
    raw_value = value
    if isinstance(value, dict):
        raw_value = value.get("url") or value.get("path") or value.get("src")
    text = as_optional_string(raw_value)
    if not text:
        return None
    if text.startswith("//"):
        return f"https:{text}"
    if text.startswith("http://") or text.startswith("https://"):
        return text
    if text.startswith("/"):
        return f"https://www.card-gorilla.com{text}"
    return text


def image_extension_for(content_type: str | None, url: str) -> str:
    lowered_type = (content_type or "").lower()
    if "png" in lowered_type:
        return "png"
    if "webp" in lowered_type:
        return "webp"
    if "gif" in lowered_type:
        return "gif"

    clean_url = url.split("?", 1)[0].lower()
    extension = clean_url.rsplit(".", 1)[-1] if "." in clean_url else ""
    if extension in {"jpg", "jpeg", "png", "webp", "gif"}:
        return extension
    return "jpg"


def copy_card_image_to_storage(card_id: str, image_url: Any) -> dict[str, Any] | None:
    normalized_url = normalize_card_image_url(image_url)
    if not normalized_url:
        return None

    try:
        response = requests.get(normalized_url, timeout=REQUEST_TIMEOUT_SECONDS)
    except requests.RequestException as error:
        return {
            "sourceUrl": normalized_url,
            "error": str(error),
        }

    if not response.ok:
        return {
            "sourceUrl": normalized_url,
            "fetchStatus": response.status_code,
        }

    content_type = response.headers.get("content-type") or "image/jpeg"
    content = response.content
    content_hash = hashlib.sha256(content).hexdigest()
    extension = image_extension_for(content_type, normalized_url)
    storage_path = f"cards/catalog/cardProducts/{card_id}/images/main.{extension}"
    token = str(uuid.uuid4())

    blob = storage.bucket(CARD_IMAGE_BUCKET).blob(storage_path)
    blob.metadata = {
        "cardId": card_id,
        "sourceUrl": normalized_url,
        "contentHash": content_hash,
        "firebaseStorageDownloadTokens": token,
    }
    blob.upload_from_string(content, content_type=content_type)

    encoded_path = quote(storage_path, safe="")
    return {
        "storagePath": storage_path,
        "sourceUrl": normalized_url,
        "contentHash": content_hash,
        "downloadUrl": (
            f"https://firebasestorage.googleapis.com/v0/b/{CARD_IMAGE_BUCKET}"
            f"/o/{encoded_path}?alt=media&token={token}"
        ),
        "uploadedAtIso": now_iso(),
    }


def normalize_card_gorilla_issuer(item: Any) -> tuple[str, dict[str, Any]] | None:
    if not isinstance(item, dict):
        return None
    idx = as_id_string(item.get("idx") or item.get("no"))
    name_ko = as_optional_string(item.get("name"))
    if not idx or not name_ko:
        return None
    issuer_id = f"cg_{idx}"
    return issuer_id, {
        "sourceType": "cardGorilla",
        "sourceRefs": {
            "cardGorilla": {
                "idx": idx,
            },
        },
        "nameKo": name_ko,
        "nameEng": as_optional_string(item.get("name_eng")),
        "color": as_optional_string(item.get("color")),
        "logoUrl": normalize_card_image_url(item.get("logo_img")),
        "eventEnabled": item.get("event_yn") == "Y" or item.get("is_event") is True,
        "isVisible": item.get("is_visible") is not False,
        "updatedAt": server_timestamp(),
    }


def normalize_card_gorilla_card_type(value: Any) -> str:
    text = str(value or "").strip().upper()
    if text == "CHK":
        return "check"
    if text == "CRD":
        return "credit"
    return "unknown"


def normalize_card_gorilla_status(data: dict[str, Any]) -> str:
    if data.get("is_discon") is True or data.get("is_discon") == 1:
        return "discontinued"
    if data.get("is_visible") is False or data.get("is_visible") == 0:
        return "hidden"
    if data.get("is_impend") is True or data.get("is_impend") == 1:
        return "pending"
    return "active"


def normalize_card_gorilla_top_benefits(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    benefits: list[dict[str, Any]] = []
    for item in value[:30]:
        if not isinstance(item, dict):
            normalized = {"title": str(item or "")}
        else:
            tags = item.get("tags")
            normalized = {
                "title": as_optional_string(item.get("title")),
                "value": as_optional_string(item.get("inputValue")),
                "tags": [str(tag) for tag in tags[:20]] if isinstance(tags, list) else [],
                "logoUrl": normalize_card_image_url(item.get("logo_img")),
            }
        if normalized.get("title") or normalized.get("value"):
            benefits.append(normalized)
    return benefits


def normalize_card_gorilla_product(
    source: dict[str, Any],
    issuer_name_by_idx: dict[str, str],
    copied_image: dict[str, Any] | None,
) -> dict[str, Any]:
    idx = as_id_string(source.get("idx"))
    corp = source.get("corp") if isinstance(source.get("corp"), dict) else {}
    corp_idx = as_id_string(corp.get("idx") or source.get("corp_idx") or source.get("corp"))
    issuer_name = (
        as_optional_string(corp.get("name"))
        or issuer_name_by_idx.get(corp_idx)
        or "카드사 미입력"
    )
    raw_hash = card_hash(source)
    top_benefits = normalize_card_gorilla_top_benefits(source.get("top_benefit"))

    detail_summary = "\n".join(
        " ".join(part for part in [item.get("title"), item.get("value")] if part)
        for item in top_benefits
        if item.get("title") or item.get("value")
    )

    images = (
        {"main": copied_image}
        if copied_image
        else {
            "main": {
                "sourceUrl": normalize_card_image_url(source.get("card_img")),
            },
        }
    )

    return {
        "name": require_card_text(source.get("name"), "카드명"),
        "issuerName": issuer_name,
        "issuerId": f"cg_{corp_idx}" if corp_idx else None,
        "cardType": normalize_card_gorilla_card_type(source.get("cate")),
        "status": normalize_card_gorilla_status(source),
        "sourceType": "cardGorilla",
        "rewardProgram": as_optional_string(source.get("c_type")),
        "annualFee": {
            "summary": as_optional_string(source.get("annual_fee_basic")),
            "detailHtml": as_optional_string(source.get("annual_fee_detail")),
        },
        "previousMonthSpend": {
            "summary": as_optional_string(source.get("pre_month_money")),
        },
        "brands": sanitize_card_json_value(source.get("brand") or []),
        "primaryBenefits": top_benefits,
        "calculatorRules": [],
        "exclusions": [],
        "detailSummary": detail_summary,
        "sourceRefs": {
            "cardGorilla": {
                "idx": idx,
                "cid": as_optional_string(source.get("cid")),
                "apiUrl": f"{CARD_GORILLA_API_BASE}/cards/{idx}",
                "detailUrl": f"https://www.card-gorilla.com/card/detail/{idx}",
                "fetchedAtIso": now_iso(),
                "rawHash": raw_hash,
            },
        },
        "images": images,
        "quality": {
            "status": "sourceImported",
            "parserVersion": 1,
        },
    }


def normalize_card_gorilla_detail_sections(source: dict[str, Any]) -> list[dict[str, Any]]:
    sections: list[dict[str, Any]] = []
    fee_html = as_optional_string(source.get("annual_fee_detail"))
    if fee_html:
        sections.append(
            {
                "id": "annual_fee",
                "title": "연회비 상세",
                "type": "annualFee",
                "html": fee_html,
                "sortOrder": 0,
            }
        )

    benefits = source.get("key_benefit") if isinstance(source.get("key_benefit"), list) else []
    for index, benefit in enumerate(benefits[:80]):
        if not isinstance(benefit, dict):
            continue
        title = (
            as_optional_string(benefit.get("title"))
            or as_optional_string(benefit.get("comment"))
            or f"혜택 {index + 1}"
        )
        html = as_optional_string(benefit.get("info"))
        body = as_optional_string(benefit.get("comment"))
        if not html and not body:
            continue
        sections.append(
            {
                "id": f"benefit_{index + 1}",
                "title": title,
                "body": body,
                "html": html,
                "type": "benefit",
                "sortOrder": index + 10,
                "sourceCategory": sanitize_card_json_value(benefit.get("cate") or None),
            }
        )

    censorship_info = as_optional_string(source.get("censorship_info"))
    if censorship_info:
        sections.append(
            {
                "id": "censorship_info",
                "title": "유의사항",
                "type": "notice",
                "html": censorship_info,
                "sortOrder": 900,
            }
        )
    return sections


def card_deep_equal(left: Any, right: Any) -> bool:
    if left is MISSING or right is MISSING:
        return left is right
    if left == right and not isinstance(left, (list, dict)):
        return True
    if isinstance(left, list) or isinstance(right, list):
        if not isinstance(left, list) or not isinstance(right, list):
            return False
        if len(left) != len(right):
            return False
        return all(card_deep_equal(a, b) for a, b in zip(left, right))
    if is_plain_object(left) or is_plain_object(right):
        if not is_plain_object(left) or not is_plain_object(right):
            return False
        left_keys = set(left.keys())
        right_keys = set(right.keys())
        if left_keys != right_keys:
            return False
        return all(card_deep_equal(left[key], right[key]) for key in left_keys)
    return left == right


def diff_card_values(before: Any, after: Any, prefix: str = "") -> list[dict[str, Any]]:
    if card_deep_equal(before, after):
        return []

    if is_plain_object(before) and is_plain_object(after):
        changes: list[dict[str, Any]] = []
        for key in set(before.keys()) | set(after.keys()):
            path = f"{prefix}.{key}" if prefix else str(key)
            changes.extend(
                diff_card_values(
                    before.get(key, MISSING),
                    after.get(key, MISSING),
                    path,
                )
            )
        return changes

    return [
        {
            "path": prefix,
            "oldValue": None if before is MISSING else before,
            "newValue": None if after is MISSING else after,
        }
    ]


def card_revision_snapshot(data: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in (data or {}).items() if value is not MISSING}


def fetch_json(url: str) -> tuple[int, Any | None]:
    response = requests.get(url, timeout=REQUEST_TIMEOUT_SECONDS)
    if response.status_code == 404:
        return response.status_code, None
    if not response.ok:
        return response.status_code, None
    return response.status_code, response.json()


def sync_card_gorilla_issuers(
    db: firestore.Client,
    dry_run: bool,
) -> dict[str, str]:
    try:
        status, payload = fetch_json(f"{CARD_GORILLA_API_BASE}/card_corps")
    except requests.RequestException as error:
        print(f"[WARN] issuer sync failed: {error}")
        return {}

    if status < 200 or status >= 300:
        print(f"[WARN] issuer sync failed: status={status}")
        return {}

    issuers = payload if isinstance(payload, list) else (payload or {}).get("data") or []
    issuer_name_by_idx: dict[str, str] = {}
    batch = db.batch()
    write_count = 0

    for item in issuers:
        normalized = normalize_card_gorilla_issuer(item)
        if not normalized:
            continue
        issuer_id, data = normalized
        idx = data["sourceRefs"]["cardGorilla"]["idx"]
        issuer_name_by_idx[idx] = data["nameKo"]
        if dry_run:
            continue
        batch.set(
            card_catalog_ref(db).collection("cardIssuers").document(issuer_id),
            data,
            merge=True,
        )
        write_count += 1
        if write_count % 450 == 0:
            batch.commit()
            batch = db.batch()

    if not dry_run and write_count % 450:
        batch.commit()
    print(f"[OK] synced issuers: {len(issuer_name_by_idx)}")
    return issuer_name_by_idx


def upsert_card_gorilla_product(
    db: firestore.Client,
    actor_uid: str,
    run_id: str,
    source: dict[str, Any],
    issuer_name_by_idx: dict[str, str],
    skip_images: bool,
    dry_run: bool,
) -> str:
    idx = as_id_string(source.get("idx"))
    card_id = f"cg_{idx}"
    copied_image = (
        None
        if skip_images or dry_run
        else copy_card_image_to_storage(card_id, source.get("card_img"))
    )
    normalized = normalize_card_gorilla_product(source, issuer_name_by_idx, copied_image)
    detail_sections = normalize_card_gorilla_detail_sections(source)

    if dry_run:
        print(f"[DRY] {card_id} {normalized['name']} ({len(detail_sections)} sections)")
        return card_id

    product_ref = card_catalog_ref(db).collection("cardProducts").document(card_id)
    snapshot_ref = product_ref.collection("sourceSnapshots").document(run_id)

    @transactional
    def run_transaction(transaction):
        current_doc = product_ref.get(transaction=transaction)
        current = current_doc.to_dict() or {}
        current_version = int(current.get("version") or 0)
        action = "importUpdate" if current_doc.exists else "importCreate"
        change_set: list[dict[str, Any]] = []

        if current_doc.exists:
            for field, value in normalized.items():
                change_set.extend(
                    diff_card_values(current.get(field, MISSING), value, field)
                )
        else:
            for path, new_value in normalized.items():
                change_set.append(
                    {
                        "path": path,
                        "oldValue": None,
                        "newValue": new_value,
                    }
                )

        effective_change_set = [change for change in change_set if change.get("path")]
        next_version = (
            current_version + 1
            if effective_change_set
            else current_version or 1
        )
        product_payload = {
            **normalized,
            "version": next_version,
            "updatedAt": server_timestamp(),
            "updatedByUid": actor_uid,
        }
        if not current_doc.exists:
            product_payload["createdAt"] = server_timestamp()
            product_payload["createdByUid"] = actor_uid

        if current_doc.exists:
            if effective_change_set:
                transaction.update(product_ref, product_payload)
        else:
            transaction.set(product_ref, product_payload)

        if effective_change_set or not current_doc.exists:
            revision_ref = product_ref.collection("revisions").document()
            snapshot_after = card_revision_snapshot(
                {
                    **current,
                    **normalized,
                    "version": next_version,
                    "updatedByUid": actor_uid,
                }
            )
            transaction.set(
                revision_ref,
                {
                    "cardId": card_id,
                    "action": action,
                    "status": "applied",
                    "sourceType": "cardGorilla",
                    "actorUid": actor_uid,
                    "importRunId": run_id,
                    "versionFrom": current_version,
                    "versionTo": next_version,
                    "changedFields": [
                        change["path"] for change in effective_change_set
                    ],
                    "changeSet": effective_change_set,
                    "snapshotBefore": (
                        card_revision_snapshot(current) if current_doc.exists else None
                    ),
                    "snapshotAfter": snapshot_after,
                    "createdAt": server_timestamp(),
                },
            )

        transaction.set(
            snapshot_ref,
            {
                "cardId": card_id,
                "sourceType": "cardGorilla",
                "sourceUrl": f"{CARD_GORILLA_API_BASE}/cards/{idx}",
                "rawHash": card_hash(source),
                "raw": sanitize_card_json_value(source),
                "fetchedAt": server_timestamp(),
                "importRunId": run_id,
            },
        )

        for section in detail_sections:
            section_id = section["id"]
            transaction.set(
                product_ref.collection("detailSections").document(section_id),
                {
                    **section,
                    "updatedAt": server_timestamp(),
                    "sourceType": "cardGorilla",
                },
                merge=True,
            )

    run_transaction(db.transaction())
    return card_id


def create_run_doc(
    db: firestore.Client,
    start_id: int,
    end_id: int,
    actor_uid: str,
    dry_run: bool,
) -> tuple[str, Any | None]:
    if dry_run:
        return f"dry_{start_id}_{end_id}_{uuid.uuid4().hex[:8]}", None

    run_ref = card_catalog_ref(db).collection("cardImportRuns").document()
    run_id = run_ref.id
    counts = {
        "requested": end_id - start_id + 1,
        "success": 0,
        "notFound": 0,
        "failed": 0,
    }
    run_ref.set(
        {
            "sourceType": "cardGorilla",
            "status": "running",
            "startId": start_id,
            "endId": end_id,
            "actorUid": actor_uid,
            "counts": counts,
            "startedAt": server_timestamp(),
        }
    )
    return run_id, run_ref


def collect_chunk(
    db: firestore.Client,
    start_id: int,
    end_id: int,
    actor_uid: str,
    issuer_name_by_idx: dict[str, str],
    skip_images: bool,
    dry_run: bool,
) -> dict[str, Any]:
    run_id, run_ref = create_run_doc(db, start_id, end_id, actor_uid, dry_run)
    counts = {
        "requested": end_id - start_id + 1,
        "success": 0,
        "notFound": 0,
        "failed": 0,
    }
    imported_card_ids: list[str] = []
    errors: list[dict[str, Any]] = []

    print(f"\n[RUN] {start_id}-{end_id} ({counts['requested']} cards) runId={run_id}")
    try:
        for card_id_num in range(start_id, end_id + 1):
            api_url = f"{CARD_GORILLA_API_BASE}/cards/{card_id_num}"
            try:
                status, source = fetch_json(api_url)
                if status == 404:
                    counts["notFound"] += 1
                    print(f"[MISS] {card_id_num}")
                    continue
                if status < 200 or status >= 300:
                    counts["failed"] += 1
                    errors.append({"id": card_id_num, "status": status})
                    print(f"[FAIL] {card_id_num} status={status}")
                    continue
                if not isinstance(source, dict) or not source.get("idx"):
                    counts["notFound"] += 1
                    print(f"[MISS] {card_id_num} empty source")
                    continue

                imported_id = upsert_card_gorilla_product(
                    db=db,
                    actor_uid=actor_uid,
                    run_id=run_id,
                    source=source,
                    issuer_name_by_idx=issuer_name_by_idx,
                    skip_images=skip_images,
                    dry_run=dry_run,
                )
                imported_card_ids.append(imported_id)
                counts["success"] += 1
                print(f"[OK] {card_id_num} -> {imported_id}")
            except Exception as error:  # Keep long batch runs moving.
                counts["failed"] += 1
                errors.append({"id": card_id_num, "message": str(error)})
                print(f"[FAIL] {card_id_num} {error}")

        if run_ref is not None:
            run_ref.update(
                {
                    "status": "completed",
                    "counts": counts,
                    "importedCardIds": imported_card_ids,
                    "errors": errors[:50],
                    "finishedAt": server_timestamp(),
                }
            )
        return {
            "runId": run_id,
            "startId": start_id,
            "endId": end_id,
            "counts": counts,
            "importedCardIds": imported_card_ids,
            "errors": errors[:10],
        }
    except Exception as error:
        if run_ref is not None:
            run_ref.update(
                {
                    "status": "failed",
                    "counts": counts,
                    "error": str(error),
                    "finishedAt": server_timestamp(),
                }
            )
        raise


def iter_chunks(start_id: int, end_id: int, chunk_size: int):
    current = start_id
    while current <= end_id:
        chunk_end = min(end_id, current + chunk_size - 1)
        yield current, chunk_end
        current = chunk_end + 1


def validate_args(args: argparse.Namespace) -> int:
    start_id = max(1, args.start_id)
    end_id = max(1, args.end_id)
    if end_id < start_id:
        raise ValueError("end_id는 start_id보다 크거나 같아야 합니다.")
    if end_id > CARD_GORILLA_MAX_IMPORT_ID:
        raise ValueError(f"end_id는 {CARD_GORILLA_MAX_IMPORT_ID} 이하로 입력해주세요.")
    return max(1, min(args.chunk_size, MAX_CHUNK_SIZE))


def main() -> None:
    args = parse_args()
    chunk_size = validate_args(args)
    db = initialize_firebase(args.service_account)
    issuer_name_by_idx = sync_card_gorilla_issuers(db, args.dry_run)

    totals = {
        "requested": 0,
        "success": 0,
        "notFound": 0,
        "failed": 0,
    }
    runs: list[str] = []
    for start_id, end_id in iter_chunks(args.start_id, args.end_id, chunk_size):
        result = collect_chunk(
            db=db,
            start_id=start_id,
            end_id=end_id,
            actor_uid=args.actor_uid,
            issuer_name_by_idx=issuer_name_by_idx,
            skip_images=args.skip_images,
            dry_run=args.dry_run,
        )
        runs.append(result["runId"])
        for key in totals:
            totals[key] += result["counts"][key]

    print("\n=== Summary ===")
    print(f"mode: {'dry-run' if args.dry_run else 'write'}")
    print(f"range: {args.start_id}-{args.end_id}")
    print(f"chunk size: {chunk_size}")
    print(f"runs: {len(runs)}")
    print(f"requested: {totals['requested']}")
    print(f"success: {totals['success']}")
    print(f"notFound: {totals['notFound']}")
    print(f"failed: {totals['failed']}")
    if runs:
        print(f"runIds: {', '.join(runs)}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"[ERROR] {error}", file=sys.stderr)
        sys.exit(1)
