# 마일캐치 모의고사 기능 총정리

작성일: 2026-05-28

## 1. 한 줄 정의

마일캐치 모의고사는 사용자가 `항공`, `카드`, `상품권`, `호텔` 분야의 문제를 풀고, 점수와 랭킹을 통해 다른 사용자와 비교하며, 친구 공유와 딥링크를 통해 신규 사용자를 유입시키는 참여형 챌린지 콘텐츠다.

단순 퀴즈 기능이 아니라 다음 흐름을 만드는 것이 핵심이다.

```text
문제를 푼다
→ 점수가 나온다
→ 내 약점과 순위를 확인한다
→ 친구에게 공유한다
→ 친구가 딥링크로 들어와 응시한다
→ 사용자는 재도전하거나 다음 회차를 연다
```

## 2. 기능 목표

### 사용자 관점

- 내가 마일리지, 카드, 상품권, 호텔 혜택을 얼마나 알고 있는지 점검한다.
- 총점, 분야별 점수, 상위 퍼센트, 랭킹을 통해 내 위치를 확인한다.
- 친구와 점수를 비교하면서 다시 도전할 이유를 얻는다.
- 오답과 해설을 통해 틀린 내용을 복습한다.
- 회차가 열리는 구조를 통해 게임처럼 다음 문제를 기대한다.

### 운영 관점

- JSON 기반 문제 데이터를 활용해 회차별 모의고사를 계속 운영한다.
- 회차, 공개 기간, 랭킹 기간, 잠금 해제 조건을 조절해 이벤트처럼 운영한다.
- 친구 공유와 딥링크를 통해 자연 유입 루프를 만든다.
- 사용자의 관심 분야와 약점 데이터를 쌓아 이후 콘텐츠, 추천, 알림에 활용한다.

### 제품 관점

- 마일캐치에 반복 방문할 이유를 만든다.
- 커뮤니티/카드/상품권/호텔/항공 데이터를 학습형 콘텐츠로 재사용한다.
- 랭킹과 공유를 통해 토스식 챌린지 경험을 만든다.

## 3. 초기 문제 구성

초기 버전은 4개 분야, 분야별 5문제, 총 20문제로 구성한다.

| 분야 | 문제 수 | 예시 주제 |
| --- | ---: | --- |
| 항공 | 5 | 마일리지 사용, 좌석, 항공사 규정, 발권 전략 |
| 카드 | 5 | 카드 혜택, 실적 조건, 포인트 전환, 마일리지 적립 |
| 상품권 | 5 | 할인율, 실질 구매가, 매입가, 상테크 계산 |
| 호텔 | 5 | 티어, 포인트 전환, 숙박권, 프로모션 |

초기에는 객관식 중심으로 간다. 문제를 너무 어렵게 만들기보다 “풀고 싶고 공유하고 싶은” 난이도를 먼저 잡는다.

### 문제 유형

- 4지선다 객관식
- O/X 문제
- 이미지 보고 정답 고르기
- 혜택 설명 보고 상품/카드/호텔 맞히기
- 조건에 맞는 최적 선택지 고르기
- 간단한 계산 문제

이미지가 있는 경우 문제 화면은 `이미지 + 질문 + 선택지` 구조로 제공한다.

## 4. 기본 사용자 흐름

```text
모의고사 목록 진입
→ 열린 회차 선택
→ 문제 풀이
→ 제출
→ 총점 확인
→ 분야별 점수 확인
→ 전체/주간/친구 랭킹 확인
→ 오답 및 해설 확인
→ 친구 공유 또는 재도전
→ 다음 회차 잠금 해제/오픈 대기
```

결과 화면이 가장 중요하다. 사용자는 문제 풀이 자체보다 “내 점수가 어느 정도인지”, “친구보다 높은지”, “상위 몇 퍼센트인지”에 더 강하게 반응할 가능성이 높다.

## 5. 점수 체계

초기 MVP는 100점 만점으로 운영한다.

- 총 20문제
- 문제당 5점
- 분야별 25점
- 총점 100점

예시:

```text
총점 80점

항공 20 / 25
카드 15 / 25
상품권 25 / 25
호텔 20 / 25
```

### 결과 화면에서 보여줄 정보

- 총점
- 분야별 점수
- 정답 수
- 풀이 시간
- 상위 퍼센트
- 전체 순위
- 주간 순위
- 친구 중 순위
- 평균 점수와의 비교
- 가장 약한 분야
- 오답/해설 보기 버튼
- 공유 버튼
- 다시 풀기 버튼
- 다음 회차 상태

### 확장 가능한 점수 방식

MVP 이후에는 난이도별 점수 가중치를 추가할 수 있다.

| 난이도 | 점수 예시 |
| --- | ---: |
| 쉬움 | 4점 |
| 보통 | 5점 |
| 어려움 | 6점 |

다만 첫 버전에서는 모든 문제를 5점으로 두는 편이 운영과 사용자의 이해 모두에 좋다.

## 6. 랭킹 설계

이 기능의 핵심 재미는 랭킹이다. 오답 해설은 학습 가치를 만들고, 랭킹은 재방문과 공유를 만든다.

### 랭킹 종류

- 회차별 랭킹: `제1회 모의고사 랭킹`
- 주간 랭킹: 이번 주 응시자 기준
- 누적 랭킹: 전체 회차 누적 점수 기준
- 분야별 랭킹: 항공/카드/상품권/호텔 분야별
- 친구 랭킹: 초대/공유 관계 또는 친구 관계 기준

초기 MVP에서는 `회차별 랭킹`, `주간 랭킹`, `친구 랭킹`을 우선 추천한다.

### 정렬 기준

동점자가 많이 나올 수 있으므로 정렬 기준을 명확히 둔다.

1. 총점 높은 순
2. 풀이 시간 짧은 순
3. 먼저 제출한 순
4. 동일하면 최근 최고 기록 기준

예시:

```text
85점 사용자 2명
→ 3분 12초 사용자가 4분 20초 사용자보다 상위
```

### 랭킹 반영 기준

추천 방식:

- 응시는 여러 번 가능
- 랭킹에는 최고 점수 반영
- 최고 점수가 같으면 가장 짧은 풀이 시간 반영
- 결과 화면에는 `첫 응시 점수`와 `최고 점수`를 구분해 표시 가능

무제한 재도전은 랭킹 신뢰도를 떨어뜨릴 수 있다. 따라서 기본 응시 후 재도전권을 제한적으로 제공하는 구조가 좋다.

## 7. 재도전권 설계

재도전권은 공유 기능과 연결하기 좋다.

### 기본 규칙

- 회차별 기본 응시 1회 제공
- 제출 후 결과와 해설 확인 가능
- 재도전권이 있으면 같은 회차를 다시 풀 수 있음
- 랭킹에는 최고 기록 반영

### 재도전권 지급 방식

- 친구에게 공유하면 재도전권 1장 지급
- 친구가 딥링크로 들어와 응시하면 추가 재도전권 지급
- 특정 점수 이하인 경우 1회 복습 재도전 제공
- 이벤트 기간에는 운영진이 재도전권 추가 지급

주의할 점은 “공유해야만 계속할 수 있다”는 느낌을 피하는 것이다. 공유는 강제가 아니라 이득이 있는 선택지로 설계하는 편이 좋다.

### 공유 보상 기록 방식

친구 공유 보상은 중복 지급 방지가 중요하다. 사용자가 공유 버튼을 계속 누르는 것만으로 재도전권을 무한히 얻으면 랭킹 신뢰도가 떨어진다.

추천 방식:

- 회차별/응시별 공유 보상은 1회만 지급
- 공유 버튼 클릭 후 Branch 링크 생성에 성공하면 재도전권 1장 지급
- 같은 `attemptId`로 이미 공유 보상을 받았다면 추가 지급하지 않음
- 친구가 링크로 들어와 실제 응시 완료까지 하면 별도 보상을 줄 수 있음

예시:

```text
1회 모의고사 결과 공유
→ Branch 링크 생성 성공
→ mockExam/main/users/{uid}/progress/{examId}.retryTickets +1
→ mockExam/main/users/{uid}/shareRewards/{rewardId} 기록
```

공유 완료 여부를 OS 공유 시트에서 완벽하게 검증하기는 어렵다. MVP에서는 `공유 링크 생성 성공` 또는 `공유 버튼 클릭`을 보상 기준으로 잡고, 중복 지급만 막는 방식이 현실적이다. 더 엄격한 보상은 친구가 딥링크로 들어와 응시를 제출했을 때 지급한다.

## 8. 친구 공유와 딥링크

친구 공유는 마일캐치 모의고사의 바이럴 루프를 만든다.

### 공유 메시지 예시

```text
나는 마일캐치 모의고사 1회에서 85점!
상위 12%에 들었어요.
너도 도전해볼래?
```

또는 조금 더 경쟁형으로:

```text
마일캐치 모의고사 1회 85점.
내 점수 넘으면 인정.
```

### 딥링크 동작

```text
친구가 공유 링크 클릭
→ 앱 설치 여부 확인
→ 앱이 있으면 해당 모의고사 회차로 이동
→ 앱이 없으면 스토어 또는 웹 랜딩으로 이동
→ 설치 후에도 같은 회차로 진입
```

### 딥링크에 담을 정보

- `examId`: 모의고사 회차 ID
- `ref`: 공유자 UID 또는 추천 코드
- `attemptId`: 공유자의 응시 기록 ID, 선택
- `score`: 공유 점수 표시용, 선택
- `source`: share, kakao, copy 등 유입 출처
- `campaign`: 이벤트/회차 캠페인 키

예시:

```text
https://milecatch.app/mock-exam/1?ref=user123&campaign=exam_1
```

앱 내부 라우팅 예시:

```text
mock_exam:exam_1
mock_exam_result:attempt_123
```

### 현재 코드 반영 메모

프로젝트에는 이미 다음 의존성이 있다.

- `flutter_branch_sdk`
- `share_plus`
- `firebase_analytics`
- `cloud_firestore`

따라서 새 딥링크 시스템을 처음부터 만들기보다 기존 `BranchService` 패턴을 확장하는 방향이 적절하다.

현재 `BranchService`는 외부 공유용 Branch 링크와 내부 이동용 `linkValue`를 함께 사용한다.

- 외부 공유: `FlutterBranchSdk.getShortUrl` 또는 `FlutterBranchSdk.showShareSheet`
- Branch payload: `destination`, `screen`, `path`, `linkValue`, 개별 ID를 custom metadata로 저장
- 내부 이동: `openInternalDeepLinkValue()`가 `linkValue`를 해석해 앱 내부 화면으로 이동
- 분석: `deep_link_open` 이벤트에 `source`, `destination`, 개별 ID를 기록

모의고사도 이 패턴에 맞춰 추가한다.

필요 작업 예시:

- `BranchService`에 `createMockExamShareLink()` 추가
- 필요하면 `showMockExamShareSheet()` 추가
- Branch payload에 `destination: mock-exam`, `screen: mock_exam`, `path: /mock-exam`, `linkValue: mock-exam:{examId}` 추가
- payload에 `examId`, `roundNo`, `referrerUid`, `attemptId`, `sharedScore`, `campaign` 추가
- `_handleDeepLinkData()`에서 `examId` 또는 `linkValue`를 읽어 모의고사 상세/응시 화면으로 이동
- `openInternalDeepLinkValue()`에서도 `mock-exam:{examId}` 내부 링크를 처리
- Branch 실패 시 `share_plus`로 일반 텍스트 공유 fallback
- 공유 클릭, 앱 진입, 응시 완료를 Analytics 이벤트로 기록

Branch payload 예시:

```json
{
  "destination": "mock-exam",
  "screen": "mock_exam",
  "path": "/mock-exam",
  "linkValue": "mock-exam:exam_001",
  "examId": "exam_001",
  "roundNo": 1,
  "referrerUid": "user123",
  "attemptId": "attempt_456",
  "sharedScore": 85,
  "campaign": "mock_exam_round_1"
}
```

내부 링크 값 예시:

```text
mock-exam:exam_001
mock-exam-result:attempt_456
```

친구가 링크를 누르면 앱은 `examId` 기준으로 해당 회차 화면에 진입한다. 로그인 전이면 로그인 후에도 `examId`, `referrerUid`, `campaign`을 임시 보관했다가 응시 시작/완료 시 기록하는 구조가 좋다.

## 9. 회차와 잠금 해제 구조

마일캐치 모의고사는 한 번 풀고 끝나는 기능이 아니라 회차형 콘텐츠로 운영한다.

### 기본 회차 구조

```text
제1회 마일캐치 모의고사: 공개
제2회 마일캐치 모의고사: 잠금
제3회 마일캐치 모의고사: 준비 중
스페셜 모의고사: 이벤트 기간 공개
```

### 잠금 해제 방식 후보

- 이전 회차 완료 시 다음 회차 해제
- 친구 공유 시 다음 회차 선공개
- 특정 날짜에 자동 오픈
- 특정 점수 이상이면 고난도 회차 해제
- 운영진이 이벤트로 강제 공개

### 추천 방식

가장 좋은 방식은 혼합형이다.

```text
1회: 항상 공개
2회: 1회 완료 시 해제
3회: 2회 완료 또는 친구 공유 시 해제
스페셜 회차: 이벤트 기간 또는 특정 점수 이상 공개
```

모든 회차를 잠그면 신규 사용자가 답답함을 느낄 수 있다. 따라서 1회는 반드시 공개하고, 이후 회차는 “게임처럼 열리는 느낌”을 주는 편이 좋다.

### 회차 카드 상태

모의고사 목록에서는 각 회차를 아래 상태로 보여준다.

- 공개: 바로 응시 가능
- 완료: 점수/랭킹/오답 보기 가능
- 재도전 가능: 재도전권 보유
- 잠금: 조건 달성 시 해제
- 오픈 예정: 특정 날짜 공개
- 종료: 랭킹 집계 종료, 기록 확인만 가능

## 10. 오답과 해설

오답 해설은 랭킹만으로 부족한 학습 가치를 만든다.

### 제공 정보

- 내가 고른 답
- 정답
- 해설
- 관련 이미지
- 관련 태그
- 관련 콘텐츠 링크

예시:

```text
카드 분야 오답 2개
상품권 분야 오답 0개

카드 혜택 비교 문제를 다시 풀어보세요.
```

### 복습 확장

MVP 이후에는 오답노트를 추가할 수 있다.

- 사용자별 오답 저장
- 틀린 문제만 다시 풀기
- 분야별 약점 복습
- 최근 7일 오답
- 자주 틀리는 태그 분석

## 11. 데이터 모델 제안

현재 문제 원천 데이터는 JSON으로 쌓고 있으므로, 운영/개발 데이터는 `문제 원본`, `회차`, `문제 표시 데이터`, `정답표`, `응시 기록`, `진행 상태`, `랭킹`, `공유 보상`을 분리하는 것이 좋다.

가장 중요한 원칙:

```text
문제와 선택지는 클라이언트가 읽어도 된다.
정답과 해설은 서버 채점 전에는 클라이언트가 직접 읽으면 안 된다.
```

랭킹이 중요한 기능이므로 정답이 앱에 노출되면 안 된다. 문제 표시용 컬렉션과 정답/해설 컬렉션을 분리하고, 채점은 Cloud Functions에서 처리하는 구조를 추천한다.

### 문제 JSON 예시

원천 JSON에는 운영 편의를 위해 정답과 해설이 같이 있어도 된다. 다만 Firestore로 배포할 때는 문제 표시용 데이터와 정답표로 나누어 저장한다.

```json
{
  "id": "card_001",
  "category": "card",
  "question": "이 카드의 주요 혜택으로 맞는 것은?",
  "image": "card_001.png",
  "choices": [
    {
      "id": "a",
      "text": "항공 마일리지 적립"
    },
    {
      "id": "b",
      "text": "호텔 조식 무료"
    },
    {
      "id": "c",
      "text": "상품권 10% 할인"
    },
    {
      "id": "d",
      "text": "공항철도 무료"
    }
  ],
  "correctChoiceId": "a",
  "explanation": "이 카드는 항공 마일리지 적립에 특화된 카드입니다.",
  "difficulty": "normal",
  "tags": ["마일리지", "카드혜택"]
}
```

`answerIndex`보다 `correctChoiceId`를 추천한다. 선택지 순서를 섞거나 수정할 때 인덱스 기반 정답은 깨지기 쉽다.

### Firestore 컬렉션 초안

추천 전체 구조는 최상위 루트 컬렉션을 `mockExam` 하나로 묶는 방식이다.

Firestore는 `collection / document / collection / document` 순서로 경로가 이어져야 하므로, `mockExam` 컬렉션 아래에 `main` 문서를 두고 그 아래에 모의고사 관련 서브컬렉션을 펼친다.

```text
mockExam/main
```

이 구조의 장점은 Firestore 콘솔에서 모의고사 관련 데이터가 하나의 루트 아래로 모인다는 점이다. 회차, 문제, 정답표, 응시 기록, 랭킹, 공유 보상 데이터가 흩어지지 않는다.

추천 경로:

```text
mockExam/main/exams/{examId}
mockExam/main/exams/{examId}/questions/{questionId}

mockExam/main/answerKeys/{examId}/questions/{questionId}

mockExam/main/users/{uid}/attempts/{attemptId}
mockExam/main/users/{uid}/progress/{examId}
mockExam/main/users/{uid}/shareRewards/{rewardId}

mockExam/main/leaderboards/{examId}/periods/{periodKey}/entries/{uid}
mockExam/main/shares/{shareId}
mockExam/main/referrals/{referralId}
```

#### `mockExam/main/exams/{examId}`

회차 메타데이터.

```json
{
  "title": "제1회 마일캐치 모의고사",
  "description": "항공, 카드, 상품권, 호텔 기본기를 확인하는 모의고사",
  "status": "published",
  "roundNo": 1,
  "questionCount": 20,
  "totalScore": 100,
  "categories": ["airline", "card", "giftcard", "hotel"],
  "timeLimitSeconds": 600,
  "openAt": "2026-05-28T00:00:00Z",
  "closeAt": null,
  "rankingPeriod": "weekly",
  "unlockRule": {
    "type": "always_open"
  },
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

#### `mockExam/main/exams/{examId}/questions/{questionId}`

회차에 포함된 문제 표시용 스냅샷. 클라이언트가 읽는 데이터다.

```json
{
  "sourceQuestionId": "card_001",
  "category": "card",
  "order": 1,
  "score": 5,
  "difficulty": "normal",
  "question": "이 카드의 주요 혜택으로 맞는 것은?",
  "imageUrl": "https://...",
  "choices": [
    {
      "id": "a",
      "text": "항공 마일리지 적립"
    },
    {
      "id": "b",
      "text": "호텔 조식 무료"
    },
    {
      "id": "c",
      "text": "상품권 10% 할인"
    },
    {
      "id": "d",
      "text": "공항철도 무료"
    }
  ],
  "tags": ["마일리지", "카드혜택"]
}
```

여기에는 `correctChoiceId`, `answerIndex`, `explanation`을 넣지 않는다. 문제는 원본이 바뀌더라도 과거 응시 기록이 흔들리지 않도록 회차에 스냅샷 형태로 저장하는 편이 안전하다.

#### `mockExam/main/answerKeys/{examId}/questions/{questionId}`

정답/해설 전용 문서. 클라이언트 직접 읽기를 막고 Cloud Functions/Admin SDK만 읽게 한다.

```json
{
  "correctChoiceId": "a",
  "answerText": "항공 마일리지 적립",
  "explanation": "이 카드는 항공 마일리지 적립에 특화된 카드입니다.",
  "score": 5,
  "category": "card",
  "tags": ["마일리지", "카드혜택"]
}
```

채점 후 결과 화면에서 해설이 필요하면 Cloud Function이 이 해설을 응시 기록 문서에 복사해 둔다. 그러면 사용자는 자신이 제출한 응시 결과 안에서만 해설을 볼 수 있다.

#### `mockExam/main/users/{uid}/attempts/{attemptId}`

사용자 응시 기록. 응시 시작 시 생성하고, 제출 후 서버가 채점 결과를 업데이트한다.

응시 시작 시:

```json
{
  "examId": "exam_001",
  "roundNo": 1,
  "status": "started",
  "questionCount": 20,
  "startedAt": "serverTimestamp",
  "submittedAt": null
}
```

제출 후:

```json
{
  "examId": "exam_001",
  "roundNo": 1,
  "status": "submitted",
  "score": 80,
  "totalScore": 100,
  "correctCount": 16,
  "questionCount": 20,
  "durationSeconds": 265,
  "categoryScores": {
    "airline": 20,
    "card": 15,
    "giftcard": 25,
    "hotel": 20
  },
  "answers": [
    {
      "questionId": "card_001",
      "selectedChoiceId": "a",
      "correctChoiceId": "a",
      "isCorrect": true,
      "score": 5,
      "category": "card",
      "explanation": "이 카드는 항공 마일리지 적립에 특화된 카드입니다."
    }
  ],
  "isBestAttempt": true,
  "sharedCount": 0,
  "referrerUid": null,
  "source": "direct",
  "campaign": "mock_exam_round_1",
  "startedAt": "serverTimestamp",
  "submittedAt": "serverTimestamp"
}
```

클라이언트는 선택한 답만 서버에 제출한다. `score`, `isCorrect`, `correctChoiceId`, `explanation`은 클라이언트가 직접 쓰면 안 된다.

제출 payload 예시:

```json
{
  "examId": "exam_001",
  "attemptId": "attempt_123",
  "answers": [
    {
      "questionId": "card_001",
      "selectedChoiceId": "a"
    },
    {
      "questionId": "hotel_001",
      "selectedChoiceId": "c"
    }
  ]
}
```

#### `mockExam/main/users/{uid}/progress/{examId}`

회차별 진행/잠금/재도전 상태.

```json
{
  "examId": "exam_001",
  "unlocked": true,
  "completed": true,
  "attemptCount": 2,
  "bestScore": 85,
  "bestAttemptId": "attempt_456",
  "retryTickets": 1,
  "shareRewardGranted": true,
  "referredAttemptCount": 1,
  "unlockedAt": "serverTimestamp",
  "lastAttemptAt": "serverTimestamp",
  "lastSubmittedAt": "serverTimestamp"
}
```

잠금 해제, 재도전권, 최고 점수, 다음 회차 노출은 이 문서를 기준으로 판단한다.

#### `mockExam/main/leaderboards/{examId}/periods/{periodKey}/entries/{uid}`

회차/기간별 사용자 최고 기록. 랭킹 화면에서는 이 컬렉션을 점수순으로 조회한다.

기간 키 예시:

```text
all
week_2026_22
month_2026_05
```

예시 구조:

```json
{
  "uid": "user123",
  "examId": "exam_001",
  "periodKey": "all",
  "displayName": "마일헌터",
  "photoUrl": "https://...",
  "score": 95,
  "durationSeconds": 188,
  "attemptId": "attempt_123",
  "categoryScores": {
    "airline": 25,
    "card": 20,
    "giftcard": 25,
    "hotel": 25
  },
  "submittedAt": "2026-05-28T12:00:00Z",
  "updatedAt": "serverTimestamp"
}
```

정렬 기준:

```text
score desc
durationSeconds asc
submittedAt asc
```

Firestore는 복합 정렬 제한이 있으므로 실제 구현 시 인덱스가 필요하다. 사용자 수가 많아지면 Cloud Functions로 Top N 랭킹 요약 문서를 별도 생성하는 방식도 고려한다.

#### `mockExam/main/shares/{shareId}`

공유 링크 생성 기록. 공유 보상, 유입 추적, 딥링크 파라미터 복구에 사용한다.

```json
{
  "examId": "exam_001",
  "attemptId": "attempt_456",
  "ownerUid": "user123",
  "roundNo": 1,
  "score": 85,
  "shareUrl": "https://...",
  "campaign": "mock_exam_round_1",
  "createdAt": "serverTimestamp",
  "clickCount": 0,
  "completedReferralCount": 0
}
```

#### `mockExam/main/users/{uid}/shareRewards/{rewardId}`

공유 재도전권 지급 이력. 중복 지급 방지용이다.

```json
{
  "examId": "exam_001",
  "attemptId": "attempt_456",
  "shareId": "share_789",
  "rewardType": "retry_ticket",
  "amount": 1,
  "reason": "result_share",
  "createdAt": "serverTimestamp"
}
```

#### `mockExam/main/referrals/{referralId}`

친구가 공유 링크로 들어와 응시한 기록. 친구 응시 완료 보상을 줄 때 사용한다.

```json
{
  "examId": "exam_001",
  "shareId": "share_789",
  "referrerUid": "user123",
  "referredUid": "user999",
  "source": "branch",
  "campaign": "mock_exam_round_1",
  "openedAt": "serverTimestamp",
  "startedAt": "serverTimestamp",
  "submittedAt": "serverTimestamp",
  "rewardGranted": false
}
```

### 제출/채점 흐름

추천 서버 흐름:

```text
1. 사용자가 모의고사 시작
2. startMockExam Cloud Function 호출
3. mockExam/main/users/{uid}/attempts/{attemptId} 생성
4. 앱은 mockExam/main/exams/{examId}/questions를 읽어 문제 표시
5. 사용자가 답 선택 후 submitMockExam 호출
6. 서버가 mockExam/main/answerKeys/{examId}/questions를 읽어 채점
7. 서버가 attempt 문서에 점수/정답/해설 저장
8. 서버가 mockExam/main/users/{uid}/progress/{examId} 업데이트
9. 서버가 mockExam/main/leaderboards 업데이트
10. 조건 충족 시 다음 회차 progress 생성 또는 unlocked 처리
```

### Firestore 보안 규칙 방향

- `mockExam/main/exams`, `mockExam/main/exams/{examId}/questions`: 공개 읽기 가능
- `mockExam/main/answerKeys`: 클라이언트 읽기/쓰기 금지
- `mockExam/main/users/{uid}/attempts`: 본인 읽기 가능, 점수/정답 필드는 서버만 쓰기
- `mockExam/main/users/{uid}/progress`: 본인 읽기 가능, 핵심 상태는 서버만 쓰기
- `mockExam/main/users/{uid}/shareRewards`: 본인 읽기 가능, 서버만 쓰기
- `mockExam/main/leaderboards`: 공개 읽기 가능, 서버만 쓰기
- `mockExam/main/shares`: 생성은 서버 함수 경유 추천, 읽기는 필요한 범위만 허용
- `mockExam/main/referrals`: 서버만 쓰기 추천

## 12. 운영진 관리 기능

운영진이 관리해야 할 항목은 다음과 같다.

- 문제 등록
- 정답 설정
- 정답표 컬렉션 분리 저장
- 선택지 관리
- 해설 입력
- 이미지 연결
- 분야 분류
- 난이도 설정
- 문제 점수 설정
- 회차 생성
- 회차별 문제 편성
- 공개 여부
- 공개 시작/종료일
- 잠금 해제 조건
- 랭킹 집계 기간
- 재도전권 지급 정책
- 공유 문구/캠페인 설정
- Branch 링크 캠페인 설정
- 공유 보상 중복 지급 관리

운영진 도구가 없더라도 MVP에서는 JSON 또는 Firestore 수동 입력으로 시작할 수 있다. 이후 반복 운영이 많아지면 관리자 화면을 붙이는 것이 좋다.

## 13. Analytics 이벤트

딥링크와 랭킹형 콘텐츠는 퍼널 측정이 중요하다.

추천 이벤트:

| 이벤트 | 설명 |
| --- | --- |
| `mock_exam_view` | 모의고사 목록/상세 진입 |
| `mock_exam_start` | 응시 시작 |
| `mock_exam_submit` | 제출 완료 |
| `mock_exam_result_view` | 결과 화면 조회 |
| `mock_exam_explanation_view` | 오답/해설 조회 |
| `mock_exam_ranking_view` | 랭킹 조회 |
| `mock_exam_share_click` | 공유 버튼 클릭 |
| `mock_exam_share_reward_grant` | 공유 재도전권 지급 |
| `mock_exam_deep_link_open` | 공유 링크로 앱 진입 |
| `mock_exam_referral_submit` | 공유받은 사용자가 응시 제출 |
| `mock_exam_retry` | 재도전 시작 |
| `mock_exam_unlock` | 다음 회차 해제 |

필수 파라미터:

- `exam_id`
- `round_no`
- `score`
- `duration_seconds`
- `category`
- `rank_percentile`
- `source`
- `campaign`
- `referrer_uid`
- `attempt_id`
- `share_id`
- `retry_ticket_balance`

## 14. MVP 범위

첫 버전은 아래 범위로 충분하다.

- 4개 분야: 항공, 카드, 상품권, 호텔
- 분야별 5문제, 총 20문제
- 객관식 문제
- 이미지 표시
- 문제 표시용 컬렉션과 정답표 컬렉션 분리
- Cloud Function 기반 제출/채점
- 100점 만점 채점
- 분야별 점수 표시
- 결과 화면
- 오답/해설 보기
- 회차별 랭킹
- 주간 랭킹
- 공유 버튼
- Branch 딥링크를 통한 회차 진입
- 결과 공유 시 재도전권 1장 지급
- 공유 보상 중복 지급 방지
- 1회 공개, 2회 잠금 또는 오픈 예정 표시
- 1회 완료 시 2회 해제

초기에는 친구 랭킹을 완벽하게 만들기보다, 공유 링크로 들어온 사용자를 정확히 특정 회차로 보내고 결과 공유/재도전권 지급이 안정적으로 되는 것을 우선한다.

## 15. 2차 확장 기능

- 친구 랭킹
- 재도전권
- 친구 응시 완료 시 보상
- 오답노트
- 분야별 약점 분석
- 누적 랭킹
- 상위 퍼센트 표시 고도화
- 회차별 뱃지/칭호
- 고난도 스페셜 모의고사
- 오늘의 5문제
- 주간 챌린지
- 공유 이미지 카드 생성
- 카카오톡 공유 최적화

## 16. 추천 우선순위

### 1단계: 문제 풀이와 결과

- 회차 목록
- 응시 화면
- 제출/채점
- 결과 화면
- 오답/해설

### 2단계: 랭킹

- 회차별 랭킹
- 주간 랭킹
- 동점 처리
- 내 순위/상위 퍼센트

### 3단계: 공유와 딥링크

- 결과 공유 문구
- Branch 링크 생성
- 공유 재도전권 지급
- 딥링크 수신 후 회차 이동
- 공유 유입 Analytics

### 4단계: 회차 잠금과 재도전

- 1회 완료 시 2회 해제
- 오픈 예정 회차
- 재도전권
- 공유 보상

## 17. 제품 방향 요약

마일캐치 모의고사는 “학습용 퀴즈”보다 “랭킹형 챌린지”로 잡는 편이 좋다.

가장 강한 구조는 다음 조합이다.

```text
1회 공개
→ 점수/상위 퍼센트/랭킹 노출
→ 친구 공유
→ 딥링크로 친구 유입
→ 공유 또는 완료로 다음 회차 해제
→ 재도전권으로 점수 갱신
→ 회차별/주간 랭킹으로 반복 참여
```

사용자에게는 “내가 얼마나 잘 아는지 확인하는 재미”를 주고, 운영진에게는 “계속 열 수 있는 회차형 콘텐츠”를 주며, 제품에는 “공유를 통한 신규 유입 루프”를 만든다.

초기 구현의 핵심은 많은 기능을 한 번에 넣는 것이 아니라, 결과 화면에서 사용자가 바로 공유하고 싶을 만큼 점수와 랭킹을 매력적으로 보여주는 것이다.
