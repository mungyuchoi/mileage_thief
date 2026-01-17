# 상품권 판매 랭킹 시스템

## 개요

상품권 판매 월별 랭킹 시스템입니다. 서버에서 주기적으로 실행되는 배치 작업을 통해 랭킹 데이터를 생성/갱신합니다.

## Firestore 경로

### 서버에서 생성하는 랭킹 데이터
```
meta/rates_monthly_v2/rates_monthly_v2/{monthKey}
```

- `monthKey`: `yyyyMM` 형식의 문자열 (예: `"202501"`, `"202512"`)

### 클라이언트에서 사용하는 경로
- 랭킹 조회: `meta/rates_monthly_v2/rates_monthly_v2/{monthKey}`

## 문서 구조

### 필드 설명

| 필드명 | 타입 | 설명 |
|--------|------|------|
| `users` | Array | 사용자별 합산된 판매금액 배열 (sellTotal 기준 내림차순 정렬) |
| `createdAt` | Timestamp | 문서 생성 시각 |
| `updatedAt` | Timestamp | 문서 마지막 갱신 시각 |

### `users` 배열 항목 구조

**서버에서 생성하는 구조**: 각 사용자별로 월별 총 판매금액이 합산되어 저장됩니다.

```typescript
{
  uid: string,           // 사용자 UID
  displayName: string,   // 사용자 닉네임 (최신 정보)
  photoUrl: string,      // 프로필 이미지 URL (최신 정보)
  sellTotal: number      // 해당 사용자의 월별 총 판매금액 (uid별 합산)
}
```

**중요**: `users` 배열은 `sellTotal` 기준으로 **내림차순 정렬**되어 저장되므로, 클라이언트에서 바로 랭킹을 표시할 수 있습니다.

**Top 3 접근**: `users[0]`, `users[1]`, `users[2]`로 1위, 2위, 3위 사용자 정보에 바로 접근할 수 있습니다.

## 서버 갱신 로직

### 1. 실행 주기

서버에서 주기적으로(예: 매일 또는 매시간) 배치 작업을 실행하여 랭킹 데이터를 생성/갱신합니다.

### 2. 대상 사용자 필터링

다음 조건을 모두 만족하는 사용자만 랭킹에 포함됩니다:

1. **`users/{uid}/hasGift`** = `true`
   - 상품권 기능을 사용하는 사용자

2. **`users/{uid}/ranking_agree`** = `true`
   - 랭킹 참여에 동의한 사용자

### 3. 데이터 수집 및 집계

#### 3-1. 대상 사용자 조회

```javascript
// 의사 코드
const eligibleUsers = await firestore
  .collection('users')
  .where('hasGift', '==', true)
  .where('ranking_agree', '==', true)
  .get();
```

#### 3-2. 월별 판매 데이터 집계

각 대상 사용자에 대해 해당 월의 모든 판매 데이터를 조회하여 합산:

```javascript
// 의사 코드
const monthKey = '202501'; // 예: 2025년 1월
const startDate = new Date(2025, 0, 1); // 2025-01-01 00:00:00
const endDate = new Date(2025, 1, 1);   // 2025-02-01 00:00:00

const userRankings = [];

for (const userDoc of eligibleUsers.docs) {
  const uid = userDoc.id;
  const userData = userDoc.data();
  
  // 해당 사용자의 해당 월 판매 데이터 조회
  const sales = await firestore
    .collection('users')
    .doc(uid)
    .collection('sales')
    .where('sellDate', '>=', startDate)
    .where('sellDate', '<', endDate)
    .get();
  
  // 판매금액 합산
  let totalSell = 0;
  for (const sale of sales.docs) {
    const sellTotal = sale.data().sellTotal || 0;
    totalSell += sellTotal;
  }
  
  // 랭킹에 추가
  if (totalSell > 0) {
    userRankings.push({
      uid: uid,
      displayName: userData.displayName || userData.email || '익명',
      photoUrl: userData.photoURL || '',
      sellTotal: totalSell
    });
  }
}
```

#### 3-3. 정렬 및 저장

```javascript
// sellTotal 기준 내림차순 정렬
userRankings.sort((a, b) => b.sellTotal - a.sellTotal);

// Firestore에 저장
const docRef = firestore
  .collection('meta')
  .doc('rates_monthly_v2')
  .collection('rates_monthly_v2')
  .doc(monthKey);

await docRef.set({
  users: userRankings,  // 이미 정렬된 배열 (users[0], users[1], users[2]가 Top 3)
  createdAt: FieldValue.serverTimestamp(),
  updatedAt: FieldValue.serverTimestamp()
}, { merge: true });
```

### 4. 데이터 구조의 장점

**제안된 구조 (정렬된 users 배열)**:
- ✅ 클라이언트에서 바로 랭킹 표시 가능 (추가 정렬 불필요)
- ✅ 전체 랭킹을 한 번에 조회 가능
- ✅ `users[0]`, `users[1]`, `users[2]`로 Top 3 바로 접근 가능
- ✅ 서버에서 한 번만 집계하면 되므로 효율적
- ✅ 불필요한 중복 필드 제거로 데이터 크기 감소

**기존 구조 (판매 단위별 저장)**:
- ❌ 클라이언트에서 uid별 합산 및 정렬 필요
- ❌ 실시간 갱신은 가능하지만 서버 배치 작업과 충돌 가능성

## 예시 데이터

### 예시: 2025년 1월 랭킹 문서 (서버 생성)

```json
{
  "users": [
    {
      "uid": "user2",
      "displayName": "김철수",
      "photoUrl": "https://example.com/user2.jpg",
      "sellTotal": 5000000
    },
    {
      "uid": "user1",
      "displayName": "홍길동",
      "photoUrl": "https://example.com/user1.jpg",
      "sellTotal": 3000000
    },
    {
      "uid": "user3",
      "displayName": "이영희",
      "photoUrl": "https://example.com/user3.jpg",
      "sellTotal": 2000000
    },
    {
      "uid": "user4",
      "displayName": "박민수",
      "photoUrl": "https://example.com/user4.jpg",
      "sellTotal": 1500000
    }
  ],
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-31T23:59:59Z"
}
```

**중요**: `users` 배열은 `sellTotal` 기준으로 **내림차순 정렬**되어 있습니다.

## 사용자 필드

### `users/{uid}` 문서 필드

| 필드명 | 타입 | 설명 |
|--------|------|------|
| `hasGift` | boolean | 상품권 기능 사용 여부 (true인 경우만 랭킹 대상) |
| `ranking_agree` | boolean | 랭킹 참여 동의 여부 (true인 경우만 랭킹 대상) |
| `displayName` | string | 사용자 닉네임 (랭킹에 표시) |
| `photoURL` | string | 프로필 이미지 URL (랭킹에 표시) |

## 주의사항

1. **서버 배치 작업**: 랭킹 데이터는 서버에서 주기적으로 생성/갱신되므로, 실시간 반영이 아닙니다.

2. **필터링 조건**: `hasGift == true` && `ranking_agree == true`인 사용자만 랭킹에 포함됩니다.

3. **정렬된 배열**: `users` 배열은 서버에서 이미 정렬되어 저장되므로, 클라이언트에서 추가 정렬이 필요 없습니다.

4. **최신 정보**: 서버가 랭킹을 생성할 때 사용자의 최신 `displayName`과 `photoURL`을 사용합니다.

5. **배열 인덱스 접근**: `users[0]`이 1위, `users[1]`이 2위, `users[2]`가 3위입니다. 사용자가 3명 미만인 경우 해당 인덱스는 존재하지 않을 수 있습니다.

6. **월별 데이터**: 각 월별로 별도의 문서가 생성되며, 월이 지나도 이전 월 데이터는 유지됩니다.

## 관련 코드 위치

- **랭킹 조회**: `lib/screen/giftcard_info_screen.dart`
  - `_loadRanking()`: 랭킹 데이터 로드 함수
  - `_loadRankingAgreement()`: 사용자 랭킹 동의 상태 로드
  - `_saveRankingAgreement()`: 사용자 랭킹 동의 상태 저장
  - `_handleRankingAgreementToggle()`: 랭킹 동의 토글 처리 (false로 변경 시 땅콩 50개 차감)

## 클라이언트 동작

### 랭킹 동의 관리

사용자는 상품권 정보 화면의 랭킹 탭에서 랭킹 참여 동의를 설정할 수 있습니다:

- **기본값**: `true` (동의)
- **필드명**: `users/{uid}/ranking_agree`
- **false로 변경 시**: 땅콩 50개 차감 (확인 팝업 표시)
- **true로 변경 시**: 즉시 허용 (비용 없음)

### 랭킹 데이터 조회

클라이언트는 `meta/rates_monthly_v2/rates_monthly_v2/{monthKey}` 경로에서 랭킹 데이터를 조회합니다.

- `users` 배열이 이미 정렬되어 있으므로, 바로 리스트로 표시 가능
- `users[0]`, `users[1]`, `users[2]`로 Top 3 접근 가능 (배열 인덱스로 직접 접근)

## 서버 구현 가이드

### 1. 실행 주기 설정

- 매일 자정 또는 특정 시간에 실행
- Cloud Functions의 스케줄러 또는 Cron Job 사용 권장

### 2. 데이터 수집 순서

1. `hasGift == true` && `ranking_agree == true`인 사용자 조회
2. 각 사용자의 해당 월 판매 데이터 조회 (`users/{uid}/sales`)
3. 판매금액 합산 (`sellTotal` 필드 합계)
4. 사용자별로 집계된 데이터 생성
5. `sellTotal` 기준 내림차순 정렬
6. Firestore에 저장

### 3. 성능 최적화

- 대량 사용자 처리 시 배치 처리 권장
- 판매 데이터 조회 시 인덱스 활용 (`sellDate` 필드 인덱스 필요)
- 필요시 캐싱 활용

## 참고사항

- **서버 전용**: `meta/rates_monthly_v2` 경로는 서버에서만 데이터를 생성/갱신합니다.
- **클라이언트 읽기 전용**: 클라이언트는 랭킹 데이터를 조회만 하며, 수정하지 않습니다.
- **이전 경로**: `meta/rates_monthly` 경로는 더 이상 사용하지 않습니다 (레거시).
