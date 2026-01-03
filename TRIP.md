# 특가 항공권 데이터베이스 설계

본 문서는 땡처리닷컴 및 여러 여행사(모두투어, 하나투어, 노랑풍선, 온라인투어)에서 파싱한 특가 항공권 정보를 저장하기 위한 Firestore 스키마를 정의합니다.

## 1. Firestore 컬렉션 구조

### 1.1 전체 구조

```
deals/
  {deal_id}/                  # 각 딜 문서 (deal_id에 agency_code 정보 포함)
    - price: 149000
    - price_display: "149,000원"
    - agency_code: "hanatour"  # 여행사 코드
    - agency: "하나투어"        # 여행사명
    - booking_url: "https://..."
    - booking_data: { ... }
    - ... (기타 필드)
    price_history/            # 가격 이력 서브컬렉션
      {timestamp}/            # 예: "20250111_143000_123456"
        - price: 149000
        - previous_price: 159000
        - price_change: -10000
        - price_change_percent: -6.29
        - recorded_at: Timestamp
        - ...
```

**경로 예시**:
- `deals/hanatour_ICN_BKK_20260105_7C_1930`
- `deals/ttangdeal_ICN_PQC_7C2355PUSPQC-G5`
- `deals/hanatour_ICN_BKK_20260105_7C_1930/price_history/20250111_143000_123456`

**참고**: `deal_id`에 이미 여행사 정보가 포함되어 있거나, 문서 내 `agency_code` 필드로 구분할 수 있으므로 별도로 여행사별로 분리하지 않습니다.

**지원되는 여행사 코드 (agency_code)**:
- `hanatour`: 하나투어
- `ttangdeal`: 땡처리닷컴
- `modetour`: 모두투어
- `yellowtour`: 노랑풍선
- `onlinetour`: 온라인투어

## 2. `deals/{deal_id}` 문서 구조

| 필드명 | 타입 | 설명 | 예시 |
| :--- | :--- | :--- | :--- |
| `deal_id` | String | 문서 고유 ID (노선+날짜+편명 조합) | `ICN_PQC_20250119_7C2355_7C2356` |
| `origin_city` | String | 출발 도시명 (표시용) | `"인천"` |
| `origin_airport` | String | 출발 공항 코드 | `"ICN"` |
| `dest_city` | String | 도착 도시명 (표시용) | `"푸꾸옥"` |
| `dest_airport` | String | 도착 공항 코드 | `"PQC"` |
| `country_code` | String | 국가 코드 (국기 표시용) | `"VN"` |
| `airline_code` | String | 항공사 코드 | `"7C"` |
| `airline_name` | String | 항공사 명 | `"제주항공"` |
| `is_direct` | Boolean | 직항 여부 | `true` |
| `via_count` | Number | 경유 횟수 | `0` |
| `flight_duration` | String | 비행 시간 (표시용) | `"6h 0m"` |
| `price` | Number | 현재 최저가 (원) | `149000` |
| `price_display` | String | 가격 표시용 | `"149,000원"` |
| `supply_start_date` | String | 공급 시작일 (YYYYMMDD) | `"20260119"` |
| `supply_end_date` | String | 공급 종료일 (YYYYMMDD) | `"20260130"` |
| `date_ranges` | Array | 가능한 출발일 범위 배열 | `[{ "start": "2026-01-19", "end": "2026-01-30" }]` |
| `available_dates` | Array | 예약 가능한 날짜 버튼 정보 | `[{ "departure": "1/5(월)", "return": "1/8(목)" }]` |
| `minimum_passengers` | Number | 최소 예약 인원 | `1` |
| `trip_type` | String | 여정 유형 | `"VV"` (왕복) |
| `master_id` | String | 여행사 마스터 ID | `"7C2355PUSPQC-G5"` |
| `agency` | String | 여행사명 | `"모두투어"` |
| `agency_code` | String | 여행사 코드 | `"modetour"` |
| `schedule_count` | Number | 일정 개수 | `1` |
| `outbound` | Map | 가는 편 상세 (UI 팝업용) | `{ ... }` |
| `inbound` | Map | 오는 편 상세 (UI 팝업용) | `{ ... }` |
| `booking_url` | String | 예약 페이지 링크 | `https://www.ttang.com/...` |
| `booking_data` | Map | 예약 시 필요한 데이터 | `{ "minimumcnt": 1, "viacnt": 0, ... }` |
| `last_updated` | Timestamp | 마지막 업데이트 시각 | `2025-12-28 14:00:00` |

### A. `deal_id` 생성 규칙 (중요)
여행사별로 동일한 노선/날짜가 있을 수 있으므로 `agency_code`를 prefix로 포함합니다.

**기본 규칙**: `{agency_code}_{출발공항}_{도착공항}_{...}`

#### A-1. 하나투어 (`hanatour`) deal_id
- **규칙**: `{agency_code}_{출발공항}_{도착공항}_{출발날짜}_{항공사코드}_{출발시간}`
- **예시**: `hanatour_ICN_BKK_20260105_7C_1930`
- **효과**: 같은 날짜/노선이라도 시간대가 다르면 별개의 특가 정보로 저장

#### A-2. 땡처리닷컴 (`ttangdeal`) deal_id
- **규칙**: `{agency_code}_{출발공항}_{도착공항}_{마스터ID}` 또는 `{agency_code}_{출발공항}_{도착공항}_{타임스탬프}`
- **예시**: `ttangdeal_ICN_PQC_7C2355PUSPQC-G5` 또는 `ttangdeal_ICN_PQC_20250111143000`
- **효과**: 마스터 ID가 있으면 사용, 없으면 타임스탬프 사용

**중요**: `agency_code`를 prefix로 포함하여 다른 여행사의 동일 노선과 구분합니다.

### B. `outbound` (가는 편) / `inbound` (오는 편) 구조
땡처리닷컴에서 제공하는 항공 일정 상세 정보를 저장합니다. 가는 편과 오는 편의 스케줄이 다르므로 각각 별도의 객체로 저장합니다.

- **필드 구성 (두 맵 동일)**:
  - `departure_time`: 출발 시간 (`"22:20"`) - 선택적 (상세 정보가 있는 경우)
  - `arrival_time`: 도착 시간 (`"16:20"`) - 선택적
  - `origin_airport`: 출발 공항 코드 (`"ICN"`)
  - `dest_airport`: 도착 공항 코드 (`"PQC"`)
  - `airline_code`: 항공사 코드 (`"7C"`)
  - `airline_name`: 항공사 명 (`"제주항공"`)
  - `flight_no`: 편명 (`"7C2355"`) - 선택적
  - `duration_text`: 비행 시간 (`"6h 0m"` 또는 `"6시간"`)

**참고**: 땡처리닷컴의 기본 리스트에서는 상세 시간 정보가 없을 수 있으므로, `outbound`와 `inbound`는 선택적 필드입니다. 상세 정보가 없는 경우 상위 레벨의 `flight_duration`을 사용합니다.

### C. `available_dates` 배열 구조
UI에서 날짜 버튼으로 표시할 수 있는 예약 가능한 날짜 조합을 저장합니다.

- **필드 구성**:
  - `departure`: 출발일 표시 (`"1/5(월)"`)
  - `return`: 귀국일 표시 (`"1/8(목)"`)
  - `departure_date`: 출발일 (YYYY-MM-DD) (`"2026-01-05"`)
  - `return_date`: 귀국일 (YYYY-MM-DD) (`"2026-01-08"`)
  - `price`: 해당 날짜 조합의 가격 (선택적)

### D. `booking_data` 구조
예약 페이지로 이동할 때 필요한 데이터를 저장합니다. 여행사별로 구조가 다를 수 있습니다.

#### D-1. 땡처리닷컴 (`ttangdeal`) 구조
- **필드 구성**:
  - `minimumcnt`: 최소 예약 인원 (`1` 또는 `2`)
  - `viacnt`: 경유 횟수 (`0`)
  - `depcity`: 출발 공항 코드 (`"ICN"`)
  - `gubun`: 구분 (`"VV"` - 왕복)
  - `airlinecode`: 도착 공항 코드 (`"PQC"`)
  - `masterid`: 마스터 ID (`"7C2355PUSPQC-G5"`)
  - `fromsupplydt`: 공급 시작일 (`"20260119"`)
  - `tosupplydt`: 공급 종료일 (`"20260130"`)

#### D-2. 하나투어 (`hanatour`) 구조
하나투어는 상세 페이지 URL의 `searchParam` 파라미터를 JSON으로 파싱하여 저장합니다.

- **필드 구성**:
  - `fareId`: 요금 ID (예: `"RTF^2960500^7C2503ICNBKK-H4^..."`)
  - `selectedCard`: 선택된 카드 정보 (할인 정보 포함)
    - `totAmt`: 총 금액
    - `dtcmAdtDcAplSaleAmt`: 성인 할인 적용 금액
    - `dtcmChdDcAplSaleAmt`: 아동 할인 적용 금액
    - `dtcmInfDcAplSaleAmt`: 유아 할인 적용 금액
  - `searchCond`: 검색 조건
    - `itnrTypeCd`: 여정 유형 (`"RT"` - 왕복, `"OW"` - 편도)
    - `seatGradCd`: 좌석 등급 (`"Y"` - 일반석)
    - `nonStopOnly`: 직항만 (`"N"` 또는 `"Y"`)
    - `psngrCntLst`: 승객 수 리스트
    - `itnrLst`: 여정 리스트
      - `depPlcCd`: 출발 공항 코드
      - `arrPlcCd`: 도착 공항 코드
      - `depDt`: 출발일 (YYYYMMDD)
  - `isViewPsngrChange`: 인원 변경 보기 여부

**예시**:
```json
{
  "fareId": "RTF^2960500^7C2503ICNBKK-H4^7C2503ICNBKK-6^20260103^T^KRW^6300199^5038791^^1^0^0",
  "selectedCard": {
    "totAmt": 399000,
    "dtcmAdtDcAplSaleAmt": 260500
  },
  "searchCond": {
    "itnrTypeCd": "RT",
    "seatGradCd": "Y",
    "itnrLst": [
      {
        "depPlcCd": "ICN",
        "arrPlcCd": "BKK",
        "depDt": "20260103"
      },
      {
        "depPlcCd": "BKK",
        "arrPlcCd": "ICN",
        "depDt": "20260107"
      }
    ]
  }
}
```

### E. `price_history` 서브컬렉션 구조
가격 변동 이력을 시간순으로 저장합니다. 각 딜 문서 아래 `price_history` 서브컬렉션에 저장됩니다.

**경로**: `deals/{deal_id}/price_history/{timestamp}`

**문서 ID 형식**: `YYYYMMDD_HHMMSS_microseconds` (예: `"20250111_143000_123456"`)

**필드 구성**:
- `price`: 현재 가격 (Number)
- `price_display`: 가격 표시용 (String, 예: `"149,000원"`)
- `previous_price`: 이전 가격 (Number, 첫 기록인 경우 없음)
- `price_change`: 가격 변동 금액 (Number, 이전 가격 대비)
- `price_change_percent`: 가격 변동률 (Number, %, 소수점 2자리)
- `recorded_at`: 기록 시각 (Timestamp, Firestore SERVER_TIMESTAMP)
- `supply_start_date`: 공급 시작일 (String, YYYYMMDD)
- `supply_end_date`: 공급 종료일 (String, YYYYMMDD)

**예시**:
```json
{
  "price": 149000,
  "price_display": "149,000원",
  "previous_price": 159000,
  "price_change": -10000,
  "price_change_percent": -6.29,
  "recorded_at": "2025-01-11T14:30:00Z",
  "supply_start_date": "20260119",
  "supply_end_date": "20260130"
}
```

**사용 목적**:
- 가격 추이 차트 생성
- 가격 하락 알림 발송
- 가격 변동 분석

---

## 3. 데이터 샘플 (JSON)

### 예시 1: 땡처리닷컴 기본 데이터 (인천 → 푸꾸옥)

```json
{
  "deal_id": "ttangdeal_ICN_PQC_7C2355PUSPQC-G5",
  "origin_city": "인천",
  "origin_airport": "ICN",
  "dest_city": "푸꾸옥",
  "dest_airport": "PQC",
  "country_code": "VN",
  "airline_code": "7C",
  "airline_name": "제주항공",
  "is_direct": true,
  "via_count": 0,
  "flight_duration": "6h 0m",
  "price": 149000,
  "price_display": "149,000원",
  "supply_start_date": "20260119",
  "supply_end_date": "20260130",
  "date_ranges": [
    {
      "start": "2026-01-19",
      "end": "2026-01-30"
    }
  ],
  "available_dates": [
    {
      "departure": "1/5(월)",
      "return": "1/8(목)",
      "departure_date": "2026-01-05",
      "return_date": "2026-01-08"
    }
  ],
  "minimum_passengers": 1,
  "trip_type": "VV",
  "master_id": "7C2355PUSPQC-G5",
  "agency": "모두투어",
  "agency_code": "modetour",
  "schedule_count": 1,
  "outbound": {
    "origin_airport": "ICN",
    "dest_airport": "PQC",
    "airline_code": "7C",
    "airline_name": "제주항공",
    "duration_text": "6h 0m"
  },
  "inbound": {
    "origin_airport": "PQC",
    "dest_airport": "ICN",
    "airline_code": "7C",
    "airline_name": "제주항공",
    "duration_text": "6h 0m"
  },
  "booking_url": "https://www.ttang.com/ttangair/search/discount/index.do",
  "booking_data": {
    "minimumcnt": 1,
    "viacnt": 0,
    "depcity": "ICN",
    "gubun": "VV",
    "airlinecode": "PQC",
    "masterid": "7C2355PUSPQC-G5",
    "fromsupplydt": "20260119",
    "tosupplydt": "20260130"
  },
  "last_updated": "2025-12-28T14:00:00Z"
}
```

### 예시 2: 2명 이상 예약 가능한 상품 (부산 → 후쿠오카)

```json
{
  "deal_id": "ttangdeal_PUS_FUK_7C1451PUSFUK-G4",
  "origin_city": "부산",
  "origin_airport": "PUS",
  "dest_city": "후쿠오카",
  "dest_airport": "FUK",
  "country_code": "JP",
  "airline_code": "7C",
  "airline_name": "제주항공",
  "is_direct": true,
  "via_count": 0,
  "flight_duration": "1h 30m",
  "price": 210000,
  "price_display": "210,000원",
  "supply_start_date": "20260117",
  "supply_end_date": "20260326",
  "date_ranges": [
    {
      "start": "2026-01-17",
      "end": "2026-03-26"
    }
  ],
  "available_dates": [],
  "minimum_passengers": 2,
  "trip_type": "VV",
  "master_id": "7C1451PUSFUK-G4",
  "agency": "땡처리닷컴",
  "agency_code": "ttangdeal",
  "schedule_count": 1,
  "outbound": {
    "origin_airport": "PUS",
    "dest_airport": "FUK",
    "airline_code": "7C",
    "airline_name": "제주항공"
  },
  "inbound": {
    "origin_airport": "FUK",
    "dest_airport": "PUS",
    "airline_code": "7C",
    "airline_name": "제주항공"
  },
  "booking_url": "https://www.ttang.com/ttangair/search/discount/index.do",
  "booking_data": {
    "minimumcnt": 2,
    "viacnt": 0,
    "depcity": "PUS",
    "gubun": "VV",
    "airlinecode": "FUK",
    "masterid": "7C1451PUSFUK-G4",
    "fromsupplydt": "20260117",
    "tosupplydt": "20260326"
  },
  "last_updated": "2025-12-28T14:00:00Z"
}
```

### 예시 3: 하나투어 데이터 (인천 → 방콕)

**Firestore 경로**: `deals/hanatour_ICN_BKK_20260105_7C_1930`

```json
{
  "deal_id": "hanatour_ICN_BKK_20260105_7C_1930",
  "origin_city": "인천",
  "origin_airport": "ICN",
  "dest_city": "방콕",
  "dest_airport": "BKK",
  "country_code": "TH",
  "airline_code": "7C",
  "airline_name": "제주항공",
  "is_direct": true,
  "via_count": 0,
  "flight_duration": "4h 15m",
  "price": 199000,
  "price_display": "199,000원",
  "supply_start_date": "20260105",
  "supply_end_date": "20260109",
  "date_ranges": [
    {
      "start": "2026-01-05",
      "end": "2026-01-09"
    }
  ],
  "available_dates": [
    {
      "departure": "1/5(월)",
      "return": "1/9(금)",
      "departure_date": "2026-01-05",
      "return_date": "2026-01-09"
    }
  ],
  "minimum_passengers": 1,
  "trip_type": "VV",
  "master_id": "",
  "agency": "하나투어",
  "agency_code": "hanatour",
  "schedule_count": 1,
  "outbound": {
    "origin_airport": "ICN",
    "dest_airport": "BKK",
    "airline_code": "7C",
    "airline_name": "제주항공",
    "departure_time": "19:30",
    "arrival_time": "23:45"
  },
  "inbound": {
    "origin_airport": "BKK",
    "dest_airport": "ICN",
    "airline_code": "7C",
    "airline_name": "제주항공",
    "departure_time": "00:50",
    "arrival_time": "06:20"
  },
  "booking_url": "https://m.hanatour.com/trp/air/CHPC0AIR0212M100?searchParam=%7B%22fareId%22%3A...",
  "booking_data": {
    "fareId": "RTF^2960500^7C2503ICNBKK-H4^7C2503ICNBKK-6^20260103^T^KRW^6300199^5038791^^1^0^0",
    "selectedCard": {
      "totAmt": 399000,
      "dtcmAdtDcAplSaleAmt": 260500,
      "dtcmChdDcAplSaleAmt": 267500,
      "dtcmInfDcAplSaleAmt": 50000
    },
    "searchCond": {
      "itnrTypeCd": "RT",
      "seatGradCd": "Y",
      "nonStopOnly": "N",
      "psngrCntLst": [
        {
          "ageDvCd": "A",
          "psngrCnt": 1
        }
      ],
      "itnrLst": [
        {
          "depPlcCd": "ICN",
          "depPlcNm": "인천 국제공항",
          "depPlcDvCd": "A",
          "arrPlcCd": "BKK",
          "arrPlcNm": "수완나품 국제공항",
          "arrPlcDvCd": "A",
          "depDt": "20260103"
        },
        {
          "depPlcCd": "BKK",
          "arrPlcCd": "ICN",
          "depDt": "20260107"
        }
      ]
    },
    "isViewPsngrChange": true
  },
  "last_updated": "2025-01-11T14:30:00Z"
}
```

**가격 이력 예시** (`deals/hanatour_ICN_BKK_20260105_7C_1930/price_history/20250111_143000_123456`):

```json
{
  "price": 199000,
  "price_display": "199,000원",
  "previous_price": 209000,
  "price_change": -10000,
  "price_change_percent": -4.78,
  "recorded_at": "2025-01-11T14:30:00Z",
  "supply_start_date": "20260105",
  "supply_end_date": "20260109"
}
```

## 4. 주요 특징 및 설계 고려사항

### 3.1 땡처리닷컴 데이터 구조 대응
- **여행사 정보**: `agency`와 `agency_code` 필드로 여러 여행사(모두투어, 하나투어, 땡처리닷컴, 노랑풍선, 온라인투어) 구분
- **예약 데이터**: `booking_data` 맵에 예약 페이지 이동 시 필요한 모든 정보 저장
- **날짜 범위**: `supply_start_date`와 `supply_end_date`로 공급 기간 관리
- **최소 인원**: `minimum_passengers`로 2명 이상 예약 가능한 상품 구분

### 3.2 UI 요구사항 대응
- **필터링**: `origin_airport`, `dest_airport`, `airline_code`, `agency_code`, `is_direct` 등으로 필터링 지원
- **정렬**: `price` 필드로 가격순 정렬 지원
- **날짜 버튼**: `available_dates` 배열로 UI의 날짜 버튼 생성 가능
- **항공사/여행사 로고**: `airline_code`와 `agency_code`로 이미지 경로 생성 가능

### 3.3 데이터 확장성
- **다중 여행사**: 같은 노선이라도 다른 여행사에서 제공하는 경우 별도 문서로 저장
- **날짜 범위**: `date_ranges` 배열로 여러 날짜 범위 지원 (향후 확장 가능)
- **선택적 필드**: `outbound`/`inbound`의 상세 시간 정보는 선택적 (기본 리스트에는 없을 수 있음)

### 4.4 크롤러 구현 시 주의사항
1. **deal_id 생성**: `agency_code`를 prefix로 포함하여 여행사별 구분
   - 하나투어: `{agency_code}_{출발공항}_{도착공항}_{출발날짜}_{항공사코드}_{출발시간}` (예: `hanatour_ICN_BKK_20260105_7C_1930`)
   - 땡처리닷컴: `{agency_code}_{출발공항}_{도착공항}_{마스터ID}` (예: `ttangdeal_ICN_PQC_7C2355PUSPQC-G5`)
2. **가격 파싱**: "210,000원∼" 형식에서 숫자만 추출하여 `price`에 저장
3. **날짜 파싱**: "2026.01.17~2026.03.26" 형식을 파싱하여 `supply_start_date`, `supply_end_date` 저장
4. **여행사 구분**: 크롤링하는 여행사에 따라 `agency`와 `agency_code` 설정
5. **예약 데이터**: 
   - 땡처리닷컴: HTML의 `data-*` 속성들을 모두 `booking_data`에 저장
   - 하나투어: Playwright로 아이템 클릭 후 이동한 URL의 `searchParam` 파라미터를 JSON으로 파싱하여 저장
6. **가격 이력 기록**: 크롤링 시 가격이 변동된 경우 `price_history` 서브컬렉션에 자동 기록
7. **Firestore 경로**: `deals/{deal_id}` 구조로 저장 (deal_id에 이미 agency_code 정보 포함)

## 5. 참고 사이트 UI 요소와의 매핑

| UI 요소 | DB 필드 | 비고 |
| :--- | :--- | :--- |
| 출발지 선택 | `origin_airport`, `origin_city` | 드롭다운/검색 필터 |
| 도착지 검색 | `dest_airport`, `dest_city` | 검색 필터 |
| 항공사 필터 | `airline_code`, `airline_name` | 필터 및 로고 표시 |
| 여행사 필터 | `agency_code`, `agency` | 필터 및 로고 표시 |
| 직항/경유 표시 | `is_direct`, `via_count` | "직항" 또는 "경유" 표시 |
| 비행 시간 | `flight_duration` | "6h 0m" 형식 |
| 일정 개수 | `schedule_count` | "1개 일정" 표시 |
| 날짜 버튼 | `available_dates` | 날짜 버튼 배열 |
| 가격 | `price`, `price_display` | "149,000원" 표시 |
| 예약하기 버튼 | `booking_url`, `booking_data` | 예약 페이지 이동 |


장점
중복 제거: 각 딜마다 URL 저장 불필요
일관성: 항공사/여행사 정보가 한 곳에서 관리
유지보수: 로고 변경 시 한 곳만 수정
확장성: 항공사별 추가 정보(색상, 국가 등) 추가 용이
크롤러에서 airline_code를 추출해 airlines 컬렉션을 자동으로 생성/업데이트하도록 구현하면 됩니다.

airlines/
  {airline_code}/          # 예: "7C", "HX", "OZ"
    - name: "제주항공"
    - code: "7C"
    - logo_url: "https://storage.../7C.png"
    - country: "KR"
    - updated_at: timestamp

agencies/                   # 여행사도 동일하게
  {agency_code}/           # 예: "modetour", "hanatour"
    - name: "모두투어"
    - code: "modetour"
    - logo_url: "https://storage.../modetour.png"
    - updated_at: timestamp

deals/
  {deal_id}/                  # 각 딜 문서
    - airline_code: "7C"       # 참조만
    - agency_code: "hanatour"  # 참조만
    - ... (기타 필드)
    price_history/             # 가격 이력 서브컬렉션
      {timestamp}/             # 각 가격 변동 기록