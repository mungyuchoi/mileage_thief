# 특가 항공권 데이터베이스 및 크롤링 설계 (TRIP2)

본 문서는 Trip.com 특가 데이터를 기반으로 캐치프로그와 같은 사용자 경험을 제공하기 위한 Firestore 스키마 및 데이터 운영 전략을 정의합니다.

## 1. Firestore 데이터 구조 설계

### A. `deals` 컬렉션 (현재 유효한 특가)
이 컬렉션은 앱의 메인 화면에서 보여줄 "현재 가장 저렴한 특가" 정보를 관리합니다.

> 참고: Firestore에서 “지역/도착지별로 컬렉션을 쪼개는 것”은 콘솔에서 보기엔 편하지만,
> 앱 기능(정렬/필터/랭킹/시나리오) 관점에선 쿼리가 어려워질 수 있습니다.
> 그래서 본 문서는 **(1) Canonical(원천) 저장은 `deals`/`price_history`로 일관되게 유지**하고,
> **(2) 지역/도시 탐색 UX는 별도의 ‘지리(taxonomy) + feed(뷰)’ 컬렉션으로 해결**하는 하이브리드 구성을 권장합니다.

| 필드명 | 타입 | 설명 | 예시 |
| :--- | :--- | :--- | :--- |
| `deal_id` | String | 문서 고유 ID (조합형) | `ICN_OKA_20251228_OW_TW` |
| `origin` | Map | 출발지(도시/메타) | `{ "city": "서울", "code": "SEL", "airports": ["ICN","GMP"] }` |
| `destination` | Map | 목적지(도시/메타) | `{ "city": "오키나와", "code": "OKA", "airports": ["OKA"] }` |
| `trip_type` | String | 여정 타입 | `"OW"` (편도) / `"RT"` (왕복) |
| `departure_date` | Timestamp | 출발 날짜 | `2025-12-28 00:00:00` |
| `return_date` | Timestamp | 오는 날짜 (왕복 시) | `2026-01-02 00:00:00` (편도는 null) |
| `cabin_class` | String | 좌석 등급 | `"일반석"` |
| `fare_type` | String | 운임 타입/표시용 (있으면) | `"특가"` / `"프로모션"` / `null` |
| `price` | Number | 현재 최저가 | `163700` |
| `currency` | String | 통화 | `"KRW"` |
| `price_includes_taxes` | Boolean | 세금/수수료 포함 여부(파싱 가능 시) | `true` |
| `avg_price_60d` | Number | 최근 60일 평균가 (뚝 떨어진 기준) | `250000` |
| `discount_rate` | Number | 평균 대비 하락폭 (%) | `-34.5` |
| `booking_url` | String | 예약 페이지 링크 | `https://kr.trip.com/...` |
| `provider` | Map | 공급자/출처 메타 | `{ "name": "trip.com", "locale": "ko-KR" }` |
| `airlines` | Array<Map> | 여정 전체에 등장하는 항공사(마케팅/운항 포함) | `[{ "code":"TW","name":"티웨이항공" }]` |
| `outbound` | Map | 가는 편(구간 배열) | 아래 `segments[]` 참고 |
| `inbound` | Map \| null | 오는 편(왕복 시, 구간 배열) | 아래 `segments[]` 참고 |
| `baggage` | Map | 수하물 정보(표시/필터용) | 아래 `baggage` 참고 |
| `availability` | Map | 재고/배지(예: 9석 미만) | 아래 `availability` 참고 |
| `is_weekend` | Boolean | 주말 항공권 여부 (금/토/일 출발) | `true` |
| `last_updated` | Timestamp | 디비 업데이트 시간 | `2025-12-25 22:00:00` |

#### 지역/대륙 탭(아시아/유럽/미주 등)을 위한 권장 필드(추가)
UI에서 “아시아/유럽/미주”처럼 빠른 필터를 하려면, `destination`에 아래 메타를 **필드로 들고 있는 게 쿼리 비용이 가장 낮습니다.**

- `destination_geo` (Map)
  - `continent` (String): `"asia" | "europe" | "north_america" | "oceania" | ...`
  - `country_code` (String): `"JP"`, `"US"` 등
  - `country_name` (String): `"일본"`, `"미국"`
  - `city_id` (String): `"jp_oka"` 같이 내부 표준 ID
  - `city_name_ko` (String): `"오키나와"`
  - `region_tags` (Array<String>): `["japan","okinawa"]` (탐색/검색 보조)

> 핵심: “컬렉션을 쪼개서 찾기 쉽게”보다, **필드를 표준화해서 where 쿼리를 쉽게** 만드는 게 Firestore에선 더 강합니다.

### (선택) C. 지리(taxonomy) 컬렉션 (탐색 UX/관리용)
콘솔/운영에서 “미국 > LA” 같은 구조로 쉽게 보고 싶다면, **원천 데이터를 분산 저장하기보다** 아래처럼 “정의/메타”만 별도로 둡니다.

- `geo_continents/{continentId}` 예: `geo_continents/north_america`
  - `name_ko`: `"북미"`
- `geo_countries/{countryCode}` 예: `geo_countries/US`
  - `continentId`: `"north_america"`
  - `name_ko`: `"미국"`
- `geo_cities/{cityId}` 예: `geo_cities/us_lax`
  - `countryCode`: `"US"`
  - `name_ko`: `"로스앤젤레스"`
  - `iata_airports`: `["LAX"]`

이 컬렉션은 주로:
- 앱에서 “지역 선택 모달” 구성
- `destination_geo`를 채우는 표준 테이블(lookup)
- 운영자가 콘솔에서 구조적으로 탐색
에 사용합니다.

### (선택) D. feed(뷰) 컬렉션 (탭/목록 빠르게 뿌리기)
“아시아 특가 TOP 50”, “미주 뚝떨어진 TOP 50” 같은 탭/목록을 매우 빠르게 제공하려면,
`deals`를 그대로 조회해도 되지만(인덱스 필요), 규모가 커지면 캐시성 뷰를 두는 게 좋아집니다.

- `feeds/{feedId}` 예: `feeds/asia_today_cheapest`
  - `generated_at`: Timestamp
  - `items` (Array<Map>): `[{ "deal_id": "...", "price": 123400, "destination_city_id":"jp_oka" }, ...]`

> 주의: `items`에 상세를 중복 저장하지 말고, 최소 메타 + `deal_id`만 두는 걸 권장합니다(중복/불일치 방지).

#### `outbound.segments[]` / `inbound.segments[]` (권장)
Trip.com 상세 화면처럼 **터미널/항공편번호/정확한 출도착 시각**을 담기 위해, “편도/왕복/경유” 모두 커버 가능한 구조로 저장합니다.

- `segments` (Array<Map>)
  - `dep_airport` (String): `"ICN"`
  - `dep_terminal` (String|null): `"T1"` (없으면 null)
  - `arr_airport` (String): `"OKA"`
  - `arr_terminal` (String|null): `"T2"` (없으면 null)
  - `dep_datetime` (Timestamp): `2025-12-28T07:20:00+09:00`
  - `arr_datetime` (Timestamp): `2025-12-28T09:55:00+09:00`
  - `duration_minutes` (Number): `155`
  - `flight_no` (String|null): `"TW241"` (파싱 가능 시)
  - `marketing_airline` (Map): `{ "code":"TW","name":"티웨이항공" }`
  - `operating_airline` (Map|null): `{ "code":"TW","name":"티웨이항공" }` (코드셰어면 다를 수 있음)
  - `stops` (Number): `0`
  - `aircraft` (String|null): `"B737"` (파싱 가능 시)

#### `baggage` (표시 + 필터에 유용)
- `checked_included` (Boolean|null): `true`
- `checked_allowance_kg` (Number|null): `15`
- `cabin_allowance_kg` (Number|null): `10`
- `notes` (String|null): `"위탁 수하물 15kg"` (원문/표시용)

#### `availability` (Trip.com의 “9석 미만 남음” 같은 UX용)
- `seats_left` (Number|null): `9` (정확히 숫자를 주면 저장, “9석 미만”만 주면 `9` 또는 null + 배지로 처리)
- `low_seats_threshold` (Number): `9`
- `is_low_seats` (Boolean): `true`
- `badges` (Array<String>): `["9석 미만 남음","최저가"]` (UI 배지용)
- `sold_out` (Boolean): `false`

### B. `price_history` 컬렉션 (가격 변동 그래프용)
특정 구간/날짜의 가격 추이를 기록합니다.

| 필드명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `deal_id` | String | `deals` 컬렉션의 문서 ID |
| `price` | Number | 해당 시점의 가격 |
| `currency` | String | 통화 (정규화) |
| `seats_left` | Number \| null | 해당 시점 잔여좌석(파싱 가능 시) |
| `is_low_seats` | Boolean | “9석 미만” 같은 재고 경고 여부 |
| `sold_out` | Boolean | 품절 여부 |
| `timestamp` | Timestamp | 크롤링 시점 |

---

## 2. 시나리오별 데이터 활용 전략

### ① 뚝 떨어진 항공권 (Suddenly Dropped)
- **로직**: `discount_rate` 필드가 가장 낮은(음수 폭이 큰) 순서대로 정렬하여 제공합니다.
- **필요 데이터**: 크롤링 시 해당 구간의 '평균가' 데이터를 별도로 관리하거나, 누적된 `price_history`를 통해 계산합니다.

### ② 주말 항공권 (Weekend Deals)
- **로직**: `is_weekend` 필드가 `true`인 데이터만 필터링합니다. 
- **조건**: 출발일이 금요일 또는 토요일이고, 도착일이 일요일 또는 월요일인 일정을 크롤링 단계에서 플래그 처리합니다.

### ③ 가격 비교 및 그래프
- **로직**: 특정 `deal_id`를 기준으로 `price_history` 컬렉션을 조회하여 시간축 그래프를 그립니다.
- **업데이트 주기**: 2시간마다 새로운 `price_history` 레코드를 추가합니다.

---

## 3. 크롤링 및 업데이트 프로세스 (2시간 주기)

1. **데이터 수집**: Trip.com 특가 페이지/상세에서 `도시, 날짜, 가격, 항공사, 출/도착 시각, 터미널, 항공편 번호, 수하물, 잔여좌석 배지(예: 9석 미만), 링크` 정보를 파싱합니다.
2. **평균가 비교**: DB에 저장된 해당 구간의 최근 60일 평균가와 현재가를 비교하여 `discount_rate`를 계산합니다.
3. **DB 업데이트**:
    - `deals` 컬렉션: 기존 문서가 있으면 현재 가격과 시간을 **Overwrite(덮어쓰기)** 하여 최신 상태 유지.
    - `price_history` 컬렉션: 매회 **Add(추가)** 하여 히스토리 보존(가격 + 재고/배지까지 같이 쌓으면 UX가 더 좋아짐).
4. **UI 표시**: 앱 상단에 `last_updated` 필드를 활용하여 "최근 업데이트: 2025년 12월 25일 22시" 메시지를 노출합니다.

---

## 4. 데이터 저장 샘플 (JSON)

```json
{
  "deal_id": "ICN_SGN_20250121_20250126_VJ",
  "origin": { "city": "서울", "code": "SEL", "airports": ["ICN"] },
  "destination": { "city": "호치민", "code": "SGN", "airports": ["SGN"] },
  "trip_type": "RT",
  "departure_date": "2025-01-21T00:00:00Z",
  "return_date": "2025-01-26T00:00:00Z",
  "price": 342400,
  "currency": "KRW",
  "discount_rate": -58.4,
  "outbound": {
    "segments": [
      {
        "dep_airport": "ICN",
        "dep_terminal": "T1",
        "arr_airport": "SGN",
        "arr_terminal": null,
        "dep_datetime": "2025-01-21T07:00:00+09:00",
        "arr_datetime": "2025-01-21T10:30:00+07:00",
        "duration_minutes": 330,
        "flight_no": "VJ863",
        "marketing_airline": { "code": "VJ", "name": "VietJet Air" },
        "operating_airline": { "code": "VJ", "name": "VietJet Air" },
        "stops": 0,
        "aircraft": null
      }
    ]
  },
  "baggage": {
    "checked_included": true,
    "checked_allowance_kg": 15,
    "cabin_allowance_kg": null,
    "notes": "위탁 수하물 15kg"
  },
  "availability": {
    "seats_left": 9,
    "low_seats_threshold": 9,
    "is_low_seats": true,
    "badges": ["9석 미만 남음", "최저가"],
    "sold_out": false
  },
  "is_weekend": false,
  "last_updated": "2025-12-25T22:00:00Z"
}
```
