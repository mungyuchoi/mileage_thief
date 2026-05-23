# 포인트 숙박 Firestore 설계

최종 업데이트: 2026-05-24

이 문서는 포인트 숙박 화면의 `호텔` 탭과 `탐색` 탭을 더미 데이터에서 Firestore 기반 데이터로 전환하기 위한 설계다.

현재 앱은 `PointHotel` 더미 모델을 기준으로 호텔 목록, 호텔 상세, 브랜드별 후보, 탐색 후보를 보여준다. Firestore 전환 후에도 화면의 역할은 단순하다.

- 앱은 Firestore에 있는 포인트 숙박 데이터를 읽기만 한다.
- 호텔/브랜드/포인트/현금가/추천 후보 데이터는 서버 배치 또는 crontab 작업이 주기적으로 갱신한다.
- 사용자가 호텔 탭이나 탐색 탭에서 입력하는 검색어, 날짜, 숙박 수는 조회 조건일 뿐이며, 이 설계에서는 Firestore에 저장하지 않는다.

## 1. 설계 원칙

### 읽기 모델과 갱신 모델을 분리한다

호텔 탭과 탐색 탭은 빠르게 보여줘야 하므로 클라이언트에서 여러 컬렉션을 join하지 않는다. 서버 배치가 화면에 필요한 형태로 데이터를 미리 정리해 둔다.

- `pointHotels`: 호텔 기본 정보와 현재 대표 포인트/현금가. 호텔명, 이미지, 위치 같은 저빈도 메타데이터는 월 1회 수준으로 갱신한다.
- `pointHotels/{hotelId}/calendarYears`: 앱이 읽는 최신 날짜별 포인트/현금가. 날짜당 1문서가 아니라 1년 단위 map 문서로 저장한다.
- `pointHotels/{hotelId}/calendarYearRuns`: 크론 실행별 날짜별 포인트/현금가 변경 이력. 하루 2회 이상 수집한 흔적을 남기되, 실행마다 1년 전체를 중복 저장하지 않는다.
- `pointAwardIndexes`: 탐색 탭에서 바로 보여줄 denormalized 후보 묶음. 브랜드/박수/정렬 조합당 1문서로 저장한다.
- `pointHotelPrograms`: 등록된 호텔 프로그램/브랜드 목록
- `pointHotelSyncRuns`: 크론 실행 로그

### 클라이언트 쓰기는 금지한다

포인트 숙박 데이터는 운영 데이터다. 일반 클라이언트는 읽기만 하고, 쓰기는 Admin SDK를 쓰는 서버 작업만 수행한다.

저장 호텔, 알림, 목표 조건 같은 사용자 데이터는 별도 기능에서 `users/{uid}/...` 하위 컬렉션으로 확장한다. 이 문서의 범위는 `호텔`과 `탐색` 탭에 필요한 공개 조회 데이터다.

### 날짜별 포인트는 연 단위 map 문서로 묶는다

메리어트처럼 날짜별 포인트 캘린더를 자주 가져오는 데이터는 날짜마다 Firestore 문서를 만들지 않는다. 날짜별 문서 구조는 단순하지만, 호텔 1개를 하루 2회만 갱신해도 365일 기준 하루 730 write가 발생한다.

v1 기준 권장 구조는 아래 두 계층이다.

- 최신 조회용: `pointHotels/{hotelId}/calendarYears/{yearKey}`. 예: `2026`
- 이력 보관용: `pointHotels/{hotelId}/calendarYearRuns/{yearKey}_{runSlot}`. 예: `2026_20260522T0600Z`

이렇게 하면 1년치를 가져와도 최신값 갱신은 호텔당 연도 문서 1개 write로 끝난다. 포인트와 현금가를 같은 실행에서 같이 수집하면 같은 연도 문서의 `days` map에 합쳐 저장한다.

외부 공급자가 한 번에 1년치를 주지 않아도 저장 규격은 동일하다. 예를 들어 메리어트 요청을 30~60일 단위로 여러 번 나누어 수집하더라도 writer는 결과를 같은 `calendarYears/{yearKey}.days` map에 merge한다.

이력은 기본적으로 전체 365일을 매번 복제하지 않고, 이전 최신값과 비교해서 바뀐 날짜만 `changedDays`에 남긴다. 특정 실행의 원본 전체 응답이 필요하면 Firestore가 아니라 Cloud Storage 또는 BigQuery에 보관하고, Firestore에는 `rawHash`와 저장 경로만 둔다.

### 탐색 탭은 집계 인덱스 문서를 따로 둔다

탐색 탭은 `브랜드`, `숙박 수`, `가치순`, `낮은 포인트`, `최근 확인` 기준으로 정렬한다. 이를 `pointHotels`와 하위 캘린더를 매번 조합해 계산하면 Firestore 쿼리가 복잡해진다.

따라서 crontab 작업이 `pointAwardIndexes`를 미리 만들어 둔다. 클라이언트는 브랜드/박수/정렬 조합에 맞는 문서 1개만 읽어서 탐색 탭을 구성한다. 개별 후보를 문서마다 나누는 `pointAwardCandidates` 방식은 read 수가 커지므로 v1 운영 경로에서는 사용하지 않는다.

## 2. 화면별 읽기 흐름

| 화면 | Firestore 기준 | 비고 |
| --- | --- | --- |
| 호텔 탭 기본 목록 | `pointHotels` | `status == active`, `sortScore desc` |
| 호텔 탭 검색 | `pointHotels.searchTokens` | Firestore 검색 한계를 고려해 토큰 검색 후 클라이언트 보정 |
| 호텔 탭 날짜/숙박 수 검색 | `calendarYears` 또는 `pointAwardIndexes` | 날짜가 있으면 상세 캘린더 기준으로 확장 |
| 호텔 상세 | `pointHotels/{hotelId}` + `calendarYears` | 호텔 정보와 1년치 캘린더 표시 |
| 탐색 탭 전체 | `pointAwardIndexes/all_n{nights}_{sort}` | 1 document read |
| 탐색 탭 브랜드 필터 | `pointAwardIndexes/{programId}_n{nights}_{sort}` | 등록 브랜드는 `pointHotelPrograms` 기준 |
| 브랜드별 포인트 숙박 섹션 | `pointHotels.programId` 또는 `pointAwardIndexes` | 현재 브랜드 탭도 같은 `programId`를 재사용 가능 |

## 3. 컬렉션 맵

| 경로 | 역할 | 클라이언트 읽기 | 클라이언트 쓰기 | 서버 쓰기 |
| --- | --- | --- | --- | --- |
| `pointHotelPrograms/{programId}` | 호텔 프로그램/브랜드 메타 | 허용 | 금지 | 허용 |
| `pointHotels/{hotelId}` | 호텔 기본 정보와 대표 가격 | 허용 | 금지 | 허용 |
| `pointHotels/{hotelId}/calendarYears/{yearKey}` | 앱이 읽는 최신 연별 포인트/현금가 map | 허용 | 금지 | 허용 |
| `pointHotels/{hotelId}/calendarYearRuns/{yearKey_runSlot}` | 수집 실행별 연별 변경 이력 | 관리자만 | 금지 | 허용 |
| `pointAwardIndexes/{indexId}` | 탐색 탭 후보 묶음 | 허용 | 금지 | 허용 |
| `pointHotelSyncRuns/{runId}` | 크론 실행 로그 | 관리자만 | 금지 | 허용 |

## 4. 문서 스키마

### `pointHotelPrograms/{programId}`

등록된 호텔 프로그램과 화면 표시 정보를 담는다. 탐색 탭의 브랜드 목록은 하드코딩 대신 이 컬렉션을 읽는 구조로 확장할 수 있다.

문서 ID 예시:

- `marriott`
- `accor`
- `hilton`
- `ihg`
- `hyatt`

예시:

```json
{
  "programId": "marriott",
  "label": "메리어트",
  "programName": "Marriott Bonvoy",
  "brandKeywords": ["marriott", "westin", "sheraton", "ritz", "st. regis"],
  "displayOrder": 10,
  "isActive": true,
  "updatedAt": "serverTimestamp"
}
```

필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `programId` | string | 문서 ID와 동일 |
| `label` | string | 앱 표시명 |
| `programName` | string | 공식 프로그램명 |
| `brandKeywords` | string[] | 호텔 브랜드 매칭용 키워드 |
| `displayOrder` | number | 브랜드 노출 순서 |
| `isActive` | boolean | 화면 노출 여부 |
| `updatedAt` | timestamp | 마지막 수정 시각 |

### `pointHotels/{hotelId}`

호텔 탭 기본 목록과 호텔 상세의 기준 문서다. 현재 `PointHotel` 더미 모델의 필드를 대부분 이 문서에 매핑한다.

문서 ID는 외부 공급자 코드가 안정적이면 `program_propertyCode`를 쓰고, 없으면 `program_slugCity_slugName` 형태를 쓴다.

예시:

```json
{
  "hotelId": "marriott_lhrwm",
  "programId": "marriott",
  "propertyCode": "LHRWM",
  "name": "The Westin London City",
  "city": "London",
  "country": "United Kingdom",
  "address": "60 Upper Thames Street, London EC4V 3AD, United Kingdom",
  "geo": {
    "lat": 51.5123,
    "lng": -0.0954
  },
  "brand": "Marriott",
  "imageUrl": "https://example.com/hotel.jpg",
  "galleryUrls": ["https://example.com/hotel.jpg"],
  "rating": 4.6,
  "guestFavorite": true,
  "description": "런던 성수기 현금가가 높을 때 포인트 가치가 돋보이는 호텔입니다.",
  "amenities": ["스파", "수영장", "라운지", "강변 위치"],
  "amenityKeys": ["spa", "pool", "lounge", "river"],
  "searchTokens": [
    "westin",
    "london",
    "city",
    "marriott",
    "united",
    "kingdom"
  ],
  "currentAward": {
    "dateKey": "2026-06-15",
    "available": true,
    "pointsPerNight": 40000,
    "cashPerNightKrw": 612000,
    "krwPerPoint": 15.3,
    "checkedAt": "serverTimestamp",
    "sourceRunId": "run_20260521_060000"
  },
  "calendarPreview": [
    {
      "dateKey": "2026-06-15",
      "available": true,
      "pointsPerNight": 40000
    }
  ],
  "sortScore": 1530,
  "status": "active",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `hotelId` | string | 문서 ID와 동일 |
| `programId` | string | `pointHotelPrograms/{programId}` 참조 키 |
| `propertyCode` | string? | 공식/외부 공급자 호텔 코드 |
| `name` | string | 호텔명 |
| `city` | string | 도시 |
| `country` | string | 국가 |
| `address` | string | 주소 |
| `geo` | map | 지도 노출용 좌표. Firestore `GeoPoint`로 바꿔도 됨 |
| `brand` | string | 화면에 표시할 브랜드명 |
| `imageUrl` | string | 대표 이미지 |
| `galleryUrls` | string[] | 상세 이미지 |
| `rating` | number | 표시용 평점 |
| `guestFavorite` | boolean | 추천/선호 배지 |
| `description` | string | 호텔 소개 |
| `amenities` | string[] | 표시용 편의시설 |
| `amenityKeys` | string[] | 필터용 편의시설 키 |
| `searchTokens` | string[] | 호텔명/도시/국가/주소/브랜드 검색 토큰 |
| `currentAward` | map | 대표 포인트/현금가 스냅샷 |
| `calendarPreview` | map[] | 목록/상세 상단에서 빠르게 쓸 7~14일 미리보기 |
| `sortScore` | number | 기본 목록 정렬 점수 |
| `status` | string | `active`, `inactive`, `hidden` |
| `createdAt` | timestamp | 최초 생성 시각 |
| `updatedAt` | timestamp | 마지막 갱신 시각 |

### `pointHotels/{hotelId}/calendarYears/{yearKey}`

호텔 상세의 최신 포인트 캘린더 원천 데이터다. 날짜별 문서를 만들지 않고 1년치 날짜를 `days` map 하나에 넣는다.

문서 ID는 `yyyy`를 사용한다. 예: `2026`

포인트/현금가를 같이 보여줘야 하므로 `days`의 각 날짜 entry 안에 포인트와 현금가를 함께 둔다. 내부 날짜 entry는 문서 크기와 네트워크 전송량을 줄이기 위해 짧은 키를 쓴다.

날짜 key는 `dMMdd`를 쓴다. 예: `2026-05-22`는 `d0522`, `2026-12-31`은 `d1231`이다. 이 방식은 dot-path 업데이트에도 안전하고, `yyyy-MM-dd`를 반복 저장하지 않아 문서가 작다.

예시:

```json
{
  "hotelId": "marriott_selmm",
  "programId": "marriott",
  "propertyCode": "SELMM",
  "yearKey": "2026",
  "occupancyKey": "r1_a2",
  "nights": 1,
  "currency": "KRW",
  "days": {
    "d0522": {
      "a": true,
      "p": 61000,
      "c": 636500,
      "v": 10.43,
      "src": "marriott_adf",
      "rid": "run_20260522_060000",
      "at": "serverTimestamp"
    },
    "d0523": {
      "a": false,
      "p": null,
      "c": null,
      "src": "marriott_adf",
      "rid": "run_20260522_060000",
      "at": "serverTimestamp"
    }
  },
  "availableCount": 182,
  "minPoints": 56000,
  "maxPoints": 88000,
  "minCashKrw": 484500,
  "maxCashKrw": 920000,
  "firstDate": "2026-01-01",
  "lastDate": "2026-12-31",
  "latestRunId": "run_20260522_060000",
  "lastCheckedAt": "serverTimestamp",
  "lastChangedAt": "serverTimestamp",
  "updatedAt": "serverTimestamp",
  "stale": false
}
```

연 문서 필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `hotelId` | string | 상위 호텔 ID |
| `programId` | string | 프로그램 필터 키 |
| `propertyCode` | string? | 공식/외부 공급자 호텔 코드 |
| `yearKey` | string | `yyyy` |
| `occupancyKey` | string | 객실/인원 조건. 기본은 `r1_a2` |
| `nights` | number | 캘린더 원천 숙박 수. 기본은 1 |
| `currency` | string | 현금가 통화. v1은 `KRW` |
| `days` | map | 날짜별 최신 값. key는 `dMMdd` |
| `availableCount` | number | 해당 연도 예약 가능 날짜 수 |
| `minPoints` | number? | 해당 연도 최저 포인트 |
| `maxPoints` | number? | 해당 연도 최고 포인트 |
| `minCashKrw` | number? | 해당 연도 최저 현금가 |
| `maxCashKrw` | number? | 해당 연도 최고 현금가 |
| `firstDate` | string | 연 문서의 첫 날짜 |
| `lastDate` | string | 연 문서의 마지막 날짜 |
| `latestRunId` | string | 마지막으로 반영된 수집 실행 ID |
| `lastCheckedAt` | timestamp | 마지막으로 성공적으로 확인한 시각. 값 변화가 없어도 갱신 |
| `lastChangedAt` | timestamp? | 날짜별 포인트/현금가 값이 실제로 바뀐 마지막 시각 |
| `updatedAt` | timestamp | 문서 write 시각. 보통 `lastCheckedAt`과 동일 |
| `stale` | boolean | 최신 수집에서 확인되지 않은 연도인지 여부 |

`days.{dMMdd}` entry 필드:

| 짧은 키 | 타입 | 의미 | 앱 표시명 |
| --- | --- | --- | --- |
| `a` | boolean | 예약 가능 여부 | `available` |
| `p` | number? | 1박 포인트 | `pointsPerNight` |
| `c` | number? | 1박 현금가 KRW | `cashPerNightKrw` |
| `v` | number? | 원/포인트 가치. `c / p` | `krwPerPoint` |
| `src` | string | 수집 출처 | `sourceProvider` |
| `rid` | string | 수집 실행 ID | `runId` |
| `at` | timestamp | 수집 확인 시각 | `checkedAt` |

Firestore는 문서 전체를 write 단위로 계산하므로, 이 구조는 365일 범위 수집 시 날짜별 365 write 대신 연도별 1 write로 끝난다. 앱은 호텔 상세 진입 시 현재 연도와 다음 연도 문서만 읽으면 1년치 캘린더를 만들 수 있다.

문서 크기 안전선:

- Firestore 문서 최대 크기는 1MiB다.
- 365일치 포인트/현금가 entry만 담는 연 문서는 보통 수십 KB 수준이라 안전하다.
- 객실 수, 인원, 숙박 수 조합이 여러 개로 늘어나면 같은 문서에 모두 넣지 않고 `calendarYears/{yearKey}_{occupancyKey}_n{nights}`처럼 문서를 분리한다.
- `days` map은 클라이언트에서 날짜별 조회만 하고 Firestore 조건 검색에 쓰지 않는다. 가능하면 Firestore single-field index exemption에서 `days` 하위 필드를 인덱싱 제외한다.
- 원본 HTML, 전체 응답 JSON, 긴 에러 본문은 이 문서에 넣지 않고 `rawHash`, `sourceUrl`, 별도 파일 경로만 남긴다.

### `pointHotels/{hotelId}/calendarYearRuns/{yearKey_runSlot}`

하루 2회 이상 수집한 이력을 남기기 위한 실행별 변경 로그다. 앱의 일반 화면은 이 컬렉션을 읽지 않고, 운영 대시보드나 가격 변동 분석에서만 사용한다.

문서 ID는 `{yearKey}_{runSlot}`을 사용한다. 예: `2026_20260522T0600Z`

기본은 전체 365일 스냅샷이 아니라, 이전 최신값 대비 변경된 날짜만 `changedDays`에 저장한다. 값이 바뀌지 않은 실행도 `observedCount`, `changedCount`, `rawHash`를 남기면 “그 시간에 확인했다”는 이력은 유지된다.

예시:

```json
{
  "hotelId": "marriott_selmm",
  "programId": "marriott",
  "propertyCode": "SELMM",
  "yearKey": "2026",
  "runSlot": "20260522T0600Z",
  "runId": "run_20260522_060000",
  "sourceProvider": "marriott_adf",
  "occupancyKey": "r1_a2",
  "nights": 1,
  "currency": "KRW",
  "rangeStart": "2026-05-22",
  "rangeEnd": "2027-05-21",
  "observedCount": 365,
  "changedCount": 2,
  "changedDays": {
    "d0522": {
      "old": {
        "a": true,
        "p": 66000,
        "c": 636500
      },
      "new": {
        "a": true,
        "p": 61000,
        "c": 636500,
        "v": 10.43
      }
    },
    "d0523": {
      "old": {
        "a": true,
        "p": 61000,
        "c": 620000
      },
      "new": {
        "a": false,
        "p": null,
        "c": null
      }
    }
  },
  "rawHash": "sha256:...",
  "rawStoragePath": "gs://bucket/marriott/SELMM/20260522T0600Z.json",
  "createdAt": "serverTimestamp"
}
```

이력 저장 정책:

- 앱 조회에 필요한 최신값은 `calendarYears`에만 둔다.
- 실행 이력은 `calendarYearRuns`에 `changedDays` 중심으로 남긴다.
- 변동 분석에서 모든 관측값이 필요하면 원본 전체 응답을 Cloud Storage 또는 BigQuery에 저장하고 Firestore에는 참조만 남긴다.
- Firestore에 full snapshot을 매번 넣는 방식은 write 수는 적지만 storage가 빠르게 늘어나므로 기본값으로 쓰지 않는다.

최신값과 이력의 의미:

- `calendarYears/{yearKey}`는 최신 상태만 가진다. 다음 실행에서 같은 날짜를 다시 확인하면 해당 날짜 entry는 새 값으로 merge되거나 덮어써진다.
- `calendarYearRuns/{yearKey}_{runSlot}`는 그 실행에서 확인한 흔적을 남긴다. 기본은 바뀐 날짜만 `changedDays`에 기록한다.
- 값이 하나도 바뀌지 않은 실행은 `calendarYears.lastCheckedAt`, `latestRunId`, `updatedAt`만 갱신하고 `lastChangedAt`은 유지한다.
- 날짜별 포인트나 현금가가 바뀐 실행은 해당 날짜 entry를 갱신하고 `lastCheckedAt`, `lastChangedAt`, `latestRunId`, `updatedAt`을 모두 갱신한다.
- 특정 실행 시점의 1년치 전체 원본을 나중에 그대로 재현해야 하면, Firestore 변경 로그만으로는 부족할 수 있으므로 원본 전체 payload를 Cloud Storage 또는 BigQuery에 같이 저장한다.

### 날짜별 포인트 업로드 payload 규격

수집기는 Marriott ADF 응답처럼 날짜별 값이 배열로 오더라도 Firestore writer에 넘길 때는 연도별 map payload로 정규화한다. 이 payload는 writer가 `calendarYears`와 `calendarYearRuns`로 나누어 쓰기 위한 내부 표준 포맷이다.

예시:

```json
{
  "runId": "run_20260522_060000",
  "runSlot": "20260522T0600Z",
  "sourceProvider": "marriott_adf",
  "hotelId": "marriott_selmm",
  "programId": "marriott",
  "propertyCode": "SELMM",
  "occupancyKey": "r1_a2",
  "nights": 1,
  "currency": "KRW",
  "rangeStart": "2026-05-22",
  "rangeEnd": "2027-05-21",
  "years": {
    "2026": {
      "d0522": {
        "a": true,
        "p": 61000,
        "c": 636500
      },
      "d0523": {
        "a": true,
        "p": 61000,
        "c": 620000
      }
    },
    "2027": {
      "d0101": {
        "a": true,
        "p": 56000,
        "c": 484500
      }
    }
  }
}
```

writer 처리 규칙:

1. `years`의 각 `yearKey`마다 `pointHotels/{hotelId}/calendarYears/{yearKey}`를 `set(..., merge: true)`로 갱신한다.
2. 같은 payload에서 포인트와 현금가를 모두 알고 있으면 같은 `days.{dMMdd}` entry에 같이 넣는다.
3. 포인트만 먼저 수집했고 현금가가 나중에 들어오면 기존 `days.{dMMdd}.p`를 유지하고 `days.{dMMdd}.c`, `days.{dMMdd}.v`만 merge한다.
4. 수집 실행 이력은 이전 `calendarYears/{yearKey}`와 비교해 바뀐 날짜만 `calendarYearRuns/{yearKey}_{runSlot}.changedDays`에 저장한다.
5. `pointHotels.currentAward`와 `calendarPreview`는 `calendarYears`에서 계산한 대표 값만 복사한다.
6. `pointAwardIndexes`는 `calendarYears`를 기준으로 다시 계산한 파생 인덱스다. 탐색 탭 조건별 후보를 문서 1개 안의 `items` 배열로 묶어 저장한다.

실제 writer는 전체 `days` map을 매번 덮어써도 write 수는 1회지만, 네트워크 전송량을 줄이려면 바뀐 날짜만 dot-path로 업데이트한다.

```text
days.d0522 = { a: true, p: 61000, c: 636500, v: 10.43, ... }
days.d0523 = { a: false, p: null, c: null, ... }
latestRunId = run_20260522_060000
updatedAt = serverTimestamp
```

쓰기 수 예시:

| 구조 | 1년 범위, 호텔 1개, 실행 1회 | 하루 2회 |
| --- | ---: | ---: |
| 날짜별 문서 `{dateKey}` | 약 365 writes | 약 730 writes |
| 연별 최신 문서 `calendarYears/{yearKey}` | 1 write | 2 writes |
| 연별 최신 + 변경 이력 | 2 writes | 4 writes |

따라서 v1은 날짜별 최신 데이터는 연 단위 map 문서로 저장하고, 이력은 실행별 변경분만 Firestore에 남긴다.

### `pointAwardIndexes/{indexId}`

탐색 탭 전용 집계 문서다. 호텔 기본 정보를 denormalize한 후보들을 `items` 배열에 담아 클라이언트가 후보 문서 수십~수백 개를 읽지 않아도 카드 UI를 만들 수 있게 한다.

문서 ID는 `{scope}_n{nights}_{sort}`를 기본으로 한다.

예:

- `all_n1_value`
- `marriott_n1_value`
- `marriott_n3_points`
- `marriott_n1_recent`

예시:

```json
{
  "indexId": "marriott_n1_value",
  "scope": "marriott",
  "programId": "marriott",
  "nights": 1,
  "sort": "value",
  "count": 3,
  "itemsPerIndex": 50,
  "items": [
    {
      "candidateId": "marriott_lhrwm_2026-06-15_1",
      "hotelId": "marriott_lhrwm",
      "programId": "marriott",
      "brand": "Marriott",
      "name": "The Westin London City",
      "city": "London",
      "country": "United Kingdom",
      "address": "60 Upper Thames Street, London EC4V 3AD, United Kingdom",
      "imageUrl": "https://example.com/hotel.jpg",
      "rating": 4.6,
      "guestFavorite": true,
      "checkInDate": "2026-06-15",
      "checkOutDate": "2026-06-16",
      "nights": 1,
      "pointsTotal": 32000,
      "cashTotalKrw": 612000,
      "krwPerPoint": 19.1,
      "valueScore": 1910,
      "confidence": 0.92
    }
  ],
  "updatedAt": "serverTimestamp",
  "sourceRunId": "run_20260521_060000",
  "status": "active"
}
```

필드:

| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `indexId` | string | 문서 ID와 동일 |
| `scope` | string | `all` 또는 `marriott`, `hyatt` 같은 프로그램 ID |
| `programId` | string? | 브랜드 인덱스일 때 프로그램 ID. `all`은 null |
| `nights` | number | 숙박 수 |
| `sort` | string | `value`, `points`, `recent` |
| `count` | number | `items` 개수 |
| `candidateObserved` | number | 원천 후보 수 |
| `itemsPerIndex` | number | 문서에 담을 최대 후보 수 |
| `items` | map[] | 카드 표시용 후보 배열 |
| `updatedAt` | timestamp | 인덱스 갱신 시각 |
| `sourceRunId` | string | 생성한 크론 실행 ID |
| `status` | string | `active`, `inactive`, `hidden` |

v1에서는 `nights` 1~7박, `sort` 3종, `scope` 전체/브랜드별 문서를 미리 만든다. 앱의 탐색 탭은 조건 변경마다 `pointAwardIndexes/{scope}_n{nights}_{sort}` 문서 1개만 읽는다.

### `pointHotelSyncRuns/{runId}`

크론 실행 로그다. 앱 화면에는 노출하지 않고 운영 확인과 장애 추적에 사용한다.

예시:

```json
{
  "runId": "run_20260521_060000",
  "trigger": "cron",
  "status": "success",
  "startedAt": "serverTimestamp",
  "finishedAt": "serverTimestamp",
  "programIds": ["marriott", "hilton", "ihg", "hyatt", "accor"],
  "hotelUpserted": 128,
  "calendarYearUpserted": 256,
  "calendarRunInserted": 256,
  "calendarDaysObserved": 46720,
  "calendarDaysChanged": 842,
  "candidateUpserted": 2310,
  "staleMarked": 52,
  "errors": []
}
```

실패 예시:

```json
{
  "runId": "run_20260521_120000",
  "trigger": "cron",
  "status": "failed",
  "startedAt": "serverTimestamp",
  "finishedAt": "serverTimestamp",
  "programIds": ["hilton"],
  "hotelUpserted": 0,
  "calendarYearUpserted": 0,
  "calendarRunInserted": 0,
  "calendarDaysObserved": 0,
  "calendarDaysChanged": 0,
  "candidateUpserted": 0,
  "staleMarked": 0,
  "errors": [
    {
      "programId": "hilton",
      "message": "provider timeout"
    }
  ]
}
```

## 5. 검색 토큰 정책

Firestore는 일반적인 contains/full-text 검색에 적합하지 않다. v1은 서버 배치가 `searchTokens`를 미리 만들어 두고, 앱은 토큰 기반으로 1차 후보를 가져온 뒤 클라이언트에서 재정렬한다.

토큰 생성 대상:

- 호텔명
- 도시
- 국가
- 주소 일부
- 브랜드명
- 프로그램명
- 공급자 호텔 코드

정규화 규칙:

- 소문자 변환
- 앞뒤 공백 제거
- 특수문자 제거 또는 공백 치환
- 한글/영문/숫자 토큰 보존
- 너무 짧은 1글자 영문 토큰은 제외
- 자주 쓰는 영문 prefix는 2~10글자까지 생성

예시:

```text
The Westin London City, Marriott
-> the, we, wes, west, westi, westin, london, city, marriott
```

데이터가 커져 검색 정확도와 속도가 중요해지면 Algolia, Typesense, Meilisearch 같은 별도 검색 인덱스를 붙인다. Firestore 단독으로 본문/부분 문자열 검색을 억지로 구현하지 않는다.

## 6. 쿼리 설계

### 호텔 탭 기본 목록

```text
pointHotels
where status == active
orderBy sortScore desc
limit 50
```

### 호텔 탭 검색

```text
pointHotels
where status == active
where searchTokens arrayContainsAny [queryTokens 최대 10개]
orderBy sortScore desc
limit 50
```

클라이언트는 가져온 결과를 다시 한 번 `name`, `city`, `country`, `address`, `brand` 기준으로 점수화해서 보여준다. 검색어가 비어 있으면 토큰 조건 없이 기본 목록을 보여준다.

### 날짜와 숙박 수가 있는 호텔 검색

```text
pointHotels 또는 pointHotels/{hotelId}/calendarYears/{yearKey}
```

날짜가 없으면 `pointHotels`를 기준으로 검색한다. 날짜가 있으면 후보 문서를 대량 조회하지 않고, 대상 호텔의 `calendarYears`를 읽은 뒤 클라이언트 또는 서버에서 해당 날짜/숙박 수 조건을 계산한다. 탐색 탭의 추천 목록은 `pointAwardIndexes`를 사용한다.

### 호텔 상세

```text
pointHotels/{hotelId}
```

```text
pointHotels/{hotelId}/calendarYears/{yearKey}
```

상세 화면의 1년치 캘린더는 `calendarYears/{yearKey}`에서 읽는다. 연말 근처에서 다음 해 날짜까지 필요하면 현재 연도와 다음 연도 문서 2개를 읽는다. 목록 화면에서 짧게 보여줄 데이터는 `pointHotels.calendarPreview`를 사용한다.

### 탐색 탭 전체

```text
pointAwardIndexes/all_n{selectedNights}_{selectedSort}
```

### 탐색 탭 브랜드 필터

```text
pointAwardIndexes/{selectedProgramId}_n{selectedNights}_{selectedSort}
```

정렬별 order:

| 정렬 | orderBy |
| --- | --- |
| 가치순 | `sort = value` |
| 낮은 포인트 | `sort = points` |
| 최근 확인 | `sort = recent` |

`전체` 브랜드는 `programId` 조건을 넣지 않는다.

## 7. 필요한 인덱스

Firestore 콘솔에서 생성 링크가 나오면 그대로 생성하되, v1 기준으로 아래 인덱스를 먼저 준비한다.

| 컬렉션 | 조건 | 정렬 |
| --- | --- | --- |
| `pointHotels` | `status == active` | `sortScore desc` |
| `pointHotels` | `status == active`, `programId == value` | `sortScore desc` |
| `pointHotels` | `status == active`, `searchTokens arrayContainsAny` | `sortScore desc` |
| `pointAwardIndexes` | 문서 ID 직접 조회 | 별도 복합 인덱스 불필요 |
`calendarYears.days`는 Firestore 쿼리 조건에 사용하지 않는다. 앱은 연도 문서 1~2개를 읽은 뒤 클라이언트에서 날짜 key를 꺼낸다. 따라서 `days` 하위 map은 single-field index exemption으로 인덱싱 제외하는 편이 좋다.

## 8. 크론 갱신 파이프라인

crontab 또는 Cloud Scheduler가 주기적으로 서버 작업을 실행한다. 현재 Functions 프로젝트는 Node 20과 Firebase Functions v2를 쓰고 있으므로, 구현 시에는 `firebase-functions/v2/scheduler`의 `onSchedule` 또는 외부 crontab이 호출하는 `onRequest` 함수를 사용할 수 있다.

호텔 메타데이터와 날짜별 가격/포인트 캘린더는 실행 주기가 다르므로 별도 작업으로 분리한다.

- 호텔 메타데이터: 월 1회 수준. Marriott은 `python3 task/point/hotel/marriott/update_marriott_hotels_from_firestore.py`를 실행한다. 이 작업은 Firestore `pointHotels`에서 `programId == marriott`, `status`가 `active` 또는 `pending`인 문서를 읽고, 각 문서의 `officialUrl`을 CDP Chrome 파서로 열어 호텔명, 주소, 좌표, 평점, 이미지, 편의시설 등을 다시 파싱한 뒤 `pointHotels/{hotelId}`에 upsert한다. 새 Marriott 호텔을 운영자가 추가할 때는 `pointHotels/{hotelId}`에 `programId`, `officialUrl`, `status: pending`만 먼저 넣어도 다음 호텔 메타데이터 배치에서 `active` 문서로 완성된다.
- 날짜별 포인트/현금가: 하루 2~3회 이상. Marriott은 `python3 task/point/marriott/update_marriott_calendar_from_firestore.py`를 실행한다. 등록된 호텔의 `propertyCode`를 기준으로 1년치 캘린더를 월 단위 window로 나누어 가져오고, 포인트와 현금가를 날짜별로 병합해 `calendarYears`와 `calendarYearRuns`에 저장한다.

권장 주기:

- 기본: 6시간마다
- 성수기/인기 호텔: 1~3시간마다 별도 우선순위 작업
- 실패 재시도: 15~30분 후 1회

실행 순서:

1. `pointHotelSyncRuns/{runId}`를 `status: running`으로 생성한다.
2. `pointHotelPrograms`에서 활성 프로그램 목록을 읽는다.
3. 프로그램별 외부 데이터 소스에서 호텔, 포인트 차감, 현금가, 예약 가능 여부를 가져온다.
4. 원본 데이터를 내부 표준 필드로 정규화한다.
5. `pointHotels/{hotelId}`를 upsert한다.
6. 날짜별 데이터를 연도별 map으로 묶어 `pointHotels/{hotelId}/calendarYears/{yearKey}`에 upsert한다.
7. 이전 최신값과 비교해 변경된 날짜만 `pointHotels/{hotelId}/calendarYearRuns/{yearKey}_{runSlot}`에 기록한다.
8. 1~7박 기준으로 `pointAwardIndexes`를 생성 또는 갱신한다.
9. 집계 인덱스는 전체 문서를 덮어쓴다. 외부 공급자 실패처럼 후보가 0개인 경우 기존 인덱스를 즉시 비우지 않는 운영 정책을 둘 수 있다.
10. 성공/실패 건수와 오류를 `pointHotelSyncRuns/{runId}`에 기록한다.

장애 대응 원칙:

- 외부 공급자가 실패해도 기존 화면을 즉시 비우지 않는다.
- `pointAwardIndexes`는 `updatedAt` 기준 24시간이 지나면 탐색 탭에서 낮은 우선순위로 보거나 제외한다.
- `pointHotels.currentAward`는 마지막 성공 데이터가 48시간을 넘으면 `available: false` 또는 `stale` 상태로 표시한다.
- 크론 실패는 `pointHotelSyncRuns`에 남기고 운영 알림으로 연결한다.

## 9. 후보 계산 규칙

기본 계산:

```text
krwPerPoint = cashTotalKrw / pointsTotal
valueScore = round(krwPerPoint * 100)
```

메리어트/힐튼처럼 5박째 무료 로직을 반영해야 하는 프로그램은 서버에서 `pointsTotal` 계산 시 적용한다.

```text
if programId in [marriott, hilton] and nights >= 5:
  freeNightCount = floor(nights / 5)
  pointsTotal = sum(all nightly points) - sum(lowest freeNightCount nightly points)
else:
  pointsTotal = sum(all nights)
```

v1에서는 간단히 같은 호텔의 날짜별 포인트를 합산하고, 5박째 무료가 있는 프로그램은 가장 낮은 포인트 1박을 제외한다. 더 정확한 정책이 필요하면 프로그램별 `pointHotelPrograms.rules` 또는 별도 서버 계산기로 분리한다.

## 10. 보안 규칙 원칙

실제 rules 파일은 프로젝트 정책에 맞춰 작성하되, 포인트 숙박 공개 데이터는 아래 원칙을 지킨다.

- 활성 호텔/후보/캘린더는 누구나 읽을 수 있다.
- 비활성/숨김 데이터는 일반 클라이언트가 읽지 못하게 한다.
- 일반 클라이언트는 포인트 숙박 운영 컬렉션에 쓸 수 없다.
- `pointHotelSyncRuns`는 관리자 또는 서버만 읽고 쓴다.
- 서버 배치는 Admin SDK로 쓰므로 Firestore Rules의 클라이언트 쓰기 허용이 필요 없다.

규칙 예시:

```text
match /pointHotelPrograms/{programId} {
  allow read: if resource.data.isActive == true;
  allow write: if false;
}

match /pointHotels/{hotelId} {
  allow read: if resource.data.status == "active";
  allow write: if false;

  match /calendarYears/{yearKey} {
    allow read: if resource.data.stale == false;
    allow write: if false;
  }

  match /calendarYearRuns/{runDocId} {
    allow read, write: if false;
  }
}

match /pointAwardIndexes/{indexId} {
  allow read: if resource.data.status == "active"
    && resource.data.stale != true;
  allow write: if false;
}

match /pointHotelSyncRuns/{runId} {
  allow read, write: if false;
}
```

Firestore Rules는 필터가 아니므로 쿼리 기반 컬렉션은 항상 `status == active`, `stale == false` 같은 조건을 포함해야 한다. `pointAwardIndexes`는 문서 ID 직접 조회라서 복합 인덱스를 만들지 않는다.

## 11. 더미 데이터 마이그레이션 기준

현재 `PointHotel` 더미 필드는 다음처럼 Firestore로 이동한다.

| `PointHotel` 필드 | Firestore 위치 |
| --- | --- |
| `id` | `pointHotels/{hotelId}.hotelId` |
| `name` | `pointHotels.name`, `pointAwardIndexes.items[].name` |
| `city` | `pointHotels.city`, `pointAwardIndexes.items[].city` |
| `country` | `pointHotels.country`, `pointAwardIndexes.items[].country` |
| `address` | `pointHotels.address`, `pointAwardIndexes.items[].address` |
| `brand` | `pointHotels.brand`, `pointAwardIndexes.items[].brand` |
| `imageUrl` | `pointHotels.imageUrl`, `pointAwardIndexes.items[].imageUrl` |
| `galleryUrls` | `pointHotels.galleryUrls` |
| `rating` | `pointHotels.rating`, `pointAwardIndexes.items[].rating` |
| `pointsPerNight` | `pointHotels.currentAward.pointsPerNight`, `calendarYears.days.{dMMdd}.p` |
| `cashPerNightKrw` | `pointHotels.currentAward.cashPerNightKrw`, `calendarYears.days.{dMMdd}.c` |
| `guestFavorite` | `pointHotels.guestFavorite`, `pointAwardIndexes.items[].guestFavorite` |
| `description` | `pointHotels.description` |
| `amenities` | `pointHotels.amenities` |
| `calendarPoints` | `pointHotels.calendarPreview`, `calendarYears.days` |

마이그레이션 순서:

1. `pointHotelPrograms` seed 문서를 만든다.
2. 기존 `pointHotelSamples`를 기준으로 `pointHotels` seed 문서를 만든다.
3. `calendarPoints`를 오늘부터 14일치 `calendarYears/{yearKey}.days` map으로 변환한다.
4. 1~7박 기준 `pointAwardIndexes`를 생성한다.
5. Flutter에서는 더미 배열 대신 Firestore repository를 통해 같은 화면 모델로 변환한다.

## 12. 수용 기준

Firestore 구축이 완료되었다고 보려면 아래 조건을 만족해야 한다.

- 호텔 탭이 더미 배열 없이 `pointHotels`에서 호텔 목록을 불러온다.
- 호텔명, 도시, 국가, 브랜드 검색이 동작한다.
- 날짜와 숙박 수가 있는 검색은 `calendarYears` 기준으로 계산된다.
- 탐색 탭에서 전체/브랜드별 후보가 `pointAwardIndexes` 문서 1개 read로 표시된다.
- 탐색 탭의 `가치순`, `낮은 포인트`, `최근 확인` 정렬이 미리 생성된 집계 문서로 처리된다.
- 호텔 상세가 `calendarYears`에서 날짜별 포인트 캘린더를 불러온다.
- 일반 클라이언트는 포인트 숙박 운영 컬렉션에 쓸 수 없다.
- 크론 실패 시 기존 화면이 빈 화면으로 무너지지 않고 마지막 성공 데이터를 유지한다.

## 13. v1 범위와 제외 항목

v1에 포함:

- 호텔 기본 정보 조회
- 호텔 검색
- 브랜드별 탐색
- 날짜별 포인트 캘린더
- 크론 기반 데이터 갱신
- 크론 실행 로그

v1에서 제외:

- 사용자 저장 호텔
- 포인트 객실 알림
- 예약 deep link 추적
- 커뮤니티 후기 자동 연결
- 전문 검색 인덱스
- 외부 공급자별 수집 구현 상세

이 제외 항목은 이후 `users/{uid}/savedPointHotels`, `users/{uid}/hotelPointGoals`, 커뮤니티 라벨, 레이더 알림으로 확장한다.

## 14. 결론

포인트 숙박의 `호텔` 탭과 `탐색` 탭은 클라이언트에서 직접 계산하는 기능이 아니라, Firestore에 준비된 읽기 모델을 빠르게 보여주는 기능으로 설계한다.

핵심은 `pointHotels`와 `pointAwardIndexes`를 분리하는 것이다. `pointHotels`는 호텔 검색과 상세의 기준 데이터이고, `pointAwardIndexes`는 탐색 탭의 브랜드/숙박 수/정렬 결과를 문서 1개로 빠르게 읽기 위한 화면 전용 데이터다.

크론 작업은 이 두 읽기 모델을 계속 최신 상태로 갱신한다. 앱은 단순히 읽고 보여준다.
