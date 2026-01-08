# 마일캐치 호텔 특가 Firebase Firestore DB 설계

최종 업데이트: 2026-01-07
기능 범위: 호텔 특가 피드, 딜 카드, 즐겨찾기

---

## :hotel: 개요

마일캐치 '특가 호텔' 서비스를 위한 Firestore 데이터 구조입니다.
- 핵심 원칙: **읽기 효율 최우선** + **비용 최소화**
- Provider: **아고다 단독** (트립닷컴 제외)
- 크롤링 범위: **오늘/내일/이번주말/다음주말** (7일 이내 제외)
- 섹션: **앱 하드코딩** (Firestore 저장 X)

---

## :bar_chart: Enum 정의

### WindowKey (체크인 시점)
| 값 | 설명 |
|---|---|
| TODAY | 오늘 체크인 |
| TOMORROW | 내일 체크인 |
| THIS_WEEKEND | 이번 주말 |
| NEXT_WEEKEND | 다음 주말 |

### RegionKey (지역 코드)

**:kr: 국내**
| 값 | 설명 |
|---|---|
| KR_SEOUL | 서울 |
| KR_JEJU | 제주도 |
| KR_BUSAN | 부산 |
| KR_INCHEON | 인천 |
| KR_DAEGU | 대구 |
| KR_SOKCHO | 속초 |
| KR_YEOSU | 여수 |
| KR_OTHER | 기타 국내 도시 |

**:cn: 중국**
| 값 | 설명 |
|---|---|
| CN_HONGKONG | 홍콩 |
| CN_MACAU | 마카오 |
| CN_BEIJING | 베이징 |
| CN_SHANGHAI | 상하이 |
| CN_GUANGZHOU | 광저우 |
| CN_SHENZHEN | 선전 |
| CN_OTHER | 기타 중국 도시 |

**:jp: 일본**
| 값 | 설명 |
|---|---|
| JP_TOKYO | 도쿄 |
| JP_OSAKA | 오사카 |
| JP_FUKUOKA | 후쿠오카 |
| JP_KYOTO | 교토 |
| JP_SAPPORO | 삿포로 |
| JP_OKINAWA | 오키나와 |
| JP_OTHER | 기타 일본 도시 |

**:earth_asia: 아시아**
| 값 | 설명 |
|---|---|
| TH_THAILAND | 태국 |
| SG_SINGAPORE | 싱가포르 |
| VN_VIETNAM | 베트남 |
| PH_PHILIPPINES | 필리핀 |
| ID_INDONESIA | 인도네시아 |
| IN_INDIA | 인도 |
| MY_MALAYSIA | 말레이시아 |
| ASIA_OTHER | 기타 아시아 |

**:flag-eu: 유럽**
| 값 | 설명 |
|---|---|
| GB_UK | 영국 |
| GR_GREECE | 그리스 |
| IT_ITALY | 이탈리아 |
| FR_FRANCE | 프랑스 |
| DE_GERMANY | 독일 |
| ES_SPAIN | 스페인 |
| PT_PORTUGAL | 포르투갈 |
| EU_OTHER | 기타 유럽 |

**:earth_americas: 북미**
| 값 | 설명 |
|---|---|
| US_USA | 미국 |
| CA_CANADA | 캐나다 |
| MX_MEXICO | 멕시코 |

**:earth_asia: 오세아니아**
| 값 | 설명 |
|---|---|
| AU_AUSTRALIA | 호주 |
| NZ_NEWZEALAND | 뉴질랜드 |
| OC_OTHER | 기타 오세아니아 |

**:earth_africa: 중동**
| 값 | 설명 |
|---|---|
| AE_UAE | 아랍에미리트 |
| SA_SAUDI | 사우디아라비아 |
| QA_QATAR | 카타르 |
| ME_OTHER | 기타 중동 |

**:earth_africa: 아프리카**
| 값 | 설명 |
|---|---|
| ZA_SOUTHAFRICA | 남아프리카 공화국 |
| MA_MOROCCO | 모로코 |
| AF_OTHER | 기타 아프리카 |

---

## :file_folder: hotel_static/{hotelId}

**호텔 정적 정보 (월 1회 또는 수동 업데이트)**

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| hotelId | string | 문서 ID (아고다 propertyId) |
| name | string | 호텔명 |
| cityId | string | 아고다 city ID (예: "14690") |
| regionKey | string | 지역 코드 |
| areaName | string | 상세 지역명 (예: "영등포", "강남") |
| isLocal | boolean | 국내 호텔 여부 |
| starRating | number | 호텔 성급 (1~5, 소수점 가능, 예: 1.5, 2, 3, 4) |
| imageUrls | array<string> | 이미지 URL 목록 (최대 10개, 전체 URL) |
| amenityTags | array<string> | 편의시설 태그 (최대 5개, 검색 결과 페이지에는 없음) |
| visitCount | number | 유저 방문 횟수 (기본 0, 앱/서버에서 방문 시 +1) |
| source | string | 데이터 출처 ("SPECIAL_DEAL" \| "USER_REQUEST") |
| updatedAt | string | 수정일 (ISO 8601 형식, 예: "2026-01-07T18:08:30.105924Z") |
| _reviewScore | number? | 리뷰 점수 (내부 사용, hotel_deal_cards에서 참조) |
| _reviewCount | number? | 리뷰 개수 (내부 사용, hotel_deal_cards에서 참조) |

> **원본 URL 생성 방법 (cityId + hotelId 방식)**
> ```
> https://www.agoda.com/ko-kr/search?cid={cid}&city={cityId}&selectedproperty={hotelId}&adults=2&Rooms=1&Checkin={checkin}&Checkout={checkout}&los=1&currencyCode=KRW
> ```
>
> **참고**:
> - cid는 어필리에이트 ID (기본값: "1881766")
> - 날짜 형식: YYYY-MM-DD
> - hotel_static.py와 hotel_Deal_cards.py 모두 동일한 URL 형식 사용

### :arrow_forward: 예시 문서
```json
{
  "hotelId": "4261773",
  "name": "캡슐 호텔 마중",
  "cityId": "14690",
  "regionKey": "KR_SEOUL",
  "areaName": "영등포",
  "isLocal": true,
  "starRating": 1.5,
  "imageUrls": [
    "https://pix8.agoda.net/hotelImages/4261773/-1/12cb57a5a0d98dfc8216ba7a0ab5fd78.jpg?ca=9&ce=1",
    "https://pix8.agoda.net/hotelImages/4261773/-1/eb37d0293bcf0f6fcb5a1d3d25793496.jpg?ca=9&ce=1",
    "https://pix8.agoda.net/hotelImages/4261773/-1/57321a83ac0cc6b7bd7b75029ddcaac1.jpg?ca=9&ce=1"
  ],
  "amenityTags": [],
  "visitCount": 0,
  "source": "SPECIAL_DEAL",
  "updatedAt": "2026-01-07T18:08:30.105924Z",
  "_reviewScore": 7.3,
  "_reviewCount": 360
}
```

---

## :file_folder: hotel_static/{hotelId}/price_history/{priceHistoryId}

**호텔 가격 이력 (가격 추이 분석용)**

> priceHistoryId 형식: `${hotelId}_${checkInDate}_${windowKey}`
> 예: `4261773_2026-01-08_TODAY`

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| priceHistoryId | string | 문서 ID (hotelId + checkInDate + windowKey 조합) |
| hotelId | string | 호텔 ID |
| checkInDate | string | 체크인 날짜 (YYYY-MM-DD) |
| windowKey | string | 체크인 시점 (TODAY \| TOMORROW \| THIS_WEEKEND \| NEXT_WEEKEND) |
| price | number | 1박 가격 (원화, 세금 제외) |
| totalPrice | number | 총 금액 (세금 포함) |
| discountPct | number | 할인율 (%) |
| hasFreeCancellation | boolean | 무료 취소 가능 여부 |
| remainingRooms | number? | 남은 객실 수 (null 가능) |
| recordedAt | string | 기록 시각 (ISO 8601 형식) |

### :arrow_forward: 저장 규칙

- `hotel_deal_cards`에서 딜 카드가 생성될 때마다 자동으로 저장
- 같은 `hotelId`, `checkInDate`, `windowKey` 조합이 이미 존재하면 **최신 값으로 덮어쓰기**
- 가격 추이 분석을 위해 모든 가격 변동을 기록

### :arrow_forward: 쿼리 예시

```javascript
// 특정 호텔의 가격 이력 조회 (최신순)
db.collectionGroup("price_history")
  .where("hotelId", "==", "4261773")
  .orderBy("checkInDate", "desc")
  .orderBy("recordedAt", "desc")
  .limit(100);

// 특정 날짜의 가격 이력 조회
db.collectionGroup("price_history")
  .where("hotelId", "==", "4261773")
  .where("checkInDate", "==", "2026-01-08")
  .orderBy("recordedAt", "desc");

// 특정 windowKey의 가격 추이 조회
db.collectionGroup("price_history")
  .where("hotelId", "==", "4261773")
  .where("windowKey", "==", "TODAY")
  .orderBy("checkInDate", "asc")
  .orderBy("recordedAt", "asc");
```

### :arrow_forward: 예시 문서

```json
{
  "priceHistoryId": "4261773_2026-01-08_TODAY",
  "hotelId": "4261773",
  "checkInDate": "2026-01-08",
  "windowKey": "TODAY",
  "price": 46147,
  "totalPrice": 55837,
  "discountPct": 36,
  "hasFreeCancellation": true,
  "remainingRooms": null,
  "recordedAt": "2026-01-07T19:14:56.839755Z"
}
```

> **참고**:
> - 같은 날짜에 여러 번 크롤링되면 마지막 값으로 덮어쓰기됨
> - 가격 변동 추이를 분석하기 위해 `recordedAt` 필드로 시간대별 기록 가능
> - CollectionGroup 쿼리를 사용하여 모든 호텔의 가격 이력을 한 번에 조회 가능

---

## :file_folder: hotel_requests/{requestId}

**사용자 호텔 추가 요청** (앱에서 호텔 URL 붙여넣기로 요청)

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| requestId | string | 문서 ID (자동 생성) |
| url | string | 사용자가 입력한 아고다 URL |
| hotelId | string? | 파싱된 propertyId (있으면) |
| cityId | string? | 파싱된 cityId (있으면) |
| status | string | 요청 상태 |
| requestedBy | string? | 요청자 UID (로그인 시) |
| requestedAt | timestamp | 요청 시각 |
| processedAt | timestamp? | 처리 완료 시각 |
| errorMessage | string? | 실패 사유 |

### :arrow_forward: status 값

| 값 | 설명 |
|---|---|
| pending | 대기 중 |
| processing | 처리 중 |
| completed | 완료 |
| failed | 실패 |

### :arrow_forward: URL 파싱 규칙

```javascript
// Case 1: 검색 결과 URL → hotelId, cityId 바로 추출
// https://www.agoda.com/ko-kr/search?city=14690&selectedproperty=4261773
// → hotelId: "4261773", cityId: "14690"

// Case 2: 슬러그 URL → 크롤링 필요 (hotelId 없음)
// https://www.agoda.com/ko-kr/rodem-house-nonhyeon/hotel/seoul-kr.html
// → hotelId: null, cityId: null, needsCrawling: true
```

### :arrow_forward: 예시 문서
```json
{
  "requestId": "req_abc123def456",
  "url": "https://www.agoda.com/ko-kr/search?city=14690&selectedproperty=4261773",
  "hotelId": "4261773",
  "cityId": "14690",
  "status": "pending",
  "requestedBy": "user_uid_12345",
  "requestedAt": "2026-01-07T10:00:00Z",
  "processedAt": null,
  "errorMessage": null
}
```

---

## :file_folder: hotel_deal_cards/{dealId}

**피드용 "딜 카드" 문서 (앱이 주로 읽는 핵심 컬렉션)**

> dealId 형식: `${regionKey}_${windowKey}_${hotelId}`
> 예: `KR_SEOUL_THIS_WEEKEND_12345`

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| dealId | string | 문서 ID (형식: `${regionKey}_${windowKey}_${hotelId}`) |
| hotelId | string | 호텔 ID |
| regionKey | string | 지역 코드 |
| windowKey | string | 체크인 시점 (TODAY \| TOMORROW \| THIS_WEEKEND \| NEXT_WEEKEND) |
| name | string | 호텔명 (영문명 포함 가능, 예: "캡슐 호텔 마중 (Capsule Hotel Majung)") |
| imageUrl | string | 대표 이미지 URL (전체 URL, hotel_static의 첫 번째 이미지 또는 크롤링한 이미지) |
| starRating | number | 호텔 성급 (hotel_static에서 가져온 값) |
| reviewScore | number | 리뷰 점수 (10점 만점, hotel_static의 _reviewScore 사용) |
| reviewCount | number | 리뷰 수 (hotel_static의 _reviewCount 사용) |
| price | number | 1박 가격 (원화, 세금 제외) |
| totalPrice | number | 총 금액 (세금 포함, price가 없으면 price 사용) |
| discountPct | number | 할인율 (%) |
| hasFreeCancellation | boolean | 무료 취소 가능 여부 |
| remainingRooms | number? | 남은 객실 수 (null 가능) |
| dealScore | number | 딜 점수 (정렬용, 소수점 가능) |
| bookingUrl | string | 예약 딥링크 (아고다 검색 URL) |
| checkInDate | string | 체크인 날짜 (YYYY-MM-DD 형식) |
| expiresAt | string | 캐시 만료 시각 (ISO 8601 형식, 예: "2026-01-07T19:14:56.839755Z") |

### :arrow_forward: 쿼리 예시
```javascript
// 오사카 이번 주말 특가 조회
db.collection("hotel_deal_cards")
  .where("regionKey", "==", "JP_OSAKA")
  .where("windowKey", "==", "THIS_WEEKEND")
  .orderBy("dealScore", "desc")
  .limit(12);
```

### :arrow_forward: 예시 문서
```json
{
  "dealId": "KR_SEOUL_TODAY_4261773",
  "hotelId": "4261773",
  "regionKey": "KR_SEOUL",
  "windowKey": "TODAY",
  "name": "캡슐 호텔 마중 (Capsule Hotel Majung)",
  "imageUrl": "https://pix8.agoda.net/hotelImages/4261773/-1/12cb57a5a0d98dfc8216ba7a0ab5fd78.jpg?ca=9&ce=1&s=1024x",
  "starRating": 1.5,
  "reviewScore": 7.3,
  "reviewCount": 360,
  "price": 46147,
  "totalPrice": 55837,
  "discountPct": 36,
  "hasFreeCancellation": true,
  "remainingRooms": null,
  "dealScore": 160.0,
  "bookingUrl": "https://www.agoda.com/ko-kr/search?cid=1881766&city=14690&selectedproperty=4261773&adults=2&Rooms=1&Checkin=2026-01-08&Checkout=2026-01-09&los=1&currencyCode=KRW",
  "checkInDate": "2026-01-08",
  "expiresAt": "2026-01-07T19:14:56.839755Z"
}
```

---

## :file_folder: users/{uid}/saved_hotels/{hotelId}

**유저 즐겨찾기 호텔**

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| hotelId | string | 호텔 ID |
| name | string | 호텔명 |
| imageUrl | string | 대표 이미지 URL |
| savedAt | timestamp | 저장 시각 |

### :arrow_forward: 예시 문서
```json
{
  "hotelId": "4261773",
  "name": "로뎀하우스 논현",
  "imageUrl": "//pix8.agoda.net/hotelImages/4261773/0/c5aee7ebfbed991264cf836be6d97aee.jpeg?s=375x",
  "savedAt": "2026-01-07T10:30:00Z"
}
```

---

## :file_folder: users/{uid}/hotel_history/{hotelId}

**최근 본 호텔** (간소화)

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| hotelId | string | 호텔 ID |
| name | string | 호텔명 |
| imageUrl | string | 대표 이미지 URL |
| viewedAt | timestamp | 조회 시각 |

> **정책**: 최대 20개까지 보관, 14일 후 자동 삭제

---

## :file_folder: hotel_regions/{regionKey}

**지역 메타 정보**

### :arrow_forward: 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| regionKey | string | 지역 코드 |
| name | string | 지역명 (한글) |
| countryCode | string | 국가 코드 |
| isLocal | boolean | 국내 여부 |
| sortOrder | number | 표시 순서 |
| isActive | boolean | 활성화 여부 |

### :arrow_forward: 예시 문서
```json
{
  "regionKey": "JP_OSAKA",
  "name": "오사카",
  "countryCode": "JP",
  "isLocal": false,
  "sortOrder": 10,
  "isActive": true
}
```

---

## :arrows_counterclockwise: 갱신 전략 (TTL 기반)

| windowKey | 갱신 주기 (TTL_HOURS) | expiresAt 설정 |
|-----------|---------------------|----------------|
| TODAY | 1시간 | now + 1시간 |
| TOMORROW | 2시간 | now + 2시간 |
| THIS_WEEKEND | 6시간 | now + 6시간 |
| NEXT_WEEKEND | 12시간 | now + 12시간 |

> **참고**: `hotel_Deal_cards.py`의 `TTL_HOURS` 딕셔너리에서 정의됨

### 갱신 로직
1. Cloud Scheduler로 주기적 실행
2. `expiresAt < now`인 카드 조회
3. 아고다 크롤링으로 가격 갱신
4. `expiresAt` 업데이트

---

## :iphone: 인덱스 설계

### hotel_deal_cards
```
1. regionKey ASC, windowKey ASC, dealScore DESC
2. windowKey ASC, dealScore DESC
```

### hotel_static/{hotelId}/price_history (CollectionGroup)
```
1. hotelId ASC, checkInDate DESC, recordedAt DESC
2. hotelId ASC, windowKey ASC, checkInDate ASC, recordedAt ASC
3. hotelId ASC, checkInDate ASC, recordedAt ASC
```

---

## :dart: dealScore 산식

```python
def calculate_deal_score(price_data: dict) -> float:
    score = 0.0
    
    # 리뷰 점수
    review_score = price_data.get("reviewScore")
    if review_score:
        score += review_score * 10
    
    # 할인율 보너스
    discount_pct = price_data.get("discountPct", 0)
    score += discount_pct * 2
    
    # 무료 취소 보너스
    if price_data.get("hasFreeCancellation"):
        score += 10
    
    # 희소성 보너스
    remaining = price_data.get("remainingRooms")
    if remaining and remaining <= 4:
        score += 5
    
    return round(score, 1)
```

**계산 공식**:
- `reviewScore * 10` (기본 점수)
- `+ discountPct * 2` (할인율 보너스)
- `+ 10` (무료 취소 보너스, hasFreeCancellation이 True일 때)
- `+ 5` (희소성 보너스, remainingRooms가 4 이하일 때)
- 최종 결과는 소수점 첫째 자리까지 반올림

---

## :bar_chart: 컬렉션 구조 요약

| 컬렉션 | 용도 | 문서 ID | 필드 수 |
|--------|------|---------|--------|
| hotel_static | 호텔 정적 정보 | hotelId | 14개 (내부 필드 포함) |
| hotel_static/{hotelId}/price_history | 가격 이력 | priceHistoryId | 10개 |
| hotel_deal_cards | 딜 카드 (가격) | dealId | 17개 |
| hotel_requests | 사용자 요청 | requestId | 9개 |
| saved_hotels | 즐겨찾기 | hotelId | 4개 |
| hotel_history | 최근 본 호텔 | hotelId | 4개 |
| hotel_regions | 지역 메타 | regionKey | 6개 |

---

## :end: 요약

- :white_check_mark: 호텔 특가 피드 (오늘/내일/이번주말/다음주말)
- :white_check_mark: 지역별 필터링
- :white_check_mark: 딜 카드 (이미지, 가격, 리뷰, 할인율)
- :white_check_mark: 가격 이력 추적 (price_history)
- :white_check_mark: 아고다 단독 예약
- :white_check_mark: 즐겨찾기
- :white_check_mark: 최근 본 호텔
- :white_check_mark: 사용자 호텔 추가 요청
- :white_check_mark: 비용 효율적인 필드 구성

---

## :spider: 크롤링 전략

### 파일 구조
```
hotel_static.py     # 정적 호텔 정보 크롤링 (월 1회)
hotel_deal_cards.py # 딜 카드 가격 크롤링 (매일)
```

### 크롤링 설정 (CONFIG)

**hotel_static.py**:
- `local_url`: 국내 특가 페이지 URL
- `abroad_url`: 해외 특가 페이지 URL
- `headless`: True (브라우저 숨김)
- `timeout`: 60000ms (페이지 로드 타임아웃)
- `delay_between_requests`: 1.0초 (요청 간 딜레이)
- `cid`: "1881766" (어필리에이트 ID)

**hotel_Deal_cards.py**:
- `headless`: True (브라우저 숨김)
- `timeout`: 60000ms (페이지 로드 타임아웃)
- `delay_between_requests`: 1.5초 (요청 간 딜레이)
- `cid`: "1881766" (어필리에이트 ID)

### hotel_static.py 흐름

```
1. 소스 수집
   ├── 특가 페이지 크롤링
   │   └── 국내: https://www.agoda.com/ko-kr/c/GoLocalKR?ds=...
   │   └── 해외: https://www.agoda.com/ko-kr/c/overseasdeal?ds=...
   │   └── JavaScript 변수(window.campaignLandingPageParams)에서 호텔 목록 추출
   │   └── cityId, propertyIds, cityName 추출
   └── 사용자 요청 (hotel_requests에서 status="pending" 조회) - TODO

2. 각 호텔 상세 정보 크롤링
   └── 검색 결과 페이지 URL 생성: 
       https://www.agoda.com/ko-kr/search?cid={cid}&city={cityId}&selectedproperty={hotelId}&...
   └── 페이지에서 정보 크롤링:
       - 호텔명 (h1 또는 data-selenium="hotel-header-name")
       - 별점 (ScreenReaderOnly에서 "X성급" 텍스트 추출)
       - 리뷰 점수/개수 (data-element-name="property-card-review")
       - 지역명 (data-selenium="area-city-text")
       - 이미지 URL 10개 (data-selenium="gallery-image" 또는 img[src*="hotelImages"])
       - amenityTags (검색 결과 페이지에는 없음, 빈 배열)

3. hotel_static 저장
   └── _reviewScore, _reviewCount 필드 포함 (hotel_deal_cards에서 사용)
   └── source 필드로 출처 구분 ("SPECIAL_DEAL")
   └── updatedAt은 ISO 8601 형식 문자열
```

### hotel_deal_cards.py 흐름

```
1. hotel_static 데이터 로드
   └── hotel_static_test.json 파일에서 읽기 (또는 Firestore에서 조회)
   └── hotelId, cityId, regionKey, starRating, _reviewScore, _reviewCount 사용

2. 각 windowKey별 가격 크롤링
   └── get_window_dates()로 날짜 계산:
       - TODAY: 오늘 ~ 내일
       - TOMORROW: 내일 ~ 모레
       - THIS_WEEKEND: 이번 주 토요일 ~ 일요일
       - NEXT_WEEKEND: 다음 주 토요일 ~ 일요일
   └── 검색 결과 페이지에서 가격 정보 추출:
       - 가격 (data-selenium="display-price")
       - 총 가격 (data-selenium="total-price-per-night")
       - 할인율 (data-element-name="discount-percent")
       - 남은 객실 수 (객실 X개 남음 패턴)
       - 무료 취소 여부 (텍스트 패턴)
       - 객실 판매 완료 체크

3. hotel_deal_cards 저장
   └── dealId 생성: ${regionKey}_${windowKey}_${hotelId}
   └── dealScore 계산 (calculate_deal_score 함수)
   └── expiresAt 설정 (TTL_HOURS 기반)
   └── bookingUrl 생성 (아고다 검색 URL)
   └── 객실 판매 완료(isSoldOut)이거나 가격이 없으면 저장하지 않음

4. price_history 저장 (hotel_deal_cards 저장과 동시에)
   └── priceHistoryId 생성: ${hotelId}_${checkInDate}_${windowKey}
   └── hotel_static/{hotelId}/price_history/{priceHistoryId}에 저장
   └── 같은 priceHistoryId가 이미 존재하면 최신 값으로 덮어쓰기
   └── recordedAt 필드에 현재 시각 기록
   └── 가격 정보만 저장 (price, totalPrice, discountPct, hasFreeCancellation, remainingRooms)
```

### 사용자 요청 처리

```
1. 앱에서 URL 붙여넣기 → hotel_requests에 저장

2. hotel_static.py 실행 시 함께 처리 (TODO: 아직 구현되지 않음)
   └── hotelId 있음 → 바로 크롤링
   └── hotelId 없음 → 슬러그 페이지 접근 후 ID 추출

3. 처리 완료 시 status="completed" 업데이트
```

### 데이터 형식 참고사항

- **날짜 형식**: 모든 날짜는 ISO 8601 형식 (YYYY-MM-DD 또는 YYYY-MM-DDTHH:mm:ss.sssZ)
- **이미지 URL**: 전체 URL 형식 (https://로 시작)
- **가격**: 원화 단위, 정수형
- **별점**: 소수점 가능 (예: 1.5, 2, 3, 4)
- **내부 필드**: `_reviewScore`, `_reviewCount`는 hotel_static에만 저장되고, hotel_deal_cards에서 참조됨