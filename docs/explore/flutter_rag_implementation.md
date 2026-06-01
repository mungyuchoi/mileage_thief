# Flutter UI와 RAG 콘텐츠 구현 설계

작성일: 2026-05-30

## 1. 결정 사항

마일고사 RPG의 학습 UI는 웹뷰 없이 Flutter 네이티브 앱으로 구현한다.

```text
Flutter 네이티브 UI
-> Firestore/JSON 레슨 데이터 로드
-> 문제 타입별 위젯 렌더링
-> 즉시 피드백
-> Cloud Functions 채점/보상
```

웹뷰는 공식 규정 페이지, 외부 호텔/항공사 링크, 참고자료 열람처럼 외부 웹페이지가 꼭 필요한 경우에만 선택적으로 사용한다.

## 2. 왜 Flutter 네이티브인가

듀오링고식 학습 화면은 앱 안에서 상태 변화가 많다.

- 레슨 노드 잠금/해제
- 상단 진행 바
- 한 문제씩 넘기는 인터랙션
- 정답/오답 피드백 패널
- 콤보/XP/땅콩 보상
- 레슨 결과 화면
- 진동, 애니메이션, Lottie

이 흐름은 웹뷰보다 Flutter 위젯으로 만드는 편이 자연스럽다. 앱 상태, Firestore 진행률, Cloud Functions 보상 지급, Analytics 이벤트도 Flutter에서 직접 다루는 것이 좋다.

## 3. Flutter 화면 구조

```text
ExploreHomeScreen
-> DomainCourseTabBar
-> CourseCardGrid
-> ContinueLessonCard

CourseDetailScreen
-> CourseHeader
-> SectionHeader
-> LessonPath
-> LessonNode
-> RewardChestNode
-> BossExamNode

LessonScreen
-> LessonProgressBar
-> LessonItemRenderer
-> AnswerInput
-> LessonFeedbackSheet

LessonResultScreen
-> XP 카드
-> 콤보 카드
-> 소요 시간 카드
-> 땅콩 보상
-> 다음 레슨 CTA
```

## 4. 문제 타입별 Flutter 위젯

| 아이템 타입 | Flutter 위젯 | 예시 |
| --- | --- | --- |
| `scenario` | `ScenarioLessonItem` | 가족 일본 3박 여행 상황 |
| `concept_card` | `ConceptCardLessonItem` | 등급 혜택은 실제 비용을 바꾼다 |
| `single_choice` | `SingleChoiceLessonItem` | 보기 중 하나 고르기 |
| `multi_select` | `MultiSelectLessonItem` | 필요한 혜택 모두 선택 |
| `match_pair` | `MatchPairLessonItem` | 혜택과 가치를 연결 |
| `fill_blank` | `FillBlankLessonItem` | 계산식 빈칸 채우기 |
| `number_input` | `NumberInputLessonItem` | 1포인트 가치 입력 |
| `slider` | `SliderAnswerLessonItem` | 수치선에서 가치 선택 |
| `order_steps` | `OrderStepsLessonItem` | 예약 판단 순서 배열 |
| `case_quiz` | `CaseQuizLessonItem` | 조건을 보고 최적 선택 |
| `recap` | `RecapLessonItem` | 한 장 요약 |

`LessonItemRenderer`가 `type`을 보고 위젯을 분기한다.

## 5. 학습 데이터 원천

초기 원천 데이터는 스사사/뉴스사사 크롤링 JSON이다.

현재 확인된 예시:

```text
docs/exam/susasa_qna_20260528.json
docs/exam/susasa_qna_20260529.json
```

JSON 구조는 대략 아래와 같다.

```text
meta
articles[]
  articleId
  url
  title
  summary
  writer.anonId
  writtenAt
  stats
  body.plainText
  comments[]
    commentId
    plainText
    writtenAt
```

이 데이터는 그대로 앱에 노출하지 않는다. RAG와 운영 검수를 거쳐 "학습 가능한 지식/상황/문제"로 재구성한다.

## 6. RAG 파이프라인

```text
크롤링 JSON
-> 정규화
-> 개인정보/불필요 문구 제거
-> 주제 분류
-> 청크 생성
-> 임베딩 저장
-> 검색/RAG
-> 레슨 초안 생성
-> 운영자 검수
-> Firestore 레슨 데이터 배포
-> Flutter 앱 렌더링
```

### 1단계: 정규화

입력 JSON에서 학습에 필요한 텍스트만 뽑는다.

- 제목
- 요약
- 본문 plainText
- 댓글 plainText
- 작성일
- 출처 URL
- 게시판/메뉴명
- 통계 정보

제거할 내용:

- 작성자 식별 정보
- 개인정보
- 중복 안내문
- 삭제 댓글
- 의미 없는 이모티콘/공백
- 너무 짧은 댓글

### 2단계: 주제 분류

각 글/댓글을 분야와 과정 후보로 분류한다.

```json
{
  "domainId": "hotel",
  "courseCandidates": ["marriott_basics"],
  "topics": ["tier", "points", "free_night", "booking"],
  "intent": "question",
  "difficulty": "beginner"
}
```

분야 예시:

- `hotel`
- `airline`
- `giftcard`
- `card`

Marriott 토픽 예시:

- `tier`
- `breakfast_lounge`
- `points_value`
- `free_night_certificate`
- `booking_case`
- `promotion`

### 3단계: 청크 생성

RAG 검색 단위는 너무 길면 안 된다.

추천 청크:

- 질문 본문 1개
- 답변 댓글 1~3개 묶음
- 하나의 사례에서 핵심 조건만 추출한 요약

청크 예시:

```json
{
  "chunkId": "susasa_1957611_body_001",
  "sourceId": "susasa_qna_20260529:1957611",
  "sourceUrl": "https://...",
  "domainId": "card",
  "topics": ["card_recommendation"],
  "text": "결혼 전 큰 지출을 앞두고 혜택 좋은 신용카드를 찾는 질문...",
  "createdAt": "2026-05-30T00:00:00Z"
}
```

### 4단계: 임베딩/검색

임베딩 인덱스는 아래 목적에 쓴다.

- 특정 과정에 맞는 실제 사용자 사례 검색
- 자주 묻는 질문 추출
- 레슨 상황 카드 생성
- 오답 해설에 참고 근거 제공
- 새 문제 초안 생성

검색 쿼리 예시:

```text
Marriott 포인트 숙박 현금가 비교 실전 사례
Marriott 조식 라운지 등급 혜택 가족 여행
숙박권 만료일 사용처 고민
```

### 5단계: 레슨 초안 생성

RAG 결과를 바로 앱에 넣지 않는다. 먼저 레슨 초안을 만든다.

```json
{
  "courseId": "marriott_basics",
  "sectionId": "marriott_tier",
  "lessonId": "marriott_tier_village_01",
  "draftStatus": "needs_review",
  "sourceChunkIds": [
    "susasa_...",
    "newsusasa_..."
  ],
  "items": [
    {
      "type": "scenario",
      "title": "가족 여행 예약을 앞둔 상황",
      "body": "가족과 3박 여행을 준비 중..."
    },
    {
      "type": "single_choice",
      "prompt": "등급 혜택을 비교할 때 가장 먼저 볼 것은?",
      "choices": [],
      "answer": {}
    }
  ]
}
```

### 6단계: 운영자 검수

검수 기준:

- 공식 규정과 충돌하지 않는가
- 특정 개인의 경험담을 그대로 노출하지 않는가
- 출처 커뮤니티 글을 과도하게 복제하지 않는가
- 혜택을 과장하지 않는가
- "무조건 이득" 같은 표현을 피했는가
- 초보자가 이해할 수 있는가
- 문제의 정답이 애매하지 않은가

검수 후에만 `published` 상태로 Firestore에 배포한다.

## 7. Firestore 데이터 구조

RAG 원천과 앱 레슨 데이터를 분리한다.

```text
explore/main/domains/{domainId}
explore/main/courses/{courseId}
explore/main/courses/{courseId}/sections/{sectionId}
explore/main/courses/{courseId}/lessons/{lessonId}
explore/main/courses/{courseId}/lessons/{lessonId}/items/{itemId}

learningSources/main/sources/{sourceId}
learningSources/main/chunks/{chunkId}
learningSources/main/drafts/{draftId}
```

### `learningSources/main/sources/{sourceId}`

```json
{
  "sourceType": "naver_cafe",
  "sourceName": "susasa",
  "filePath": "docs/exam/susasa_qna_20260529.json",
  "fetchedAt": "2026-05-28T22:25:38.518Z",
  "articleCount": 1315,
  "commentCount": 8903,
  "identityPolicy": "anonymized",
  "createdAt": "serverTimestamp"
}
```

### `learningSources/main/chunks/{chunkId}`

```json
{
  "sourceId": "susasa_qna_20260529",
  "sourceArticleId": "1957611",
  "sourceUrl": "https://...",
  "domainId": "hotel",
  "courseCandidates": ["marriott_basics"],
  "topics": ["tier", "booking_case"],
  "text": "정제된 학습용 청크...",
  "embeddingRef": "vector_store_id_or_path",
  "qualityScore": 0.82,
  "createdAt": "serverTimestamp"
}
```

### `learningSources/main/drafts/{draftId}`

```json
{
  "courseId": "marriott_basics",
  "sectionId": "marriott_tier",
  "lessonId": "marriott_tier_village_01",
  "status": "needs_review",
  "sourceChunkIds": ["chunk_001", "chunk_002"],
  "generatedItems": [],
  "reviewNotes": "",
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

## 8. 앱 런타임에서 RAG를 직접 쓸지 여부

MVP에서는 앱 런타임에서 RAG를 직접 호출하지 않는 것을 추천한다.

추천 구조:

```text
RAG는 운영/콘텐츠 제작 도구에서 사용
-> 검수된 레슨 JSON을 Firestore에 저장
-> 앱은 검수된 데이터만 읽어서 Flutter UI로 표시
```

이유:

- 응답 속도가 빠르다.
- 비용 예측이 쉽다.
- 정답/해설 품질을 통제할 수 있다.
- 커뮤니티 원문 노출 위험을 줄일 수 있다.
- 랭킹/보상 시스템의 공정성을 지킬 수 있다.

나중에 추가할 수 있는 기능:

- `AI 해설 더보기`
- `비슷한 실제 사례 보기`
- `내 상황으로 다시 설명`
- `오답 기반 맞춤 복습`

이 기능들은 RAG를 실시간으로 붙일 수 있지만, 첫 버전의 핵심 학습 플로우에는 넣지 않는다.

## 9. Flutter와 백엔드 역할 분리

| 영역 | 담당 |
| --- | --- |
| Flutter | 화면, 인터랙션, 로컬 선택 상태, 진행 애니메이션 |
| Firestore | 과정/레슨/아이템/진행률 저장 |
| Cloud Functions | 제출 검증, 보상 지급, 진행 상태 업데이트 |
| RAG 파이프라인 | 원천 JSON 정제, 검색, 레슨 초안 생성 |
| 운영자 도구 | 초안 검수, 수정, publish |

## 10. 첫 구현 순서

1. `ExploreHomeScreen`을 Flutter 네이티브로 만든다.
2. `CourseDetailScreen`에서 Marriott 세로 레슨 노드를 보여준다.
3. `LessonScreen`에서 정적 JSON 아이템 5~7개를 렌더링한다.
4. `LessonItemRenderer`를 타입별로 분리한다.
5. 레슨 완료 보상을 Cloud Functions로 처리한다.
6. 스사사/뉴스사사 JSON을 정규화하는 스크립트를 만든다.
7. 정규화 청크로 RAG 검색/레슨 초안 생성을 만든다.
8. 검수된 레슨 데이터를 Firestore에 배포한다.
9. 마지막에 `mockExam` 마스터 인증으로 연결한다.

## 11. 주의할 점

- 커뮤니티 글 원문을 앱에 그대로 노출하지 않는다.
- 개인정보나 특정 사용자 경험이 식별되지 않게 한다.
- 공식 규정이 필요한 내용은 반드시 최신 공식 자료로 검수한다.
- RAG가 만든 정답은 그대로 믿지 말고 운영자 검수를 거친다.
- 앱 사용자는 빠른 네이티브 학습 경험을 기대하므로, 레슨 중 실시간 생성 대기는 피한다.
