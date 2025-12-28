# 특가 항공권 데이터베이스 설계 (Simplified)

본 문서는 제공된 UI 스크린샷을 바탕으로, 앱 화면 구현에 꼭 필요한 정보만 담은 심플한 Firestore 스키마를 정의합니다.

## 1. `deals` 컬렉션 구조

| 필드명 | 타입 | 설명 | 예시 |
| :--- | :--- | :--- | :--- |
| `deal_id` | String | 문서 고유 ID | `ICN_LAX_20250125_RT` |
| `city_name` | String | 도시 명 (표시용) | `"로스앤젤레스"` |
| `country_code` | String | 국가 코드 (국기 표시용) | `"US"` |
| `duration_days` | Number | 여행 기간 (일 단위) | `14` |
| `price` | Number | 현재 최저가 | `801600` |
| `discount_rate` | Number | 가격 하락폭 (%) | `-39.4` |
| `departure_date_display` | String | 출발 날짜 표시용 | `"1.25(일)"` |
| `return_date_display` | String | 오는 날짜 표시용 | `"2.7(토)"` |
| `outbound` | Map | 가는 편 상세 (UI 팝업용) | `{ ... }` |
| `inbound` | Map | 오는 편 상세 (UI 팝업용) | `{ ... }` |
| `booking_url` | String | 예약 페이지 링크 | `https://kr.trip.com/...` |
| `last_updated` | Timestamp | 마지막 업데이트 시각 | `2025-12-28 14:00:00` |

### A. `outbound` (가는 편) / `inbound` (오는 편) 구조
스크린샷의 "항공 일정 확인" 팝업 데이터에 최적화된 구조입니다. 가는 편과 오는 편의 스케줄이 다르므로 각각 별도의 객체로 저장합니다.

- **필드 구성 (두 맵 동일)**:
  - `departure_time`: 출발 시간 (`"22:20"`)
  - `arrival_time`: 도착 시간 (`"16:20"`)
  - `origin_airport`: 출발 공항 코드 (`"ICN"`)
  - `dest_airport`: 도착 공항 코드 (`"LAX"`)
  - `airline_name`: 항공사 명 (`"에어프레미아 주식회사"`)
  - `flight_no`: 편명 (`"YP0103"`)
  - `duration_text`: 비행 시간 (`"11시간"`)

---

## 2. 데이터 샘플 (JSON)

```json
{
  "deal_id": "ICN_LAX_20250125_YP",
  "city_name": "로스앤젤레스",
  "country_code": "US",
  "duration_days": 14,
  "price": 801600,
  "discount_rate": -39.4,
  "departure_date_display": "1.25(일)",
  "return_date_display": "2.7(토)",
  "outbound": {
    "departure_time": "22:20",
    "arrival_time": "16:20",
    "origin_airport": "ICN",
    "dest_airport": "LAX",
    "airline_name": "에어프레미아",
    "flight_no": "YP0103",
    "duration_text": "11시간"
  },
  "inbound": {
    "departure_time": "09:50",
    "arrival_time": "16:20",
    "origin_airport": "LAX",
    "dest_airport": "ICN",
    "airline_name": "에어프레미아",
    "flight_no": "YP0102",
    "duration_text": "13시간 30분"
  },
  "booking_url": "https://kr.trip.com/flights/...",
  "last_updated": "2025-12-28T14:00:00Z"
}
```

## 3. 주요 변경 사항
1. **평면화된 구조**: `segments` 배열을 제거하고 UI에서 바로 사용할 수 있도록 `outbound`, `inbound` 맵으로 고정했습니다. (스크린샷처럼 가는 편/오는 편이 명확히 구분된 UI 대응)
2. **표시용 필드 추가**: 날짜 계산 로직을 앱에서 수행하지 않도록 `departure_date_display` 같은 필드를 두어 크롤러에서 미리 포맷팅하여 저장합니다.
3. **단순화**: 복잡한 수하물 규정이나 주말 여부 플래그 등 화면에 직접 보이지 않는 정보는 제외하여 데이터 관리를 용이하게 했습니다.

