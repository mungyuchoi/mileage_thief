from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse
from zoneinfo import ZoneInfo

import firebase_admin
import requests
from firebase_admin import credentials, firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter


ROOT_DIR = Path(__file__).resolve().parents[2]
ENV_DIR = ROOT_DIR / "env"
DEFAULT_ACTOR_UID = "task_collect_gift_price"
REQUEST_TIMEOUT_SECONDS = 30
SEOUL = ZoneInfo("Asia/Seoul")


TRACKING_QUERY_KEYS = {
    "fbclid",
    "gclid",
    "igshid",
    "NaPm",
    "n_media",
    "n_query",
    "n_rank",
    "n_ad_group",
    "n_ad",
}

DEFAULT_DDART_HTML = ROOT_DIR / "task" / "gift" / "ddart.html"

REPORTED_SOURCE_URLS = [
    {
        "url": "https://locashop.lottecard.co.kr/goods/detail?goodsNo=G011073220",
        "merchantName": "띵샵",
        "memo": "공지 예시 링크",
    },
    {
        "url": "https://link.gmarket.co.kr/vtXftGfn0",
        "merchantName": "G마켓",
        "memo": "공지 댓글 제보: 하잉이",
    },
    {
        "url": "https://link.gmarket.co.kr/HiXftGfn0",
        "merchantName": "G마켓",
        "memo": "공지 댓글 제보: 하잉이",
    },
    {
        "url": "https://m.smartstore.naver.com/coop_egift/products/13303424126?NaPm=ct%3Dmosheowl%7Cci%3Dcheckout%7Ctr%3Dppc%7Ctrx%3Dnull%7Chk%3D2fe3d295adc9733fdd3676b96029b9af61ab0fda",
        "merchantName": "네이버스토어",
        "memo": "공지 댓글 제보: 하잉이",
    },
    {
        "url": "https://ltcard.kr/1tWirZe",
        "merchantName": "띵샵",
        "memo": "공지 댓글 제보",
    },
    {
        "url": "https://naver.me/xG0iZveN",
        "merchantName": "네이버스토어",
        "memo": "공지 댓글 제보",
    },
    {
        "url": "https://link.gmarket.co.kr/mhQOdiQNv",
        "merchantName": "G마켓",
        "memo": "공지 댓글 제보",
    },
    {
        "url": "https://mobile.auction.co.kr/ego.aspx?t=vp&p=F381893090",
        "merchantName": "옥션",
        "memo": "공지 댓글 제보",
    },
]


@dataclass
class DealSnapshot:
    deal_id: str
    source: dict[str, Any]
    title: str
    price_krw: int
    discount_rate: float
    discount_amount_krw: int
    status: str
    buy_url: str
    raw_title: str


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
        description="Collect online giftcard deal prices into Firestore.",
    )
    parser.add_argument(
        "--service-account",
        default=str(find_default_service_account()),
        help="Path to Firebase service account JSON.",
    )
    parser.add_argument(
        "--actor-uid",
        default=DEFAULT_ACTOR_UID,
        help="Value saved to crawler metadata fields.",
    )
    parser.add_argument(
        "--date",
        default=datetime.now(SEOUL).strftime("%Y%m%d"),
        help="History document id in yyyyMMdd. Defaults to today in Korea.",
    )
    parser.add_argument(
        "--source-id",
        help="Collect one giftcardDealSources document id.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Maximum number of enabled sources to collect. 0 means no limit.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Fetch and parse prices without writing Firestore or sending FCM.",
    )
    parser.add_argument(
        "--no-notify",
        action="store_true",
        help="Do not send FCM notifications after saving prices.",
    )
    parser.add_argument(
        "--include-ddart",
        action="store_true",
        help="Also parse DDART market page for diagnostics. It is not written as managed sources.",
    )
    parser.add_argument(
        "--ddart-url",
        default="https://auto.ddart.net/market/",
        help="DDART market URL used when --include-ddart is set.",
    )
    parser.add_argument(
        "--seed-sources",
        action="store_true",
        help="Seed giftcardDealSources from task/gift/ddart.html and reported URLs.",
    )
    parser.add_argument(
        "--seed-html",
        default=str(DEFAULT_DDART_HTML),
        help="DDART HTML file used for source seeding.",
    )
    parser.add_argument(
        "--no-auto-seed",
        action="store_true",
        help="Do not seed sources automatically when giftcardDealSources is empty.",
    )
    parser.add_argument(
        "--collect-after-seed",
        action="store_true",
        help="After seeding an empty database, continue with live crawling.",
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


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def server_timestamp():
    return firestore.SERVER_TIMESTAMP


def as_string(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def as_int(value: Any) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value
    if isinstance(value, float) and math.isfinite(value):
        return int(round(value))
    if isinstance(value, str):
        return int(re.sub(r"[^0-9]", "", value) or 0)
    return 0


def as_float(value: Any) -> float:
    if isinstance(value, bool):
        return 0.0
    if isinstance(value, (int, float)) and math.isfinite(value):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.replace("%", "").replace(",", "").strip())
        except ValueError:
            return 0.0
    return 0.0


def slug(value: str) -> str:
    text = value.strip().lower()
    output: list[str] = []
    last_was_sep = False
    for char in text:
        if char.isascii() and char.isalnum():
            output.append(char)
            last_was_sep = False
        elif "가" <= char <= "힣":
            output.append(char)
            last_was_sep = False
        elif output and not last_was_sep:
            output.append("_")
            last_was_sep = True
    return "".join(output).strip("_")


def normalize_url(value: str) -> str:
    trimmed = value.strip()
    parsed = urlparse(trimmed)
    if not parsed.netloc:
        return trimmed
    query_items = [
        (key, val)
        for key, val in parse_qsl(parsed.query, keep_blank_values=True)
        if key not in TRACKING_QUERY_KEYS and not key.startswith("utm_")
    ]
    query_items.sort(key=lambda item: item[0])
    return urlunparse(
        (
            (parsed.scheme or "https").lower(),
            parsed.netloc.lower(),
            parsed.path,
            parsed.params,
            urlencode(query_items, doseq=True),
            "",
        )
    )


def build_deal_id(
    merchant_name: str,
    brand_name: str,
    denomination_krw: int,
    normalized_url: str,
) -> str:
    digest = hashlib.sha1(normalized_url.encode("utf-8")).hexdigest()[:10]
    return f"{slug(merchant_name)}_{slug(brand_name)}_{denomination_krw}_{digest}"


def request_html(url: str) -> str:
    response = requests.get(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0 Safari/537.36"
            ),
            "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
        },
        timeout=REQUEST_TIMEOUT_SECONDS,
    )
    response.raise_for_status()
    response.encoding = response.apparent_encoding or response.encoding
    return response.text


def strip_tags(value: str) -> str:
    without_script = re.sub(
        r"<(script|style)\b[^>]*>.*?</\1>",
        " ",
        value,
        flags=re.I | re.S,
    )
    text = re.sub(r"<[^>]+>", " ", without_script)
    return html.unescape(re.sub(r"\s+", " ", text)).strip()


def extract_title(raw_html: str) -> str:
    patterns = [
        r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\']([^"\']+)["\']',
        r'<meta[^>]+name=["\']title["\'][^>]+content=["\']([^"\']+)["\']',
        r"<title[^>]*>(.*?)</title>",
    ]
    for pattern in patterns:
        match = re.search(pattern, raw_html, flags=re.I | re.S)
        if match:
            return strip_tags(match.group(1))[:200]
    return ""


def extract_status(raw_html: str) -> str:
    text = strip_tags(raw_html)
    if re.search(r"품절|판매\s*종료|일시\s*품절|구매\s*불가", text):
        return "soldOut"
    return "active"


def extract_price(raw_html: str, face_value_krw: int) -> int:
    candidates: list[int] = []
    patterns = [
        r'"(?:salePrice|discountPrice|finalPrice|price|payPrice)"\s*:\s*"?([0-9][0-9,]{3,})',
        r"(?:판매가|할인가|즉시할인가|쿠폰적용가|상품금액)[^0-9]{0,20}([0-9][0-9,]{3,})\s*원",
        r"([0-9][0-9,]{3,})\s*원",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, raw_html, flags=re.I):
            price = as_int(match.group(1))
            if price > 0:
                candidates.append(price)

    if not candidates:
        return 0

    unique = sorted(set(candidates))
    if face_value_krw > 0:
        lower = int(face_value_krw * 0.55)
        upper = int(face_value_krw * 1.10)
        plausible = [price for price in unique if lower <= price <= upper]
        if plausible:
            return min(plausible)
    return min(unique)


def infer_merchant_name(url: str, fallback: str = "") -> str:
    fallback = fallback.strip()
    host = urlparse(url).netloc.lower()
    if "gmarket" in host:
        return "G마켓"
    if "auction" in host:
        return "옥션"
    if "11st" in host:
        return "11번가"
    if "ssg.com" in host:
        return "SSG"
    if "locashop" in host or "ltcard.kr" in host:
        return "띵샵"
    if "samsungcard" in host:
        return "삼카몰"
    if "lotteon" in host:
        return "롯데ON"
    if "smartstore.naver" in host or host == "naver.me":
        return "네이버스토어"
    return fallback or host or "기타"


def infer_brand_name(row_type: str, title: str) -> str:
    combined = f"{row_type} {title}"
    brand_patterns = [
        ("신세계", r"신세계|이마트|SSG상품권"),
        ("롯데", r"롯데"),
        ("현대", r"현대"),
        ("SSG", r"\bSSG\b|쓱"),
        ("갤러리아", r"갤러리아"),
        ("AK", r"\bAK\b|애경"),
        ("북앤라이프", r"북앤라이프|도서문화"),
        ("컬쳐랜드", r"컬쳐랜드|문화상품권"),
        ("해피머니", r"해피머니"),
        ("온라인문화", r"온라인문화"),
        ("스마일머니", r"스마일머니"),
        ("엘포인트", r"엘포인트|L\.?POINT|L포인트"),
    ]
    for brand, pattern in brand_patterns:
        if re.search(pattern, combined, flags=re.I):
            return brand
    return row_type.strip() or "미분류"


def round_nice_amount(value: float) -> int:
    if value <= 0 or not math.isfinite(value):
        return 0
    step = 10000 if value >= 100000 else 1000
    return int(round(value / step) * step)


def infer_face_value(title: str, price_krw: int, discount_rate: float) -> int:
    title = title or ""
    candidates: list[int] = []
    for match in re.finditer(r"(\d+(?:\.\d+)?)\s*만원", title):
        candidates.append(int(float(match.group(1)) * 10000))
    for match in re.finditer(r"([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{5,7})\s*원", title):
        candidates.append(as_int(match.group(1)))
    plausible = [
        value
        for value in candidates
        if value > 0 and (price_krw <= 0 or value >= int(price_krw * 0.85))
    ]
    if plausible:
        return min(plausible, key=lambda value: abs(value - price_krw))
    if price_krw > 0 and 0 < discount_rate < 80:
        return round_nice_amount(price_krw / (1 - discount_rate / 100))
    return price_krw


def normalize_source(doc_id: str, data: dict[str, Any]) -> dict[str, Any]:
    url = as_string(data.get("url"))
    normalized_url = as_string(data.get("normalizedUrl")) or normalize_url(url)
    merchant_name = as_string(data.get("merchantName"))
    brand_name = as_string(data.get("brandName"))
    face_value = as_int(data.get("faceValueKRW")) or as_int(data.get("denominationKRW"))
    deal_id = doc_id or build_deal_id(
        merchant_name=merchant_name,
        brand_name=brand_name,
        denomination_krw=face_value,
        normalized_url=normalized_url,
    )
    return {
        **data,
        "id": deal_id,
        "url": url,
        "normalizedUrl": normalized_url,
        "merchantId": as_string(data.get("merchantId")) or slug(merchant_name),
        "merchantName": merchant_name,
        "brandId": as_string(data.get("brandId")) or slug(brand_name),
        "brandName": brand_name,
        "faceValueKRW": face_value,
        "denominationKRW": face_value,
        "displayName": as_string(data.get("displayName")),
    }


def load_sources(
    db: firestore.Client,
    source_id: str | None,
    limit: int,
) -> list[dict[str, Any]]:
    collection = db.collection("giftcardDealSources")
    if source_id:
        snap = collection.document(source_id).get()
        if not snap.exists:
            raise ValueError(f"giftcardDealSources/{source_id} does not exist")
        return [normalize_source(snap.id, snap.to_dict() or {})]

    query = collection.where(filter=FieldFilter("enabled", "==", True))
    if limit > 0:
        query = query.limit(limit)
    sources = [
        normalize_source(doc.id, doc.to_dict() or {})
        for doc in query.stream()
    ]
    return sources


def collect_one_source(source: dict[str, Any]) -> DealSnapshot:
    url = as_string(source.get("url"))
    if not url:
        raise ValueError("source url is empty")
    raw_html = request_html(url)
    face_value = as_int(source.get("faceValueKRW"))
    price = extract_price(raw_html, face_value)
    if price <= 0:
        raise ValueError("price not found")

    status = extract_status(raw_html)
    discount_amount = max(face_value - price, 0) if face_value > 0 else 0
    discount_rate = (
        round((discount_amount / face_value) * 100, 4)
        if face_value > 0
        else 0.0
    )
    raw_title = extract_title(raw_html)
    title = as_string(source.get("displayName")) or raw_title

    return DealSnapshot(
        deal_id=as_string(source.get("id")),
        source=source,
        title=title,
        price_krw=price,
        discount_rate=discount_rate,
        discount_amount_krw=discount_amount,
        status=status,
        buy_url=url,
        raw_title=raw_title,
    )


def save_snapshot(
    db: firestore.Client,
    snapshot: DealSnapshot,
    history_date: str,
    actor_uid: str,
    dry_run: bool,
) -> bool:
    source = snapshot.source
    if dry_run:
        print(
            "[DRY] "
            f"{snapshot.deal_id} {snapshot.title} "
            f"{snapshot.price_krw:,}원 {snapshot.discount_rate:.2f}%"
        )
        return True

    source_ref = db.collection("giftcardDealSources").document(snapshot.deal_id)
    deal_ref = db.collection("giftcardDeals").document(snapshot.deal_id)
    history_ref = deal_ref.collection("priceHistory").document(history_date)

    previous = deal_ref.get()
    previous_data = previous.to_dict() if previous.exists else {}
    changed = (
        as_int(previous_data.get("priceKRW")) != snapshot.price_krw
        or round(as_float(previous_data.get("discountRate")), 4)
        != round(snapshot.discount_rate, 4)
    )

    deal_payload = {
        "sourceId": snapshot.deal_id,
        "title": snapshot.title,
        "brandId": source.get("brandId", ""),
        "brandName": source.get("brandName", ""),
        "merchantId": source.get("merchantId", ""),
        "merchantName": source.get("merchantName", ""),
        "denominationKRW": as_int(source.get("denominationKRW")),
        "faceValueKRW": as_int(source.get("faceValueKRW")),
        "priceKRW": snapshot.price_krw,
        "discountRate": snapshot.discount_rate,
        "discountAmountKRW": snapshot.discount_amount_krw,
        "buyUrl": snapshot.buy_url,
        "status": snapshot.status,
        "lastSeenAt": server_timestamp(),
        "updatedAt": server_timestamp(),
        "updatedByUid": actor_uid,
    }
    if changed:
        deal_payload["lastChangedAt"] = server_timestamp()

    deal_ref.set(deal_payload, merge=True)
    history_ref.set(
        {
            "priceKRW": snapshot.price_krw,
            "discountRate": snapshot.discount_rate,
            "discountAmountKRW": snapshot.discount_amount_krw,
            "crawledAt": server_timestamp(),
            "rawTitle": snapshot.raw_title,
            "sourceUrl": snapshot.buy_url,
            "status": snapshot.status,
            "updatedByUid": actor_uid,
        },
        merge=True,
    )
    source_ref.set(
        {
            "lastCrawlStatus": "success",
            "lastCrawlError": "",
            "lastPriceKRW": snapshot.price_krw,
            "lastDiscountRate": snapshot.discount_rate,
            "lastCrawledAt": server_timestamp(),
            "updatedAt": server_timestamp(),
            "updatedByUid": actor_uid,
        },
        merge=True,
    )
    return changed


def save_source_error(
    db: firestore.Client,
    source: dict[str, Any],
    error: Exception,
    actor_uid: str,
    dry_run: bool,
) -> None:
    message = str(error)[:500]
    print(f"[ERROR] {source.get('id')}: {message}", file=sys.stderr)
    if dry_run:
        return
    db.collection("giftcardDealSources").document(as_string(source.get("id"))).set(
        {
            "lastCrawlStatus": "error",
            "lastCrawlError": message,
            "lastCrawledAt": server_timestamp(),
            "updatedAt": server_timestamp(),
            "updatedByUid": actor_uid,
        },
        merge=True,
    )


def alert_matches(alert: dict[str, Any], snapshot: DealSnapshot) -> bool:
    source = snapshot.source
    deal_ids = [str(item) for item in alert.get("dealIds") or [] if str(item)]
    brand_ids = [str(item) for item in alert.get("brandIds") or [] if str(item)]
    merchant_ids = [str(item) for item in alert.get("merchantIds") or [] if str(item)]
    denominations = [
        as_int(item)
        for item in alert.get("denominationsKRW") or []
        if as_int(item) > 0
    ]
    if deal_ids and snapshot.deal_id not in deal_ids:
        return False
    if brand_ids and str(source.get("brandId")) not in brand_ids:
        return False
    if merchant_ids and str(source.get("merchantId")) not in merchant_ids:
        return False
    if denominations:
        source_amount = as_int(source.get("faceValueKRW")) or as_int(
            source.get("denominationKRW")
        )
        if source_amount not in denominations:
            return False

    min_discount = as_float(alert.get("minDiscountRate"))
    max_price = as_int(alert.get("maxPriceKRW"))
    if min_discount > 0 and snapshot.discount_rate < min_discount:
        return False
    if max_price > 0 and snapshot.price_krw > max_price:
        return False
    return True


def is_improved_for_alert(alert: dict[str, Any], snapshot: DealSnapshot) -> bool:
    notify_mode = as_string(alert.get("notifyMode")) or "improved_only"
    if notify_mode != "improved_only":
        return True

    last_price = as_int(alert.get("lastNotifiedPriceKRW"))
    last_discount = as_float(alert.get("lastNotifiedDiscountRate"))
    if last_price <= 0 and last_discount <= 0:
        return True
    if snapshot.price_krw > 0 and (
        last_price <= 0 or snapshot.price_krw < last_price
    ):
        return True
    return snapshot.discount_rate > last_discount


def notification_event_id(
    alert_path: str,
    snapshot: DealSnapshot,
    history_date: str,
) -> str:
    return hashlib.sha1(
        "|".join(
            [
                alert_path,
                snapshot.deal_id,
                history_date,
                str(snapshot.price_krw),
                f"{snapshot.discount_rate:.4f}",
            ]
        ).encode("utf-8")
    ).hexdigest()


def send_notifications(
    db: firestore.Client,
    snapshots: list[DealSnapshot],
    history_date: str,
    dry_run: bool,
) -> int:
    if not snapshots:
        return 0
    sent = 0
    alerts = db.collection_group("giftcardDealAlerts").where(
        filter=FieldFilter("enabled", "==", True),
    ).stream()
    event_collection = db.collection("giftcardDealNotificationEvents")
    user_cache: dict[str, dict[str, Any]] = {}

    for alert_doc in alerts:
        alert = alert_doc.to_dict() or {}
        user_ref = alert_doc.reference.parent.parent
        if user_ref is None:
            continue
        uid = user_ref.id
        if uid not in user_cache:
            user_snap = user_ref.get()
            user_cache[uid] = user_snap.to_dict() or {}
        token = as_string(user_cache[uid].get("fcmToken"))
        if not token:
            continue

        candidates = [
            snapshot
            for snapshot in snapshots
            if alert_matches(alert, snapshot)
            and is_improved_for_alert(alert, snapshot)
        ]
        candidates.sort(key=lambda item: (-item.discount_rate, item.price_krw))

        for snapshot in candidates:
            event_id = notification_event_id(
                alert_doc.reference.path,
                snapshot,
                history_date,
            )
            if event_collection.document(event_id).get().exists:
                continue

            title = "상품권 특가 알림"
            body = (
                f"{snapshot.title} {snapshot.discount_rate:.2f}% "
                f"({snapshot.price_krw:,}원)"
            )
            if dry_run:
                print(f"[DRY][FCM] {uid} {body}")
                sent += 1
                break

            message = messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data={
                    "channelId": "radar_notifications",
                    "notificationTitle": title,
                    "notificationBody": body,
                    "type": "giftcard_deal",
                    "dealId": snapshot.deal_id,
                    "giftcardDealId": snapshot.deal_id,
                    "linkValue": f"giftcard-deal:{snapshot.deal_id}",
                },
            )
            messaging.send(message)
            event_collection.document(event_id).set(
                {
                    "uid": uid,
                    "alertPath": alert_doc.reference.path,
                    "dealId": snapshot.deal_id,
                    "historyDate": history_date,
                    "priceKRW": snapshot.price_krw,
                    "discountRate": snapshot.discount_rate,
                    "sentAt": server_timestamp(),
                }
            )
            alert_doc.reference.set(
                {
                    "lastNotifiedAt": server_timestamp(),
                    "lastNotifiedDealId": snapshot.deal_id,
                    "lastNotifiedPriceKRW": snapshot.price_krw,
                    "lastNotifiedDiscountRate": snapshot.discount_rate,
                    "updatedAt": server_timestamp(),
                },
                merge=True,
            )
            sent += 1
            break
    return sent


def parse_ddart_rows(raw_html: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for tr in re.findall(r"<tr\b[^>]*>.*?</tr>", raw_html, flags=re.I | re.S):
        cells = re.findall(r"<td\b[^>]*>(.*?)</td>", tr, flags=re.I | re.S)
        if len(cells) < 5:
            continue
        link_match = re.search(
            r'<a\b[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',
            cells[4],
            flags=re.I | re.S,
        )
        price = as_int(strip_tags(cells[1]))
        discount = abs(as_float(strip_tags(cells[2])))
        if price <= 0:
            continue
        rows.append(
            {
                "type": strip_tags(cells[0]),
                "priceKRW": price,
                "discountRate": discount,
                "merchantName": strip_tags(cells[3]),
                "title": strip_tags(link_match.group(2) if link_match else cells[4]),
                "url": html.unescape(link_match.group(1)) if link_match else "",
            }
        )
    return rows


def source_from_seed_row(row: dict[str, Any]) -> dict[str, Any] | None:
    url = as_string(row.get("url"))
    if not url:
        return None
    normalized_url = normalize_url(url)
    title = as_string(row.get("title"))
    price_krw = as_int(row.get("priceKRW"))
    discount_rate = as_float(row.get("discountRate"))
    merchant_name = infer_merchant_name(url, as_string(row.get("merchantName")))
    brand_name = infer_brand_name(as_string(row.get("type")), title)
    face_value = infer_face_value(title, price_krw, discount_rate)
    deal_id = build_deal_id(
        merchant_name=merchant_name,
        brand_name=brand_name,
        denomination_krw=face_value,
        normalized_url=normalized_url,
    )
    return {
        "id": deal_id,
        "url": url,
        "normalizedUrl": normalized_url,
        "merchantId": slug(merchant_name),
        "merchantName": merchant_name,
        "brandId": slug(brand_name),
        "brandName": brand_name,
        "denominationKRW": face_value,
        "faceValueKRW": face_value,
        "displayName": title,
        "enabled": True,
        "memo": as_string(row.get("memo")),
        "seedSource": as_string(row.get("seedSource")) or "ddart_html",
        "seedPriceKRW": price_krw,
        "seedDiscountRate": discount_rate,
        "seedTitle": title,
    }


def build_seed_sources(seed_html_path: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    path = Path(seed_html_path)
    if path.exists():
        raw_html = path.read_text(encoding="utf-8")
        for row in parse_ddart_rows(raw_html):
            row["seedSource"] = "ddart_html"
            row["memo"] = "DDART HTML 초기 시드"
            rows.append(row)
    else:
        print(f"[SEED][WARN] DDART HTML not found: {path}", file=sys.stderr)

    for item in REPORTED_SOURCE_URLS:
        rows.append(
            {
                "url": item["url"],
                "merchantName": item.get("merchantName", ""),
                "title": "",
                "type": "미분류",
                "priceKRW": 0,
                "discountRate": 0,
                "seedSource": "reported_comment",
                "memo": item.get("memo", "공지 댓글 제보"),
            }
        )

    sources_by_url: dict[str, dict[str, Any]] = {}
    for row in rows:
        source = source_from_seed_row(row)
        if source is None:
            continue
        normalized_url = source["normalizedUrl"]
        existing = sources_by_url.get(normalized_url)
        if existing is None:
            sources_by_url[normalized_url] = source
            continue
        if as_int(source.get("seedPriceKRW")) > 0 and as_int(existing.get("seedPriceKRW")) <= 0:
            sources_by_url[normalized_url] = source
    return list(sources_by_url.values())


def seed_sources(
    db: firestore.Client,
    seed_html_path: str,
    history_date: str,
    actor_uid: str,
    dry_run: bool,
) -> dict[str, int]:
    sources = build_seed_sources(seed_html_path)
    source_count = 0
    deal_count = 0
    history_count = 0
    for source in sources:
        source_count += 1
        price_krw = as_int(source.get("seedPriceKRW"))
        discount_rate = as_float(source.get("seedDiscountRate"))
        face_value = as_int(source.get("faceValueKRW"))
        discount_amount = max(face_value - price_krw, 0) if price_krw > 0 else 0
        source_payload = {
            "url": source["url"],
            "normalizedUrl": source["normalizedUrl"],
            "merchantId": source["merchantId"],
            "merchantName": source["merchantName"],
            "brandId": source["brandId"],
            "brandName": source["brandName"],
            "denominationKRW": face_value,
            "faceValueKRW": face_value,
            "displayName": source["displayName"],
            "enabled": True,
            "memo": source["memo"],
            "seedSource": source["seedSource"],
            "updatedAt": server_timestamp(),
            "updatedByUid": actor_uid,
            "createdAt": server_timestamp(),
            "createdByUid": actor_uid,
        }
        if price_krw > 0:
            source_payload.update(
                {
                    "lastCrawlStatus": "seeded",
                    "lastCrawlError": "",
                    "lastPriceKRW": price_krw,
                    "lastDiscountRate": discount_rate,
                    "lastCrawledAt": server_timestamp(),
                }
            )

        if dry_run:
            print(
                "[DRY][SEED] "
                f"{source['id']} {source['merchantName']} "
                f"{source['brandName']} {face_value:,} {source['url']}"
            )
        else:
            db.collection("giftcardDealSources").document(source["id"]).set(
                source_payload,
                merge=True,
            )

        if price_krw <= 0:
            continue

        deal_count += 1
        if dry_run:
            continue
        deal_ref = db.collection("giftcardDeals").document(source["id"])
        deal_ref.set(
            {
                "sourceId": source["id"],
                "title": source["displayName"],
                "brandId": source["brandId"],
                "brandName": source["brandName"],
                "merchantId": source["merchantId"],
                "merchantName": source["merchantName"],
                "denominationKRW": face_value,
                "faceValueKRW": face_value,
                "priceKRW": price_krw,
                "discountRate": discount_rate,
                "discountAmountKRW": discount_amount,
                "buyUrl": source["url"],
                "status": "active",
                "lastSeenAt": server_timestamp(),
                "lastChangedAt": server_timestamp(),
                "updatedAt": server_timestamp(),
                "updatedByUid": actor_uid,
                "seedSource": source["seedSource"],
            },
            merge=True,
        )
        deal_ref.collection("priceHistory").document(history_date).set(
            {
                "priceKRW": price_krw,
                "discountRate": discount_rate,
                "discountAmountKRW": discount_amount,
                "crawledAt": server_timestamp(),
                "rawTitle": source["displayName"],
                "sourceUrl": source["url"],
                "status": "active",
                "updatedByUid": actor_uid,
                "seedSource": source["seedSource"],
            },
            merge=True,
        )
        history_count += 1

    return {
        "sourceCount": source_count,
        "dealCount": deal_count,
        "historyCount": history_count,
    }


def run(args: argparse.Namespace) -> int:
    db = initialize_firebase(args.service_account)
    run_ref = None
    if not args.dry_run:
        run_ref = db.collection("giftcardDealRuns").document()
        run_ref.set(
            {
                "startedAt": server_timestamp(),
                "historyDate": args.date,
                "actorUid": args.actor_uid,
                "dryRun": False,
            }
        )

    sources = load_sources(db, args.source_id, args.limit)
    should_seed = args.seed_sources or (
        not args.no_auto_seed and not args.source_id and not sources
    )
    if should_seed:
        seed_result = seed_sources(
            db=db,
            seed_html_path=args.seed_html,
            history_date=args.date,
            actor_uid=args.actor_uid,
            dry_run=args.dry_run,
        )
        print(
            json.dumps(
                {
                    "seededSources": seed_result["sourceCount"],
                    "seededDeals": seed_result["dealCount"],
                    "seededHistory": seed_result["historyCount"],
                    "dryRun": args.dry_run,
                },
                ensure_ascii=False,
            )
        )
        if args.seed_sources or not args.collect_after_seed:
            if run_ref is not None:
                run_ref.set(
                    {
                        "finishedAt": server_timestamp(),
                        "sourceCount": seed_result["sourceCount"],
                        "parsedCount": seed_result["dealCount"],
                        "changedCount": seed_result["dealCount"],
                        "errorCount": 0,
                        "notifiedCount": 0,
                        "seeded": True,
                    },
                    merge=True,
                )
            return 0
        sources = load_sources(db, args.source_id, args.limit)

    if args.include_ddart:
        try:
            ddart_rows = parse_ddart_rows(request_html(args.ddart_url))
            print(f"[DDART] parsed {len(ddart_rows)} rows")
            for row in ddart_rows[:10]:
                print(
                    "[DDART] "
                    f"{row['type']} {row['merchantName']} "
                    f"{row['priceKRW']:,}원 {row['discountRate']:.2f}% "
                    f"{row['title']}"
                )
        except Exception as error:
            print(f"[DDART][ERROR] {error}", file=sys.stderr)

    print(f"Loaded {len(sources)} enabled giftcard deal sources.")

    snapshots: list[DealSnapshot] = []
    parsed_count = 0
    changed_count = 0
    error_count = 0
    for source in sources:
        try:
            snapshot = collect_one_source(source)
            changed = save_snapshot(
                db=db,
                snapshot=snapshot,
                history_date=args.date,
                actor_uid=args.actor_uid,
                dry_run=args.dry_run,
            )
            snapshots.append(snapshot)
            parsed_count += 1
            changed_count += int(changed)
        except Exception as error:
            error_count += 1
            save_source_error(db, source, error, args.actor_uid, args.dry_run)

    notified_count = 0
    if not args.no_notify:
        notified_count = send_notifications(db, snapshots, args.date, args.dry_run)

    print(
        json.dumps(
            {
                "historyDate": args.date,
                "sourceCount": len(sources),
                "parsedCount": parsed_count,
                "changedCount": changed_count,
                "errorCount": error_count,
                "notifiedCount": notified_count,
                "dryRun": args.dry_run,
            },
            ensure_ascii=False,
        )
    )

    if run_ref is not None:
        run_ref.set(
            {
                "finishedAt": server_timestamp(),
                "sourceCount": len(sources),
                "parsedCount": parsed_count,
                "changedCount": changed_count,
                "errorCount": error_count,
                "notifiedCount": notified_count,
            },
            merge=True,
        )
    return 0 if error_count == 0 else 1


if __name__ == "__main__":
    raise SystemExit(run(parse_args()))
