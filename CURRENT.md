## Firestore 현재 설계 (상품권 시세용)

크롤링 서버가 참고해야 할 **공식 Firestore 구조 정의서**입니다.  
마일캐치 앱의 상품권 시세/지점 정보는 아래 구조를 기준으로 저장합니다.

---

## 최상위 컬렉션 개요

- **`branches`**: 지점(매입처) 정보 + 지점별 상품권 시세/히스토리
- **`giftcards`**: 상품권 브랜드 정보 + 브랜드별 요약 시세

크롤러는 주로 아래 3곳을 업데이트합니다.

- **지점 기준 현재 시세**: `branches/{branchId}/giftcardRates_current/{giftcardId}`
- **지점 기준 일별 히스토리**: `branches/{branchId}/rates_daily/{yyyymmdd}`
- **브랜드 기준 요약 시세**: `giftcards/{giftcardId}`

---

## 1. `branches` 컬렉션 (지점 정보)

- **경로**
  - `branches/{branchId}`
- **예시**
  - `branches/choigo`
  - `branches/myeongin`

### 1-1. 지점 문서 예시 필드

- **기본 정보**
  - `branchId`: 문자열, 지점 ID (문서 ID와 동일하게 유지 권장)
  - `name`: `"최고 상품권"` 등 지점명
  - `address`: 주소 문자열
  - `phone`: 전화번호 문자열
  - `notice`: 안내사항
- **위치/이미지**
  - `latitude`: double
  - `longitude`: double
  - `logoUrl`: string
- **영업시간 (예시 구조)**
  - `openingHours.monFri`: `"10:30~19:30"`
  - `openingHours.sat`: `"10:30~17:00"`
  - `openingHours.sun`: `"전화 문의"` 등

> 크롤링 서버는 보통 **시세 관련 서브컬렉션만** 건드리고,  
> 지점 기본 정보는 앱/관리툴에서 수동 관리하는 것을 기본으로 합니다.

---

## 1-2. 현재 시세: `giftcardRates_current` (크롤러 필수 업데이트)

- **경로**
  - `branches/{branchId}/giftcardRates_current/{giftcardId}`
- **설명**
  - “지금 이 지점이 이 상품권을 얼마에 사고/파는지”를 저장하는 컬렉션.
  - 오상 사이트의 **지점 상세 시세표**, 마일캐치의 **지점 상세 > 시세 탭**에서 사용.

### 1-2-1. 문서 구조 예시

- **경로 예시**
  - `branches/myeongin/giftcardRates_current/lotte`
  - `branches/choigo/giftcardRates_current/samsung`

- **필드 (예시, 필요에 따라 조정 가능)**
  - `giftcardId`: 문자열 (예: `"lotte"`, `"samsung"`)
  - `branchId`: 문자열 (예: `"myeongin"`)  
    - 중복 정보지만, collectionGroup 쿼리에서 편의를 위해 포함.
  - **가격/수수료 – 사용자 기준**
    - `sellPrice_general`: int  
      - 사용자가 이 지점에 **상품권을 팔 때(일반권)** 받는 금액
    - `sellPrice_gift`: int (선택)  
      - 사용자가 **증정권**을 팔 때 받는 금액
    - `buyPrice_general`: int  
      - 사용자가 이 지점에서 **상품권을 살 때(일반권)** 지불하는 금액
    - `buyPrice_gift`: int (선택)
  - **비율 정보 (있으면 함께 저장)**
    - `sellFeeRate_general`: double (예: `3.30`) – 팔 때 수수료율
    - `buyDiscountRate_general`: double (예: `3.25`) – 살 때 할인율
  - **메타**
    - `isActive`: bool (선택, 현재 취급 여부)
    - `updatedAt`: Timestamp (크롤링 시각)

### 1-2-2. 크롤링 서버 동작 규칙

- 각 크롤링 주기마다,
  - 지점 × 상품권 조합별로 위 경로에 `set`(merge) 또는 `update`.
- 이미 있는 문서를 덮어써도 무방하며, 항상 **최신 값**을 유지하는 컬렉션입니다.

---

## 1-3. 일별 히스토리: `rates_daily` (크롤러 필수 업데이트)

- **경로**
  - `branches/{branchId}/rates_daily/{yyyymmdd}`
  - 예: `branches/myeongin/rates_daily/20251202`
- **설명**
  - “이 지점의 **해당 날짜 기준** 시세 스냅샷”을 저장.
  - 오상 사이트의 **차트(날짜별 변동)** 을 위한 데이터 소스.

### 1-3-1. 문서 ID 규칙

- `yyyymmdd` 형태의 문자열을 문서 ID로 사용.
  - 예: `"20251025"`, `"20251202"`
- 정렬 시 문자열 순서가 날짜 순서와 같아서,  
  `orderBy(FieldPath.documentId())` 만으로 일자 오름차순 정렬이 가능.

### 1-3-2. 문서 구조 예시

- **필드**
  - `date`: Timestamp  
    - 해당 날짜 00:00:00 (또는 크롤링 시각)
  - `giftcardRates`: Map  
    - 키: `giftcardId` (예: `"lotte"`, `"samsung"`)
    - 값: 해당 상품권의 시세 스냅샷

- **예시 구조 (개념)**
  - `giftcardRates.lotte.sellPrice_general`: 96700
  - `giftcardRates.lotte.buyPrice_general`: 96750
  - `giftcardRates.samsung.sellPrice_general`: 97100
  - `giftcardRates.samsung.buyPrice_general`: 97000

> 한 문서에 **여러 상품권**의 값을 같이 넣는 구조입니다.  
> 이 데이터에서 특정 `giftcardId` 만 골라서 라인 차트를 그립니다.

### 1-3-3. 크롤링 서버 동작 규칙

- 하루에 한 번(또는 크롤링 타이밍마다),
  - 해당 지점의 모든 상품권 시세를 한 번에 모아
  - `branches/{branchId}/rates_daily/{yyyymmdd}` 에 `set`(merge) 또는 `update`.
- 이미 있는 날짜 문서가 있으면 갱신, 없으면 생성.

---

## 1-4. 월별 집계: `rates_monthly` (선택)

- **경로**
  - `branches/{branchId}/rates_monthly/{yyyymm}`
  - 예: `branches/myeongin/rates_monthly/202512`
- **용도**
  - 월 평균/최고/최저값 등 요약 통계가 필요할 경우 사용.
- **필드 예시**
  - `month`: `"2025-12"`
  - `giftcardStats.lotte.avgSellPrice_general`
  - `giftcardStats.lotte.maxSellPrice_general`
  - … (필요 시 정의)

> 월별 집계는 필수가 아니며,  
> 필요해지면 크롤러 또는 Cloud Functions 로 추가 집계하는 것을 전제로 합니다.

---

## 2. `giftcards` 컬렉션 (상품권 브랜드 정보)

- **경로**
  - `giftcards/{giftcardId}`
- **예시**
  - `giftcards/lotte`
  - `giftcards/samsung`

### 2-1. 기본 정보 필드

- `giftcardId`: 문자열 (문서 ID와 동일하게 유지 권장)
- `name`: `"롯데상품권"` 등 표시용 이름
- `logoUrl`: 브랜드 로고 이미지 URL
- `sortOrder`: int (리스트 정렬 순서)

> 이 부분은 “브랜드 마스터 데이터”이며,  
> 크롤러보다는 관리툴/앱에서 수동 관리해도 됩니다.

---

## 2-2. 브랜드별 요약 시세 (크롤러/집계 서버가 업데이트)

- **용도**
  - 메인 시세 리스트, “어디에 팔면 제일 이득인지” 한눈에 보여주기 위한 요약 값.
- **필드 예시**
  - `bestSellPrice`: int  
    - 사용자가 이 상품권을 팔 때 **가장 많이 주는 가격**
  - `bestSellBranchId`: string  
    - 위 가격을 제공하는 `branchId`
  - `bestBuyPrice`: int  
    - 사용자가 이 상품권을 살 때 **가장 싸게 살 수 있는 가격**
  - `bestBuyBranchId`: string
  - `bestUpdatedAt`: Timestamp
  - (선택) `worstSellPrice`, `worstSellBranchId`, `worstBuyPrice`, `worstBuyBranchId` : 최저/최고 값 참고용

### 2-2-1. 크롤링/집계 서버 동작 규칙

1. 모든 지점의 `giftcardRates_current` 를 크롤링/저장한 뒤,
2. `giftcardId` 별로:
   - `collectionGroup('giftcardRates_current')`  
     또는 내부 메모리 데이터를 순회하며
   - `sellPrice_general` 최대값/최소값, `buyPrice_general` 최소값/최대값을 계산.
3. 그 결과를 `giftcards/{giftcardId}` 의 요약 필드들(`best*`, 선택 시 `worst*`)로 `update`.

> 이 과정은 크롤링 서버에서 같이 해도 되고,  
> 별도의 집계 배치(Cloud Functions 등)로 분리해도 됩니다.

---

## 3. 상품권 시세 표 화면 기본 정책

1bang.kr 형태처럼 `상품권 × 지점` 행렬로 현재 시세를 보여줄 수 있습니다.
이 표는 기존 `branches/{branchId}/giftcardRates_current/{giftcardId}` 문서를 셀 데이터로 사용합니다.

### 3-1. 기본 행(상품권) 구성

사용자별 설정이 없을 때 표의 기본 행은 아래 상품권 4개를 우선 표시합니다.

- `lotte`: 롯데상품권
- `shinsegae`: 신세계상품권
- `hyundai`: 현대상품권
- `galleria`: 갤러리아상품권

> 기본 표는 현재 앱의 주 사용 단위인 **10만 원권 기준**으로 표시합니다.  
> 추후 5만 원권, 50만 원권 등을 분리해야 하면 `giftcardRates_current` 문서에 `faceValue` 또는 `denomination` 필드를 추가해 같은 상품권 브랜드 안에서도 권종을 구분합니다.

### 3-2. 기본 열(지점) 구성

사용자별 표시 지점 설정이 없을 때 표의 기본 열은 `lotte` 기준 상위 3개 지점입니다.

- 기준 상품권: `lotte`
- 기준 가격: `sellPrice_general`
- 정렬 규칙:
  1. `branches/{branchId}/giftcardRates_current/lotte` 문서가 존재하는 지점만 후보로 사용
  2. `sellPrice_general` 높은 순으로 정렬
  3. 동률이면 `sellFeeRate_general` 낮은 순으로 정렬
  4. 그래도 동률이면 지점명 오름차순으로 정렬
- 결과: 상위 3개 `branchId`를 표의 기본 열로 사용

> 사용자 입장에서 “팔 때 가장 유리한 지점”을 기본값으로 잡기 위한 규칙입니다.

### 3-3. 표 셀 표시 규칙

각 셀은 `branches/{branchId}/giftcardRates_current/{giftcardId}` 문서를 읽어 구성합니다.

- 판매 기준 표시:
  - 가격: `sellPrice_general`
  - 수수료율: `sellFeeRate_general`
  - 수수료율이 없으면 `sellPrice_general`과 기준 액면가 100,000원으로 계산
- 구매 기준 표시:
  - 가격: `buyPrice_general`
  - 할인율: `buyDiscountRate_general`
  - 할인율이 없으면 `buyPrice_general`과 기준 액면가 100,000원으로 계산
- 해당 지점이 해당 상품권을 취급하지 않거나 문서가 없으면 `-`로 표시
- 표 기본 모드는 판매 기준(`sellPrice_general`)을 우선 사용하고, 필요 시 UI에서 구매 기준으로 전환합니다.

---

## 4. 사용자별 상품권 시세 표 지점 설정

사용자가 직접 표에 표시할 지점 1, 2, 3순위를 선택하고 순서를 변경할 수 있도록 사용자 문서 하위에 설정 문서를 둡니다.

### 4-1. 경로

- `users/{uid}/giftcard_meta/order`

### 4-2. 문서 구조 예시

```json
{
  "branchIds": ["hiticket", "best", "choigo"],
  "giftcardIds": ["lotte", "hyundai", "shinsegae"],
  "updatedAt": "serverTimestamp",
  "updatedByUid": "{uid}"
}
```

- `branchIds`: 표 열로 보여줄 지점 ID 목록
  - 배열 순서가 화면 표시 순서입니다.
  - 예: 1위 `hiticket`, 2위 `best`, 3위 `choigo`
  - 기본 UI는 최대 3개 지점을 선택하도록 제한합니다.
- `giftcardIds`: 표 행으로 보여줄 상품권 ID 목록
  - 배열 순서가 화면 표시 순서입니다.
  - 예: 1행 `lotte`, 2행 `hyundai`, 3행 `shinsegae`
  - 기본 UI는 최소 3개, 최대 6개 상품권을 선택하도록 제한합니다.
- `updatedAt`: 마지막 수정 시각
- `updatedByUid`: 수정한 사용자 UID

> 설정 문서 이름은 `order`로 고정합니다.  
> `branchIds`와 `giftcardIds`는 같은 문서에서 함께 관리합니다.

### 4-3. 화면 적용 규칙

1. 시세 표 진입 시 `users/{uid}/giftcard_meta/order` 문서를 먼저 조회합니다.
2. 문서가 있고 `branchIds`가 비어 있지 않으면, 해당 지점 목록을 표 열로 사용합니다.
3. `branchIds` 안에 삭제되었거나 비활성화된 지점이 있으면 해당 지점은 제외합니다.
4. 유효한 지점이 3개보다 적으면, 부족한 칸은 기본 열 계산 규칙(롯데상품권 판매가 상위 지점)으로 채웁니다.
5. `giftcardIds`가 3개 이상 있으면 해당 상품권 목록과 순서를 표 행으로 사용합니다.
6. `giftcardIds`가 없거나 유효한 상품권이 3개 미만이면 3-1의 기본 행 구성을 사용합니다.
7. 설정 문서가 없거나 유효한 지점이 하나도 없으면 3-2의 기본 열 계산 규칙을 사용합니다.

### 4-4. 사용자 편집 권한

- 로그인한 사용자는 본인 경로의 `users/{uid}/giftcard_meta/order`만 생성/수정할 수 있습니다.
- 사용자는 메뉴 편집 화면에서:
  - 표에 보여줄 지점 1~3개 선택
  - 1, 2, 3위 순서 변경
  - 표에 보여줄 상품권 3~6개 선택
  - 상품권 표시 순서 변경
  - 설정 초기화
  를 할 수 있습니다.
- 저장 시 앱은 선택한 지점 ID 배열을 `branchIds`에, 선택한 상품권 ID 배열을 `giftcardIds`에 순서대로 저장합니다.

---

## 5. 크롤링 서버 관점에서의 전체 플로우

1. **각 지점 페이지 크롤링**
   - 입력: `branchId`
   - 출력: `지점 × 상품권` 현재 시세 데이터(팔/살 가격, 수수료/할인율 등).
2. **현재 시세 쓰기**
   - 각 `(branchId, giftcardId)` 조합에 대해  
     → `branches/{branchId}/giftcardRates_current/{giftcardId}` 업데이트.
3. **일별 히스토리 쓰기**
   - 지점별로 해당 날짜의 모든 상품권 시세를 모아서  
     → `branches/{branchId}/rates_daily/{yyyymmdd}` 업데이트.
4. **브랜드별 요약 시세 집계**
   - 모든 지점의 최신 `giftcardRates_current` 기준으로  
     → `giftcards/{giftcardId}` 의 `best*` 필드 업데이트.

이 문서를 기준으로 크롤링 서버에서 Firestore 쓰기 로직을 구현하면,  
