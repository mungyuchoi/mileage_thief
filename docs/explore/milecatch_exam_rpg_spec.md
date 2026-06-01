# 마일고사 RPG 학습 시스템 강화 기획서

작성일: 2026-05-29
업데이트: 2026-05-30

## 1. 한 줄 정의

마일고사 RPG는 사용자가 마일리지, 호텔 포인트, 카드 포인트, 상품권 지식을 "시험"으로만 확인하는 것이 아니라, 듀오링고처럼 분야를 고르고 짧은 레슨을 한 문제씩 진행하면서 실전 판단력을 키우는 학습형 게임 시스템이다.

```text
분야/과정을 고른다
-> 레슨 노드를 선택한다
-> 한 화면에 한 문제씩 푼다
-> 즉시 피드백을 받는다
-> 땅콩/경험치/배지를 받는다
-> 다음 레슨 노드가 열린다
```

## 2. 현재 마일고사의 위치

현재 구현된 마일고사는 이미 좋은 게임 재료를 갖고 있다.

- 회차형 문제 목록이 있다.
- 서버 채점과 정답표 분리가 되어 있다.
- 점수, 분야별 점수, 풀이 시간, 랭킹이 있다.
- 첫 응시 땅콩 보상과 재도전권 구매가 있다.
- Branch 공유 링크와 공유 보상이 있다.

따라서 다음 단계의 핵심은 문제 엔진을 갈아엎는 것이 아니라, 기존 `mockExam`을 "보스전/인증전"으로 유지하고 그 앞단에 듀오링고형 스텝 학습 레이어를 추가하는 것이다.

## 2-0. 구현 방향 결정

UI는 웹뷰가 아니라 Flutter 네이티브 앱으로 구현한다.

```text
Flutter 네이티브 화면
-> Firestore 레슨 데이터 로드
-> 문제 타입별 Flutter 위젯 렌더링
-> Cloud Functions 제출/채점/보상
```

학습 원천 데이터는 스사사/뉴스사사 크롤링 JSON을 사용하되, 앱에서 원문 JSON을 직접 보여주지 않는다. 원천 JSON은 RAG 파이프라인에서 정제하고, 검수된 결과만 레슨/문제 데이터로 Firestore에 배포한다.

```text
스사사/뉴스사사 크롤링 JSON
-> 정제/익명화
-> 청크화
-> 임베딩/RAG
-> 레슨 초안 생성
-> 운영자 검수
-> Firestore publish
-> Flutter 앱 표시
```

첫 MVP에서 RAG는 앱 런타임 기능이 아니라 콘텐츠 제작 도구로 둔다. 이렇게 해야 속도, 비용, 정답 품질, 개인정보/저작권 리스크를 통제하기 쉽다.

## 2-1. 듀오링고식 화면에서 가져올 패턴

사용자가 제공한 듀오링고 스크린샷에서 참고할 핵심 패턴은 아래와 같다.

| 패턴 | 마일고사 적용 |
| --- | --- |
| 상단 과정 선택 | `호텔`, `항공`, `상품권`, `카드`, `과정 추가` |
| 과정별 아이콘 | `Marriott`, `대한항공`, `상품권 계산`, `카드 포인트` |
| 세로 레슨 노드 | 등급 마을, 포인트 광산, 숙박권 동굴을 원형 노드로 표시 |
| 잠긴 보상/상자 | 특정 레슨 완료 후 보상 상자 오픈 |
| 한 화면 한 문제 | 선택, 드래그, 빈칸 채우기, 수치 슬라이더, 카드 매칭 |
| 상단 진행 바 | 레슨 내 진행도와 남은 하트/에너지 표시 |
| 콤보/연속 정답 | 연속 정답 보너스와 빠른 완료 보너스 |
| 즉시 피드백 | 정답이면 초록 하단 패널, 오답이면 다시 생각하게 유도 |
| 결과 화면 | XP, 콤보, 소요 시간, 땅콩 보상을 카드로 표시 |

이 방향으로 가면 "월드맵을 보는 재미"보다 "짧은 문제를 계속 풀고 싶어지는 리듬"이 강해진다. 첫 MVP는 과한 지도형 연출보다 듀오링고식 과정/레슨 구조를 우선한다.

## 3. 제품 철학

사용자는 "공부"를 하러 들어오지 않는다. 사용자는 아래와 같은 실전 이득을 원한다.

- 대한항공 마일을 더 잘 쓰고 싶다.
- Marriott 포인트와 숙박권을 손해 보지 않고 쓰고 싶다.
- 상품권/카드 포인트로 실제 절약을 만들고 싶다.
- 호텔 등급 혜택을 여행에서 제대로 누리고 싶다.

그래서 정보 나열보다 상황 기반 흐름이 먼저 와야 한다.

```text
정보 -> 문제
```

보다

```text
실전 상황 -> 필요한 정보 -> 판단 훈련 -> 문제 -> 보상
```

이 더 강하다.

## 4. 핵심 루프

### 짧은 루프: 1~3분

```text
레슨 노드 선택
-> 문제 1개 풀이
-> 즉시 정답/오답 피드백
-> 다음 문제
-> 레슨 완료
-> XP/땅콩/콤보 보상
```

목표는 "앱을 켰을 때 부담 없이 하나만 하고 나가기"다.

### 중간 루프: 10~20분

```text
과정 안의 여러 레슨 완료
-> 다음 섹션 오픈
-> 보상 상자 오픈
-> 마스터 인증 오픈
-> 배지 획득
```

목표는 "오늘 Marriott 과정의 등급 파트를 끝냈다"는 성취감이다.

### 긴 루프: 주간/월간

```text
분야/과정별 숙련도 상승
-> 마스터 인증 도전
-> 랭킹/친구 비교
-> 신규 과정 업데이트 대기
```

목표는 "마일리지 업계의 듀오링고"에 가까운 반복 방문이다.

## 5. 정보 구조

```text
Explore Home
-> Domain
-> Course
-> Section
-> Lesson Node
-> Lesson Item
-> Feedback
-> Reward
-> Boss Exam
```

### Explore Home

듀오링고의 과정 선택 화면과 비슷한 역할을 한다. 첫 화면은 "마일고사 회차 목록"이 아니라 사용자가 배울 분야/과정을 고르는 화면이다.

- 상단 보유 상태: 땅콩, 연속 학습일, 에너지/하트, XP
- 주요 분야: 호텔, 항공, 상품권, 카드
- 열린 과정: Marriott, 대한항공, 상품권 계산 등
- 준비 중 과정: Hilton, Hyatt, ANA, IHG 등
- 추천 과정: 사용자의 보유 포인트/관심 분야 기반
- 현재 위치: 마지막 진행 과정과 레슨 노드

### Domain

큰 분야다.

예시:

- `hotel`: 호텔 포인트/등급/숙박권
- `airline`: 항공 마일/좌석/발권
- `giftcard`: 상품권 할인율/매입가/실질 수익
- `card_points`: 카드 포인트/실적/전환

초기 대주제는 [category_taxonomy.md](category_taxonomy.md)를 기준으로 `호텔`, `항공`, `카드/포인트`, `상품권` 4개만 둔다.

### Course

분야 안에 들어가는 학습 과정이다. UI에서는 과정 카드나 월드처럼 보여줄 수 있다.

예시:

- `marriott_basics`: Marriott 포인트/등급/숙박권
- `korean_air_basics`: 대한항공 마일/좌석/가족합산/발권
- `giftcard_math`: 상품권 할인율/실질 구매가/매입가 계산
- `card_points_basics`: 카드 포인트 적립/전환/실적

초기 과정 우선순위는 아래와 같다.

1. `호텔 > Marriott`
2. `상품권 > 상품권 기초/계산`
3. `항공 > 대한항공 기초`
4. `카드/포인트 > 카드 기초`

### Section

과정 안의 묶음이다. 듀오링고의 `산수 2`, `숫자 감각 키우기` 같은 단위와 비슷하다.

예시:

```text
Marriott 기초
-> 등급 이해하기
-> 포인트 가치 계산하기
-> 숙박권 판단하기
-> 예약 조합하기
```

### Lesson Node

사용자가 실제로 누르는 원형 노드다. 기존 문서의 `Stage`에 해당하지만, 이제는 더 작고 반복 가능한 레슨 단위로 본다.

레슨 상태:

| 상태 | 의미 |
| --- | --- |
| `locked` | 아직 진입 불가 |
| `unlocked` | 진입 가능 |
| `in_progress` | 시작했지만 완료하지 않음 |
| `completed` | 1회 완료 |
| `mastered` | 만점/콤보/복습 조건까지 달성 |

### Lesson Item

레슨 안에서 한 화면에 하나씩 나오는 문제 또는 학습 카드다.

예시:

- 설명 카드
- 객관식 선택
- OX
- 카드 매칭
- 순서 배열
- 빈칸 채우기
- 숫자 입력
- 수치 슬라이더
- 호텔 조건 비교
- 예약 조합 선택

### Boss Exam

과정 마지막의 검증 단계다. 새 엔진을 만들기보다 기존 `mockExam` 회차를 연결한다.

예시:

```text
Marriott 과정 레슨 노드 완료
-> Marriott 마스터 인증 오픈
-> mockExam exam_marriott_master 응시
-> 점수/시간 랭킹 반영
```

## 6. 첫 화면 설계

초기 화면은 듀오링고의 과정 선택 화면처럼 구성한다. 사용자가 "몇 회차를 풀까"보다 "어떤 분야를 배울까"라고 느끼게 하는 것이 핵심이다.

```text
상단 상태바
땅콩 320 | 연속 2일 | XP 593 | 에너지 18

분야 탭
[호텔] [항공] [상품권] [카드] [+ 과정]

내 과정
[Marriott] 진행중 2/7
[대한항공] 시작하기
[상품권 계산] 준비중

신규 과정
[Hilton] 준비중
[Hyatt] 준비중
[ANA] 준비중
```

과정 카드에 표시할 정보:

- 과정 이름
- 분야
- 진행률
- 현재 레슨
- 완료 레슨 수
- 획득 배지
- 보상 가능 여부
- 잠금 조건

## 7. 듀오링고형 학습 템플릿

모든 레슨은 같은 뼈대를 갖는다. 운영자는 문제 타입과 콘텐츠만 바꾸고, UI와 데이터 구조는 재사용한다.

| 순서 | 블록 | 목적 |
| ---: | --- | --- |
| 1 | 브리핑 | 이번 레슨에서 풀 상황 제시 |
| 2 | 개념 카드 | 외워야 할 정보가 아니라 판단 기준 제공 |
| 3 | 인터랙션 문제 | 한 화면에 한 문제씩 풀이 |
| 4 | 즉시 피드백 | 정답/오답 이유를 바로 제공 |
| 5 | 반복 문제 | 같은 개념을 다른 형식으로 재확인 |
| 6 | 결과 화면 | XP, 콤보, 시간, 땅콩 보상 |
| 7 | 다음 노드 오픈 | 다음 레슨/보상 상자/인증으로 연결 |

지원할 블록 타입:

| 타입 | 예시 |
| --- | --- |
| `scenario` | "가족 4명이 오사카 여행을 간다." |
| `concept_card` | 등급/포인트/숙박권 핵심 개념 |
| `flip_card` | 앞면 질문, 뒷면 답 |
| `compare` | 현금 예약 vs 포인트 예약 비교 |
| `choice` | 가장 유리한 선택 고르기 |
| `ox` | OX 판단 |
| `single_choice` | 객관식 1개 선택 |
| `multi_select` | 해당되는 혜택 모두 선택 |
| `match_pair` | 등급과 혜택 연결 |
| `order_steps` | 예약 판단 순서 배열 |
| `fill_blank` | "현금가 ÷ 포인트 = 1포인트 가치" 빈칸 채우기 |
| `number_input` | 포인트 가치 직접 입력 |
| `slider` | 수치선에서 적정 가치 표시 |
| `mini_quiz` | 3~7문항으로 구성된 짧은 레슨 |
| `case_quiz` | 실전 조건 기반 문제 |
| `recap` | 핵심만 요약 |
| `reward` | 땅콩/XP/배지 지급 |

### 레슨 화면 공통 UI

레슨 화면은 듀오링고처럼 몰입형으로 구성한다.

- 상단 왼쪽: 닫기 버튼
- 상단 중앙: 레슨 진행 바
- 상단 오른쪽: 에너지/하트 또는 땅콩
- 중앙: 문제 또는 인터랙션
- 하단: `확인` 버튼
- 정답 후: 초록 피드백 패널과 `계속` 버튼
- 오답 후: 빨간/주황 피드백 패널과 짧은 힌트

### 결과 화면 공통 UI

레슨 완료 후에는 별도 결과 화면을 보여준다.

| 카드 | 의미 |
| --- | --- |
| `총 XP` | 레슨 완료 경험치 |
| `콤보` | 연속 정답 수 |
| `최고속` | 가장 빠른 완료 시간 또는 이번 소요 시간 |
| `땅콩` | 최초 완료/만점 보상 |

## 7-1. RAG 기반 콘텐츠 생성 원칙

스사사/뉴스사사 글은 실제 사용자 고민이 많기 때문에 레슨의 "상황 카드"와 "실전 문제"를 만들기 좋다. 다만 원문을 그대로 학습 화면에 넣지 않고 아래처럼 재구성한다.

| 원천 데이터 | 레슨 전환 |
| --- | --- |
| 질문 글 | `scenario`, `case_quiz` |
| 댓글 답변 | `concept_card`, `feedback`, `recap` |
| 반복 질문 | `lesson topic`, `FAQ` |
| 계산 사례 | `fill_blank`, `number_input`, `slider` |
| 선택 고민 | `single_choice`, `multi_select`, `order_steps` |

RAG가 만든 콘텐츠는 항상 아래 필드를 남긴다.

- `sourceChunkIds`: 어떤 청크에서 나온 초안인지
- `reviewStatus`: `draft`, `needs_review`, `approved`, `rejected`
- `reviewedBy`: 검수자
- `reviewedAt`: 검수 시각
- `officialCheckRequired`: 공식 규정 검수 필요 여부
- `contentRisk`: 개인정보/규정/저작권 리스크 메모

## 8. 잠금/장애물 시스템

장애물은 단순 장식이 아니라 사용자의 "모르는 지점"을 시각화한 것이다. 다만 첫 MVP에서는 큰 지도 장애물보다 듀오링고식 `잠긴 노드`, `잠긴 보상 상자`, `다음 섹션`으로 표현하는 편이 구현과 이해가 쉽다.

예시:

| 장애물 | 사용자의 막힘 | 해결 방식 |
| --- | --- | --- |
| 등급의 벽 | 플래티넘이 왜 중요한지 모름 | 등급 레슨 완료 |
| 포인트 광산 입구 | 포인트 가치 계산을 못함 | 가치 비교 문제 통과 |
| 숙박권의 문 | 숙박권 한도/사용처 판단이 어려움 | 숙박권 레슨 완료 |
| 예약 미궁 | 언제 포인트 예약이 유리한지 모름 | 예약 케이스 문제 통과 |
| 고수의 성문 | 여러 규칙을 조합하지 못함 | 보스 퀴즈 기준 점수 달성 |

장애물 제거 조건은 세 단계로 나눈다.

- `learn`: 학습 블록을 끝내면 제거
- `score`: 미니 퀴즈 기준 점수 이상이면 제거
- `spend`: 선택형 지름길만 땅콩으로 제거

핵심 학습은 땅콩으로 막지 않는 것을 추천한다. 땅콩은 지름길, 재도전, 꾸미기, 고급 콘텐츠에 쓰는 편이 건강하다.

## 9. 보상 경제

현재 마일고사는 첫 응시 제출 보상 `100` 땅콩, 재도전권 구매 `50` 땅콩 구조를 갖고 있다. RPG 학습에서는 보상 규모를 더 작게 잡아야 한다.

추천 보상:

| 행동 | 보상 |
| --- | ---: |
| 레슨 최초 완료 | 5~15 땅콩 |
| 레슨 만점/무오답 | 추가 5~10 땅콩 |
| 섹션 완료 | 20~40 땅콩 |
| 보스 인증 최초 완료 | 100 땅콩 또는 특별 배지 |
| 일일 복습 | 3~5 땅콩 |

추가 성장 재화:

- `exploreXp`: 과정 성장/레벨에 사용
- `badges`: 인증과 자랑에 사용
- `cosmetics`: 땅콩 스킨, 배경 테마, 타이틀

땅콩 사용처:

| 사용처 | 추천 여부 | 이유 |
| --- | --- | --- |
| 재도전권 | 높음 | 이미 구현되어 있고 랭킹과 연결됨 |
| 스킨/테마 | 높음 | 경제 밸런스에 안전함 |
| 고급 퀴즈 오픈 | 중간 | 핵심 학습을 막지 않는 선에서 사용 |
| 필수 레슨 입장 | 낮음 | 신규 사용자 이탈 가능 |
| 장애물 지름길 | 중간 | 선택형이면 재미 요소가 됨 |

## 10. 랭킹 구조

기존 마일고사 랭킹은 유지한다. 레슨형 랭킹은 바로 MVP에 넣기보다 과정 데이터가 쌓인 뒤 추가한다.

추천 순서:

1. 기존 `mockExam` 회차 랭킹 유지
2. 과정별 마스터 인증 랭킹 추가
3. 주간 Explore XP 랭킹 추가
4. 친구 과정 진행률 비교 추가

랭킹 지표 후보:

- 보스 퀴즈 점수
- 보스 퀴즈 풀이 시간
- 과정 완료율
- 주간 획득 XP
- 배지 수

## 11. 데이터 모델 초안

기존 `mockExam/main`과 분리해 `explore/main` 루트를 둔다. 학습 진행과 퀴즈 채점 책임이 달라지기 때문이다.

```text
explore/main/domains/{domainId}
explore/main/courses/{courseId}
explore/main/courses/{courseId}/sections/{sectionId}
explore/main/courses/{courseId}/lessons/{lessonId}
explore/main/courses/{courseId}/lessons/{lessonId}/items/{itemId}

explore/main/users/{uid}/courseProgress/{courseId}
explore/main/users/{uid}/lessonProgress/{lessonId}
explore/main/users/{uid}/lessonAttempts/{attemptId}
explore/main/users/{uid}/badges/{badgeId}
explore/main/users/{uid}/inventory/{itemId}

explore/main/leaderboards/{leaderboardId}/periods/{periodKey}/entries/{uid}
```

### `domains/{domainId}`

```json
{
  "title": "호텔",
  "subtitle": "호텔 등급, 포인트, 숙박권을 배웁니다",
  "status": "published",
  "sortOrder": 10,
  "icon": "hotel",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### `courses/{courseId}`

```json
{
  "domainId": "hotel",
  "title": "Marriott",
  "subtitle": "포인트와 숙박권으로 호텔을 정복하는 길",
  "status": "published",
  "sortOrder": 10,
  "heroAsset": "asset/icon/icon_marriott.svg",
  "bossExamId": "exam_marriott_master",
  "sectionCount": 4,
  "lessonCount": 18,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### `sections/{sectionId}`

```json
{
  "courseId": "marriott_basics",
  "title": "등급 이해하기",
  "subtitle": "조식, 라운지, 체크아웃 혜택을 실제 비용으로 봅니다",
  "order": 1,
  "status": "published",
  "unlockRule": {
    "type": "course_start"
  },
  "reward": {
    "peanuts": 30,
    "xp": 300,
    "badgeId": null
  }
}
```

### `lessons/{lessonId}`

```json
{
  "sectionId": "marriott_tier",
  "title": "등급 마을",
  "subtitle": "호텔 등급 혜택의 기준을 잡는다",
  "order": 1,
  "status": "published",
  "unlockRule": {
    "type": "course_start"
  },
  "obstacle": {
    "id": "tier_wall",
    "title": "등급의 벽",
    "clearRule": "complete_lesson"
  },
  "reward": {
    "peanuts": 10,
    "xp": 100,
    "badgeId": null
  },
  "lessonConfig": {
    "itemCount": 6,
    "passScore": 5,
    "energyCost": 1,
    "allowMistakes": 2
  }
}
```

### `items/{itemId}`

```json
{
  "type": "scenario",
  "order": 1,
  "title": "가족 여행 예약을 앞둔 상황",
  "body": "호텔 포인트가 있는데 현금 예약과 포인트 예약 중 무엇이 유리할지 판단해야 한다.",
  "payload": {}
}
```

문제형 아이템 예시:

```json
{
  "type": "single_choice",
  "order": 3,
  "prompt": "가족 4명이 3박을 할 때 조식 혜택의 가치는 언제 커질까요?",
  "choices": [
    {"id": "a", "text": "혼자 1박할 때"},
    {"id": "b", "text": "인원수와 숙박일수가 많을 때"},
    {"id": "c", "text": "조식을 먹지 않을 때"}
  ],
  "answer": {
    "correctChoiceIds": ["b"],
    "explanation": "조식 혜택은 인원수와 숙박일수가 늘수록 현금 가치가 커집니다."
  },
  "xp": 15
}
```

### `lessonProgress/{lessonId}`

```json
{
  "courseId": "marriott_basics",
  "sectionId": "marriott_tier",
  "lessonId": "marriott_tier_village_01",
  "status": "completed",
  "bestScore": 6,
  "bestCombo": 6,
  "bestDurationSeconds": 69,
  "attemptCount": 1,
  "rewardGranted": true,
  "completedAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

보상 지급은 클라이언트 단독 업데이트가 아니라 Cloud Functions에서 처리해야 한다. 사용자가 클라이언트 데이터를 조작해 땅콩을 반복 수령하는 것을 막기 위해서다.

## 12. 기존 `mockExam`과의 연결

`Explore`는 짧은 학습/반복 문제, `mockExam`은 공식 시험/랭킹을 담당한다.

연결 방식:

- `courses/{courseId}.bossExamId`에 기존 마일고사 회차 ID를 저장한다.
- 과정 마지막 섹션 완료 시 해당 회차 응시 버튼을 노출한다.
- 보스 시험 결과는 기존 `mockExam/main/users/{uid}/progress/{examId}`를 사용한다.
- 과정 진행률에는 보스 시험 완료 여부만 복사/참조한다.

장점:

- 서버 채점과 랭킹을 재사용한다.
- 정답표 보안 구조를 유지한다.
- 기존 회차형 콘텐츠와 새 레슨형 콘텐츠가 서로 먹고 들어간다.

## 13. 화면 설계

### Explore Home

필수 요소:

- 상단: 내 땅콩, 연속 학습일, XP, 에너지/하트
- 본문 상단: 분야 탭 또는 과정 아이콘
- 본문: 내 과정, 신규 과정, 준비 중 과정
- 하단: 현재 레슨 카드, 최근 획득 배지

Flutter 구현 단위:

- `ExploreHomeScreen`
- `ExploreStatusBar`
- `DomainTabBar`
- `CourseTileGrid`
- `ContinueLessonCard`

### Course Detail

필수 요소:

- 과정 제목과 진행률
- 섹션 제목
- 세로 레슨 노드 경로
- 현재 위치
- 잠긴 노드 조건
- 보상 상자
- 보스 인증 카드

Flutter 구현 단위:

- `CourseDetailScreen`
- `CourseHeader`
- `SectionHeader`
- `LessonPath`
- `LessonNode`
- `RewardChestNode`
- `BossExamNode`

### Lesson Screen

필수 요소:

- 닫기 버튼
- 레슨 진행 바
- 에너지/하트
- 문제 본문
- 인터랙션 위젯
- 확인 버튼
- 정답/오답 피드백 패널

Flutter 구현 단위:

- `LessonScreen`
- `LessonProgressBar`
- `LessonItemRenderer`
- `AnswerInput`
- `LessonFeedbackSheet`

### Lesson Result

필수 요소:

- 획득 땅콩
- 획득 XP
- 콤보
- 소요 시간
- 새로 열린 노드
- 다음 레슨 버튼
- 복습/다시 풀기 버튼

## 14. 분석 이벤트

추천 Analytics 이벤트:

| 이벤트 | 주요 파라미터 |
| --- | --- |
| `explore_home_view` | `source` |
| `explore_domain_select` | `domain_id` |
| `explore_course_open` | `course_id`, `domain_id`, `status` |
| `explore_lesson_start` | `course_id`, `section_id`, `lesson_id` |
| `explore_item_view` | `lesson_id`, `item_type`, `order` |
| `explore_item_submit` | `lesson_id`, `item_id`, `is_correct`, `duration_seconds` |
| `explore_lesson_complete` | `lesson_id`, `score`, `combo`, `reward_peanuts`, `reward_xp` |
| `explore_node_unlock` | `course_id`, `lesson_id`, `unlock_type` |
| `explore_boss_exam_open` | `course_id`, `exam_id` |

봐야 할 지표:

- 분야 선택률
- 과정 진입률
- 첫 레슨 완료율
- 레슨별 이탈 지점
- 문제 타입별 오답률
- 레슨 재시도율
- 보스 시험 전환율
- 보스 시험 완료율
- 완료 후 공유율

## 15. 구현 로드맵

### Phase 0. 문서/콘텐츠 정리

- 분야/과정/섹션/레슨 데이터 구조 확정
- Marriott 과정 MVP 원고 작성
- 기존 `mockExam` 회차 중 보스 시험으로 쓸 회차 선정

### Phase 1. 과정 홈 MVP

- `ExploreHomeScreen` 추가
- 분야 탭과 과정 카드 UI 추가
- `호텔 > Marriott` 과정만 published, 나머지는 coming soon 처리
- Firestore `explore/main/domains`, `explore/main/courses` 읽기

### Phase 2. 레슨 경로 MVP

- `CourseDetailScreen` 추가
- 세로 `LessonPath`와 `LessonNode` 추가
- 완료/진행중/잠금/보상 상자 노드 상태 지원

### Phase 3. 레슨 풀이 MVP

- `LessonScreen` 추가
- `scenario`, `concept_card`, `single_choice`, `multi_select`, `match_pair`, `fill_blank`, `number_input`, `recap` 아이템 지원
- 정답/오답 즉시 피드백 패널 추가
- 레슨 완료와 보상 지급 Cloud Function 추가

### Phase 4. 보스 시험 연결

- 과정 완료 조건에서 기존 `mockExam` 회차 오픈
- 보스 시험 결과를 과정 진행률에 표시
- 보스 완료 배지 지급

### Phase 5. 반복 방문 강화

- 일일 복습
- 오답 기반 추천 레슨
- 과정별 배지/타이틀
- 과정별 친구 비교
- 콤보/연속 학습일/에너지 시스템

## 16. MVP 성공 기준

초기 MVP는 수익화보다 "이 흐름이 진짜 재미있는지"를 검증한다.

- Explore Home 진입 사용자 중 60% 이상이 첫 레슨 시작
- 첫 레슨 시작 사용자 중 50% 이상이 완료
- Marriott 과정 시작 사용자 중 25% 이상이 보스 시험 진입
- 보스 시험 완료자 중 20% 이상이 결과 공유 또는 랭킹 확인
- 기존 단순 마일고사 대비 재방문율 상승

## 17. 주의할 점

- 실제 프로그램 규정은 자주 바뀐다. Marriott, 항공사, 카드 혜택 등은 배포 전 공식 자료 기준으로 운영 검수가 필요하다.
- 땅콩 보상은 과하게 풀면 기존 경제가 흔들릴 수 있다.
- 레슨이 길어지면 피로도가 높다. 첫 버전은 5~7개 아이템 안에서 끝내는 편이 좋다.
- 잠금이 많으면 이탈한다. 첫 과정의 앞쪽 2~3개 레슨은 쉽게 열어두는 편이 좋다.
- 정답/해설 보안이 필요한 퀴즈는 반드시 서버 채점을 유지한다.

## 18. 결정이 필요한 질문

- 첫 과정은 Marriott로 확정할지, 대한항공과 동시에 열지
- 첫 화면을 분야 탭형으로 만들지, 과정 카드형으로 만들지
- 레슨 완료 보상 땅콩을 몇 개로 시작할지
- 보스 시험을 기존 20문항 회차로 둘지, 과정 전용 10문항으로 만들지
- 캐릭터 이름을 `땅콩`으로 고정할지, 사용자가 선택하게 할지
