from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore


DEFAULT_SERVICE_ACCOUNT = Path(__file__).resolve().parents[1] / "env" / "mileagethief-firebase-adminsdk-8gdf2-1aed24e38a.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Backfill miles and mileRuleUsedPerMileKRW for lots missing those fields.",
    )
    parser.add_argument(
        "--service-account",
        default=str(DEFAULT_SERVICE_ACCOUNT),
        help="Path to Firebase service account json.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print target documents without writing updates.",
    )
    parser.add_argument(
        "--user-id",
        help="Only process one user uid.",
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


def normalize_pay_type(pay_type: Any) -> str:
    value = str(pay_type or "").strip().lower()
    if value in {"check", "체크"}:
        return "check"
    return "credit"


def get_mile_rule(card_data: dict[str, Any], pay_type: Any) -> int:
    normalized = normalize_pay_type(pay_type)
    key = "checkPerMileKRW" if normalized == "check" else "creditPerMileKRW"
    raw = card_data.get(key)
    if isinstance(raw, bool):
        return 0
    if isinstance(raw, int):
        return raw
    if isinstance(raw, float):
        return int(raw)
    if raw is None:
        return 0
    try:
        return int(str(raw))
    except ValueError:
        return 0


def has_missing_mile_fields(lot_data: dict[str, Any]) -> bool:
    return "mileRuleUsedPerMileKRW" not in lot_data or "miles" not in lot_data


def to_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if value is None:
        return 0
    try:
        return int(str(value))
    except ValueError:
        return 0


def fetch_card_map(user_ref: firestore.DocumentReference) -> dict[str, dict[str, Any]]:
    cards: dict[str, dict[str, Any]] = {}
    for card_doc in user_ref.collection("cards").stream():
        cards[card_doc.id] = card_doc.to_dict() or {}
    return cards


def backfill_user_lots(
    user_doc: firestore.DocumentSnapshot,
    db: firestore.Client,
    dry_run: bool,
) -> dict[str, int]:
    user_ref = db.collection("users").document(user_doc.id)
    card_map = fetch_card_map(user_ref)
    stats = {
        "users": 1,
        "checked_lots": 0,
        "updated_lots": 0,
        "skipped_no_card": 0,
        "skipped_no_rule": 0,
    }

    batch = db.batch()
    batch_count = 0

    for lot_doc in user_ref.collection("lots").stream():
        lot_data = lot_doc.to_dict() or {}
        stats["checked_lots"] += 1

        if not has_missing_mile_fields(lot_data):
            continue

        card_id = str(lot_data.get("cardId") or "").strip()
        if not card_id:
            print(f"[SKIP][{user_doc.id}/{lot_doc.id}] missing cardId")
            stats["skipped_no_card"] += 1
            continue

        card_data = card_map.get(card_id)
        if card_data is None:
            print(f"[SKIP][{user_doc.id}/{lot_doc.id}] card not found: {card_id}")
            stats["skipped_no_card"] += 1
            continue

        mile_rule = get_mile_rule(card_data, lot_data.get("payType"))
        if mile_rule <= 0:
            print(
                f"[SKIP][{user_doc.id}/{lot_doc.id}] invalid mile rule for cardId={card_id}, payType={lot_data.get('payType')}"
            )
            stats["skipped_no_rule"] += 1
            continue

        buy_unit = to_int(lot_data.get("buyUnit"))
        qty = to_int(lot_data.get("qty"))
        buy_total = buy_unit * qty
        miles = round(buy_total / mile_rule) if buy_total > 0 else 0

        payload = {
            "mileRuleUsedPerMileKRW": mile_rule,
            "miles": miles,
        }

        print(
            f"[TARGET][{user_doc.id}/{lot_doc.id}] cardId={card_id} payType={lot_data.get('payType')} "
            f"buyUnit={buy_unit} qty={qty} rule={mile_rule} miles={miles}"
        )

        if dry_run:
            stats["updated_lots"] += 1
            continue

        batch.update(lot_doc.reference, payload)
        batch_count += 1
        stats["updated_lots"] += 1

        if batch_count == 400:
            batch.commit()
            batch = db.batch()
            batch_count = 0

    if not dry_run and batch_count > 0:
        batch.commit()

    return stats


def iter_users(db: firestore.Client, user_id: str | None):
    users_ref = db.collection("users")
    if user_id:
        snapshot = users_ref.document(user_id).get()
        if not snapshot.exists:
            raise ValueError(f"User not found: {user_id}")
        return [snapshot]
    return list(users_ref.stream())


def main() -> None:
    args = parse_args()
    db = initialize_firebase(args.service_account)

    totals = {
        "users": 0,
        "checked_lots": 0,
        "updated_lots": 0,
        "skipped_no_card": 0,
        "skipped_no_rule": 0,
    }

    for user_doc in iter_users(db, args.user_id):
        result = backfill_user_lots(user_doc, db, args.dry_run)
        for key, value in result.items():
            totals[key] += value

    print("\n=== Summary ===")
    print(f"users: {totals['users']}")
    print(f"checked lots: {totals['checked_lots']}")
    print(f"updated lots: {totals['updated_lots']}")
    print(f"skipped(no card): {totals['skipped_no_card']}")
    print(f"skipped(no rule): {totals['skipped_no_rule']}")
    print(f"mode: {'dry-run' if args.dry_run else 'write'}")


if __name__ == "__main__":
    main()
