# Marriott 과정 MVP 설계

작성일: 2026-05-29
업데이트: 2026-05-30

이 문서는 마일고사 RPG의 첫 과정 후보인 `호텔 > Marriott`를 듀오링고형 스텝 학습으로 구현하기 위한 초안이다. 기존 "월드맵 탐험"보다 `분야 선택 -> 과정 선택 -> 세로 레슨 노드 -> 한 문제씩 풀이 -> 즉시 피드백 -> 결과 보상` 흐름을 우선한다.

프로그램 규정, 등급 혜택, 숙박권 조건 등은 변동 가능성이 있으므로 배포 전 공식 자료 기준으로 운영 검수가 필요하다.

## 1. 과정 컨셉

```text
호텔 분야에서 Marriott 과정을 선택한다.
사용자는 짧은 레슨 노드를 하나씩 완료하며
등급, 포인트, 숙박권, 예약 판단을 익힌다.
마지막에는 Marriott 마스터 인증을 본다.
```

사용자가 배워야 할 것은 세부 규정 암기가 아니라 "언제 이득이고, 언제 손해인지 판단하는 기준"이다.

## 2. 홈에서 보이는 구조

듀오링고 스크린샷처럼 첫 화면은 과정 선택형으로 구성한다.

```text
상단 상태
땅콩 320 | 연속 2일 | XP 593 | 에너지 18

분야 탭
[호텔] [항공] [상품권] [카드] [+ 과정]

호텔 과정
[Marriott] 진행중 2/18
[Hilton] 준비중
[Hyatt] 준비중
[IHG] 준비중
```

`Marriott`를 누르면 과정 상세로 들어가고, 과정 상세는 세로 레슨 노드 경로를 보여준다.

## 2-1. 구현/콘텐츠 원칙

- 화면은 웹뷰 없이 Flutter 네이티브로 구현한다.
- Marriott 레슨 데이터는 Firestore 또는 번들 JSON에서 읽는다.
- 스사사/뉴스사사 크롤링 JSON은 앱에 직접 노출하지 않는다.
- 크롤링 JSON은 RAG로 정제해 레슨 초안, 상황 카드, 문제 아이템을 만드는 데 사용한다.
- RAG가 만든 레슨은 운영자 검수 후 `published` 상태로 배포한다.

## 3. 과정 메타데이터 초안

```json
{
  "courseId": "marriott_basics",
  "domainId": "hotel",
  "title": "Marriott",
  "subtitle": "포인트와 숙박권으로 호텔을 정복하는 길",
  "status": "published",
  "sortOrder": 10,
  "heroAsset": "asset/icon/icon_marriott.svg",
  "bossExamId": "exam_marriott_master",
  "sectionCount": 4,
  "lessonCount": 18,
  "reward": {
    "completionPeanuts": 100,
    "completionXp": 1000,
    "badgeId": "badge_marriott_master"
  }
}
```

## 4. 섹션/레슨 경로

```text
Marriott 기초
-> 등급 이해하기
   -> 등급 마을 1
   -> 조식과 라운지
   -> 레이트 체크아웃
   -> 등급 혜택 복습 상자

포인트 가치 계산
-> 포인트 광산 1
-> 현금가 vs 포인트
-> 1포인트 가치 계산
-> 포인트 가치 복습 상자

숙박권 판단
-> 숙박권 동굴 1
-> 만료일과 사용 우선순위
-> 숙박권 사용처 고르기

예약 조합
-> 예약 미궁 1
-> 5박/성수기/가족 여행 케이스
-> Marriott 성
-> Marriott 마스터 인증
```

## 5. 레슨 노드 상태

| 상태 | UI 표현 | 의미 |
| --- | --- | --- |
| 완료 | 초록 체크 노드 | 보상 수령 완료 |
| 진행중 | 금색 별 노드 | 이어서 풀 위치 |
| 입장 가능 | 컬러 노드 | 바로 시작 가능 |
| 잠금 | 회색/구름 노드 | 이전 레슨 완료 필요 |
| 보상 상자 | 상자 노드 | 섹션 중간 보상 |
| 인증 | 성/트로피 노드 | 기존 `mockExam`으로 연결 |

## 6. Lesson 1: 등급 마을 1

### 목표

사용자가 호텔 등급을 "멋있는 이름"이 아니라 실제 여행 비용과 경험에 영향을 주는 조건으로 이해한다.

### 사용자 상황

```text
가족과 일본 3박 여행을 준비 중이다.
현금가는 비슷한 호텔이 여러 개 있다.
어떤 호텔은 조식이 유료이고,
어떤 호텔은 등급 혜택으로 조식/라운지/늦은 체크아웃이 가능하다.
어떤 선택이 진짜 이득인지 판단해야 한다.
```

### 레슨 구성

듀오링고처럼 한 화면에 하나씩 진행한다.

| 순서 | 아이템 타입 | 화면 목적 | 예시 |
| ---: | --- | --- | --- |
| 1 | `scenario` | 오늘의 상황 제시 | 가족 일본 3박 여행 브리핑 |
| 2 | `concept_card` | 핵심 개념 1개 전달 | 등급 혜택은 실제 비용을 바꾼다 |
| 3 | `single_choice` | 첫 판단 문제 | 조식 혜택 가치가 커지는 상황 선택 |
| 4 | `match_pair` | 혜택 연결 | 조식-식비 절감, 라운지-간식/음료, 레이트 체크아웃-마지막 날 여유 |
| 5 | `multi_select` | 필요한 혜택 고르기 | 가족 여행에서 볼 혜택 모두 선택 |
| 6 | `case_quiz` | 실전 판단 | 현금가가 비슷할 때 어떤 호텔이 유리한가 |
| 7 | `recap` | 요약 | 등급은 이름이 아니라 이번 여행에서 쓸 혜택으로 판단 |
| 8 | `reward` | 완료 보상 | XP, 콤보, 소요 시간, 땅콩 |

### 레슨 결과

```text
등급 마을 1 완료
총 XP 25
콤보 x6
소요 시간 1:09
+10 땅콩
```

## 7. Lesson 1 문제 아이템 예시

### `single_choice`

```json
{
  "type": "single_choice",
  "prompt": "가족 4명이 3박을 할 때 조식 혜택의 가치가 가장 커지는 상황은?",
  "choices": [
    {"id": "a", "text": "혼자 1박만 할 때"},
    {"id": "b", "text": "인원수와 숙박일수가 많을 때"},
    {"id": "c", "text": "조식을 먹지 않는 일정일 때"}
  ],
  "answer": {
    "correctChoiceIds": ["b"],
    "explanation": "조식 혜택은 인원수와 숙박일수가 늘수록 현금 절감 효과가 커집니다."
  }
}
```

### `match_pair`

```json
{
  "type": "match_pair",
  "prompt": "등급 혜택과 실제 가치를 연결하세요.",
  "leftItems": [
    {"id": "breakfast", "text": "조식"},
    {"id": "lounge", "text": "라운지"},
    {"id": "late_checkout", "text": "레이트 체크아웃"}
  ],
  "rightItems": [
    {"id": "food_cost", "text": "식비 절감"},
    {"id": "snack_drink", "text": "간식/음료 가치"},
    {"id": "last_day", "text": "마지막 날 일정 여유"}
  ],
  "answer": {
    "pairs": {
      "breakfast": "food_cost",
      "lounge": "snack_drink",
      "late_checkout": "last_day"
    }
  }
}
```

### `multi_select`

```json
{
  "type": "multi_select",
  "prompt": "가족 여행에서 등급 혜택을 평가할 때 확인할 항목을 모두 고르세요.",
  "choices": [
    {"id": "breakfast", "text": "조식 포함 여부"},
    {"id": "people", "text": "동행 인원수"},
    {"id": "nights", "text": "숙박일수"},
    {"id": "logo", "text": "호텔 로고 색상"}
  ],
  "answer": {
    "correctChoiceIds": ["breakfast", "people", "nights"],
    "explanation": "등급 혜택은 이번 여행에서 실제로 쓸 수 있는 혜택인지가 중요합니다."
  }
}
```

### `case_quiz`

```json
{
  "type": "case_quiz",
  "prompt": "두 호텔의 현금가가 비슷합니다. 가족 4명, 3박, 조식을 매일 먹는 일정이라면 어떤 판단이 좋을까요?",
  "case": {
    "hotelA": "조식 유료, 라운지 없음",
    "hotelB": "등급 혜택으로 조식 가능"
  },
  "choices": [
    {"id": "a", "text": "호텔 A가 무조건 유리하다"},
    {"id": "b", "text": "호텔 B의 조식 가치를 현금가에 더해 비교한다"},
    {"id": "c", "text": "등급 이름만 보고 결정한다"}
  ],
  "answer": {
    "correctChoiceIds": ["b"],
    "explanation": "현금가가 비슷하면 실제로 쓸 수 있는 혜택 가치까지 계산해야 합니다."
  }
}
```

## 7-1. RAG로 만들 수 있는 Marriott 학습 데이터

스사사/뉴스사사 글에서 Marriott 관련 질문과 답변을 뽑아 아래 형태로 전환한다.

| 커뮤니티 원천 | Marriott 레슨 변환 |
| --- | --- |
| "포인트로 예약하는 게 이득인가요?" | 포인트 가치 계산 `case_quiz` |
| "숙박권 어디에 쓰는 게 좋나요?" | 숙박권 우선순위 `order_steps` |
| "플래티넘이면 조식 되나요?" | 등급 혜택 `single_choice` |
| "5박 예약은 어떻게 해야 하나요?" | 예약 조합 `case_quiz` |
| "현금가와 포인트 차감 중 뭘 봐야 하나요?" | 1포인트 가치 `fill_blank` |

전환 규칙:

- 글의 개인 상황은 일반화한다.
- 댓글 표현은 그대로 복사하지 않고 학습 문장으로 재작성한다.
- 규정이 필요한 부분은 `officialCheckRequired: true`로 표시한다.
- 정답이 애매한 커뮤니티 의견은 퀴즈 정답으로 쓰지 않고 `참고 사례`로만 쓴다.
- 최종 레슨은 운영자가 승인해야 앱에 노출한다.

## 8. 레슨 화면 UX

### 문제 풀이 화면

```text
[닫기] [진행 바] [에너지 18]

가족 여행에서 조식 혜택의 가치가 커지는 상황은?

[혼자 1박]
[4명 3박]
[조식을 먹지 않음]

[확인]
```

### 정답 피드백

```text
잘하셨어요!
조식 혜택은 인원수와 숙박일수가 늘수록 가치가 커져요.

[계속]
```

### 오답 피드백

```text
다시 생각해볼까요?
이번 여행에서 실제로 쓸 수 있는 혜택인지 먼저 보세요.

[다시 선택]
```

## 9. Marriott 과정 전체 레슨 초안

| 섹션 | 레슨 | 핵심 질문 | 문제 타입 |
| --- | --- | --- | --- |
| 등급 이해하기 | 등급 마을 1 | 등급 혜택은 왜 중요한가? | 선택, 매칭 |
| 등급 이해하기 | 조식과 라운지 | 혜택을 어떻게 현금 가치로 볼까? | 다중선택, 케이스 |
| 등급 이해하기 | 늦은 체크아웃 | 일정에 따라 가치가 왜 달라질까? | OX, 케이스 |
| 포인트 가치 계산 | 포인트 광산 1 | 포인트 사용이 이득인지 어떻게 판단하나? | 숫자입력, 선택 |
| 포인트 가치 계산 | 현금가 vs 포인트 | 1포인트 가치를 어떻게 계산하나? | 빈칸, 계산 |
| 포인트 가치 계산 | 수치선 판단 | 어느 사용처가 더 좋은가? | 슬라이더 |
| 숙박권 판단 | 숙박권 동굴 1 | 숙박권은 언제 쓰는 것이 좋은가? | 선택, 정렬 |
| 숙박권 판단 | 만료일 | 만료일이 가까울 때 우선순위는? | 순서배열 |
| 예약 조합 | 예약 미궁 1 | 현금/포인트/숙박권 중 무엇을 고르나? | 케이스 |
| 예약 조합 | 고수의 성문 | 여러 조건을 조합할 수 있나? | 복합 케이스 |
| 인증 | Marriott 성 | 최종 요약과 인증 준비 | 요약, 보스 연결 |

## 10. 포인트 가치 계산 레슨 예시

듀오링고 수학 문제처럼 숫자 감각을 키우는 화면을 만들 수 있다.

### `fill_blank`

```text
현금가 400,000원
포인트 50,000점

1포인트 가치는?

400,000 ÷ 50,000 = [   ] 원
```

### `slider`

```text
1포인트 가치가 8원이라면 수치선에서 어디에 표시할까요?

0원 ---- 3원 ---- 5원 ---- 8원 ---- 10원
```

### `order_steps`

```text
포인트 예약 판단 순서를 완성하세요.

1. 현금가 확인
2. 포인트 차감 확인
3. 1포인트 가치 계산
4. 취소 조건 확인
5. 최종 선택
```

## 11. 보스 인증

보스 인증은 기존 `mockExam`을 재사용한다.

추천 구성:

- 10~20문항
- 카테고리: `marriott_tier`, `marriott_points`, `marriott_free_night`, `marriott_booking`, `marriott_case`
- 총점: 100점
- 랭킹: 점수 높은 순, 동점이면 풀이 시간 짧은 순
- 최초 완료 보상: 100 땅콩 또는 `Marriott 마스터` 배지

Firestore 연결:

```json
{
  "courseId": "marriott_basics",
  "bossExamId": "exam_marriott_master",
  "bossUnlockRule": {
    "type": "complete_lessons",
    "requiredLessonIds": [
      "marriott_tier_village_01",
      "marriott_breakfast_lounge_01",
      "marriott_late_checkout_01",
      "marriott_point_value_01",
      "marriott_free_night_01",
      "marriott_booking_case_01",
      "marriott_castle_01"
    ]
  }
}
```

## 12. Flutter 구현 구조

### 화면

- `ExploreHomeScreen`: 분야/과정 선택
- `CourseDetailScreen`: Marriott 과정의 세로 레슨 노드
- `LessonScreen`: 한 문제씩 진행
- `LessonResultScreen`: XP, 콤보, 소요 시간, 땅콩 보상
- `MockExamTakeScreen`: 마스터 인증 응시

### 주요 위젯

- `ExploreStatusBar`
- `DomainCourseTabBar`
- `CourseCard`
- `LessonPath`
- `LessonNode`
- `RewardChestNode`
- `LessonProgressBar`
- `LessonItemRenderer`
- `SingleChoiceItem`
- `MultiSelectItem`
- `MatchPairItem`
- `FillBlankItem`
- `SliderAnswerItem`
- `OrderStepsItem`
- `LessonFeedbackSheet`
- `LessonRewardPanel`

### 상태 모델

```dart
enum LessonNodeStatus {
  locked,
  unlocked,
  inProgress,
  completed,
  mastered,
}

enum LessonItemType {
  scenario,
  conceptCard,
  singleChoice,
  multiSelect,
  matchPair,
  fillBlank,
  numberInput,
  slider,
  orderSteps,
  caseQuiz,
  recap,
}
```

## 13. UI 카피 초안

과정 카드:

```text
Marriott
포인트와 숙박권으로 호텔을 정복하는 길
진행률 2/18
계속하기
```

잠긴 과정:

```text
Hilton
준비 중
곧 새로운 호텔 과정이 열립니다.
```

레슨 완료:

```text
등급 마을을 완료했어요.
다음 레슨이 열렸습니다.
+10 땅콩
```

보스 인증:

```text
Marriott 마스터 인증이 열렸습니다.
지금까지 배운 내용을 시험처럼 확인해보세요.
```

## 14. 애셋/애니메이션 후보

초기에는 새 캐릭터 애니메이션을 크게 만들기보다 상태 변화가 분명한 짧은 Lottie를 우선한다.

- 레슨 노드 완료
- 보상 상자 열림
- 다음 섹션 오픈
- 정답 피드백
- 배지 획득

필요 애셋:

- Marriott 과정 아이콘
- 호텔 분야 아이콘
- 땅콩 캐릭터 기본 상태
- 땅콩 캐릭터 탐험가 스킨
- 레슨 노드 아이콘
- 배지 이미지

## 15. 첫 구현 체크리스트

- `explore/main/domains/hotel` 문서 생성
- `explore/main/courses/marriott_basics` 문서 생성
- Marriott 섹션 문서 생성
- 등급 마을 레슨 문서 생성
- 등급 마을 아이템 6~8개 생성
- `LessonItemRenderer` 타입별 분기 구현
- 레슨 제출/채점/보상 Cloud Function 설계
- `ExploreHomeScreen` 추가
- `CourseDetailScreen` 추가
- `LessonScreen` 추가
- 기존 `MockExamTakeScreen`으로 마스터 인증 연결

## 16. 콘텐츠 제작 원칙

- 문항은 "정답 맞히기"보다 "상황 판단" 중심으로 만든다.
- 한 레슨은 5~7개 아이템 안에서 끝낸다.
- 한 화면에는 하나의 판단만 요구한다.
- 공식 규정이 필요한 문항에는 검수 날짜를 남긴다.
- 혜택은 과장하지 않는다.
- "무조건 이득" 표현을 피하고 조건부 판단을 가르친다.
- 사용자가 바로 여행/예약에서 써먹을 수 있는 요약을 남긴다.
