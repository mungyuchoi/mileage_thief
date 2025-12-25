# 특가 항공권 데이터베이스 및 크롤링 설계 (TRIP2)

본 문서는 Trip.com 특가 데이터를 기반으로 캐치프로그와 같은 사용자 경험을 제공하기 위한 Firestore 스키마 및 데이터 운영 전략을 정의합니다.

## 1. Firestore 데이터 구조 설계

### A. `deals` 컬렉션 (현재 유효한 특가)
이 컬렉션은 앱의 메인 화면에서 보여줄 "현재 가장 저렴한 특가" 정보를 관리합니다.

| 필드명 | 타입 | 설명 | 예시 |
| :--- | :--- | :--- | :--- |
| `deal_id` | String | 문서 고유 ID (조합형) | `ICN_OKA_20251228_OW_TW` |
| `origin` | Map | 출발지 정보 | `{ "city": "서울", "code": "ICN" }` |
| `destination` | Map | 목적지 정보 | `{ "city": "오키나와", "code": "OKA" }` |
| `trip_type` | String | 여정 타입 | `"OW"` (편도) / `"RT"` (왕복) |
| `departure_date` | Timestamp | 출발 날짜 | `2025-12-28 00:00:00` |
| `return_date` | Timestamp | 오는 날짜 (왕복 시) | `2026-01-02 00:00:00` (편도는 null) |
| `airline` | Map | 항공사 정보 | `{ "name": "티웨이항공", "logo_url": "https://..." }` |
| `seat_class` | String | 좌석 등급 | `"일반석"` |
| `has_baggage` | Boolean | 위탁 수하물 포함 여부 | `true` |
| `price` | Number | 현재 최저가 | `163700` |
| `avg_price_60d` | Number | 최근 60일 평균가 (뚝 떨어진 기준) | `250000` |
| `discount_rate` | Number | 평균 대비 하락폭 (%) | `-34.5` |
| `booking_url` | String | 예약 페이지 링크 | `https://kr.trip.com/...` |
| `outbound_flight` | Map | 가는 편 상세 시간 | `{ "dep": "07:20", "arr": "09:55", "duration": "2h 35m" }` |
| `inbound_flight` | Map | 오는 편 상세 시간 (왕복) | `{ "dep": "14:25", "arr": "17:00", "duration": "2h 35m" }` |
| `is_weekend` | Boolean | 주말 항공권 여부 (금/토/일 출발) | `true` |
| `last_updated` | Timestamp | 디비 업데이트 시간 | `2025-12-25 22:00:00` |

### B. `price_history` 컬렉션 (가격 변동 그래프용)
특정 구간/날짜의 가격 추이를 기록합니다.

| 필드명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `deal_id` | String | `deals` 컬렉션의 문서 ID |
| `price` | Number | 해당 시점의 가격 |
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

1. **데이터 수집**: Trip.com 특가 페이지에서 `도시, 날짜, 가격, 항공사, 시간, 링크` 정보를 파싱합니다.
2. **평균가 비교**: DB에 저장된 해당 구간의 최근 60일 평균가와 현재가를 비교하여 `discount_rate`를 계산합니다.
3. **DB 업데이트**:
    - `deals` 컬렉션: 기존 문서가 있으면 현재 가격과 시간을 **Overwrite(덮어쓰기)** 하여 최신 상태 유지.
    - `price_history` 컬렉션: 매회 **Add(추가)** 하여 히스토리 보존.
4. **UI 표시**: 앱 상단에 `last_updated` 필드를 활용하여 "최근 업데이트: 2025년 12월 25일 22시" 메시지를 노출합니다.

---

## 4. 데이터 저장 샘플 (JSON)

```json
{
  "deal_id": "ICN_SGN_20250121_20250126_VJ",
  "origin": { "city": "서울/인천", "code": "ICN" },
  "destination": { "city": "호치민", "code": "SGN" },
  "trip_type": "RT",
  "departure_date": "2025-01-21T00:00:00Z",
  "return_date": "2025-01-26T00:00:00Z",
  "price": 342400,
  "discount_rate": -58.4,
  "outbound_flight": {
    "dep_time": "07:00",
    "arr_time": "10:30",
    "duration": "5시간 30분"
  },
  "is_weekend": false,
  "last_updated": "2025-12-25T22:00:00Z"
}
```
