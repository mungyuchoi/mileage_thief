# 마일캐치 실전 모의고사 생성 및 업로드 프롬프트

이 문서는 새 컨텍스트에서도 이 파일 하나만 보고 다음 회차 `milecatch_exam_round_N.json`을 생성하고 Firestore에 업로드할 수 있도록 만든 작업 지침이다.

## 작업 목표

사용자가 “이 MD 파일을 근거로 다음 실전모의고사 N회를 만들자”라고 요청하면 아래 순서로 바로 진행한다.

1. `docs/exam/milecatch_exam_round_*.json`을 모두 읽어 이미 사용된 `sourceArticleIds`, 문제 주제, 이미지 문항 유형을 파악한다.
2. 최신 또는 사용자가 지정한 `docs/exam/susasa_qns_20xxxxxxxx.json`을 문제 원천 데이터로 사용한다.
3. 기존 `milecatch_exam_round_N.json`과 source article ID 및 실질 문제 주제가 겹치지 않게 새 20문항을 만든다.
4. 결과 파일을 `docs/exam/milecatch_exam_round_N.json`에 저장한다.
5. 기본 상태는 반드시 `locked`로 한다.
6. Firebase Admin 서비스 계정으로 Firestore에 업로드한다.
7. 업로드 후 Firestore에서 다시 읽어 `status`, 문항 수, 정답키 수, 정답 분포를 검증한다.

## 우선 적용 규칙

아래 규칙은 뒤쪽의 “원본 1회 생성 프롬프트 JSON”보다 우선한다.

- 회차 번호는 사용자 요청의 N을 따른다. 예: 5회차면 `exam_005`, `roundNo: 5`, 파일명은 `docs/exam/milecatch_exam_round_5.json`.
- `examDocument.data.status`는 기본값으로 반드시 `locked`를 사용한다.
- `examDocument.data.title`은 `제N회 마일캐치 모의고사` 형식을 사용한다.
- `examDocument.path`는 `mockExam/main/exams/exam_NNN` 형식을 사용한다.
- 문제 경로는 `mockExam/main/exams/exam_NNN/questions/q001`부터 `q020`까지 사용한다.
- 정답키 경로는 `mockExam/main/answerKeys/exam_NNN/questions/q001`부터 `q020`까지 사용한다.
- 정답과 해설은 절대 `questionDocuments`에 넣지 않는다. `answerKeyDocuments`에만 넣는다.
- 기본 톤은 명확하고 실전적인 시험 문제 톤이다. 유머러스하거나 장난스러운 문제는 사용자가 그 회차에서 명시적으로 요청할 때만 추가한다.
- 이미지 문항은 적극 활용하되, 이미지가 정답 판단에 도움이 되는 경우에만 `imageUrl`을 넣는다.
- `choices`는 항상 `a`, `b`, `c`, `d` 4개다.
- 정답 위치는 한쪽으로 몰리지 않게 한다. 가능하면 `a: 5`, `b: 5`, `c: 5`, `d: 5`로 맞춘다.
- 난이도는 원본 프롬프트처럼 `easy: 10`, `normal: 8`, `hard: 2`를 기본으로 한다.
- 카테고리는 `airline`, `card`, `giftcard`, `hotel` 각 5문항씩 총 20문항이다.
- `createdAt`, `updatedAt`은 JSON 파일에는 문자열 `"serverTimestamp"`로 넣고, 업로드 시 Firebase `FieldValue.serverTimestamp()`로 변환한다.
- `unlockRule`은 기본적으로 `{ "type": "always_open" }`를 유지한다. 앱에서는 `status: locked`가 접근 제한의 기준이다.

## 원천 데이터 규칙

문제 원천은 `docs/exam/susasa_qns_20xxxxxxxx.json` 파일을 사용한다고 가정한다.

파일명 예:

- `docs/exam/susasa_qns_20260528.json`
- `docs/exam/susasa_qns_20260603.json`
- `docs/exam/susasa_qns_20260715.json`

현재 레포에 과거 파싱 파일이 `susasa_qna_YYYYMMDD.json` 이름으로 남아 있을 수 있다. 새 작업에서는 사용자가 지정한 파일을 우선하고, 지정이 없으면 `docs/exam/susasa_qns_*.json` 중 날짜가 가장 최신인 파일을 우선한다. `susasa_qns_*.json`이 없고 `susasa_qna_*.json`만 있으면 최신 `susasa_qna_*.json`을 fallback으로 사용할 수 있다.

원천 데이터 예상 구조:

```json
{
  "meta": {
    "source": "naver_cafe",
    "fetchedAt": "2026-05-27T23:07:59.083Z",
    "articleCount": 1366,
    "commentCount": 8094
  },
  "articles": [
    {
      "articleId": 1964299,
      "url": "https://...",
      "title": "게시글 제목",
      "summary": "요약",
      "body": {
        "plainText": "본문 텍스트",
        "sanitizedHtml": "이미지 URL 포함 가능"
      },
      "comments": [
        {
          "plainText": "댓글 텍스트"
        }
      ],
      "stats": {
        "readCount": 76,
        "likeCount": 0,
        "commentCount": 1
      }
    }
  ]
}
```

이미지 URL 추출 규칙:

- `article.images[]`가 있으면 먼저 사용한다.
- `body.sanitizedHtml` 안의 `<img src="...">`도 함께 추출한다.
- 중복 URL은 제거한다.
- `?type=w800`이 붙은 썸네일 URL을 사용할 수 있다.
- 이미지가 문제 풀이에 도움이 되지 않으면 억지로 넣지 않는다.

원천 데이터 선택 규칙:

- `title`, `summary`, `body.plainText`, `comments[].plainText`, `stats`를 함께 참고한다.
- 조회수와 댓글 수가 많은 글, 반복적으로 등장하는 질문, 실제 사용자가 헷갈릴 만한 실전 사례를 우선한다.
- 원문 문장을 길게 복사하지 말고 문제와 해설은 새 문장으로 재구성한다.
- 개인정보, 작성자 특정, 커뮤니티 내부의 과도하게 좁은 맥락은 제거한다.
- 최신 정책, 약관, 시세, 프로모션은 바뀔 수 있으므로 원천 JSON 근거가 있더라도 단정형 문항은 피하고 “확인해야 할 것” 중심으로 낸다.
- 출처가 특정 개인 경험뿐인 경우 일반화 가능한 안전한 판단 문제로 바꾼다.

## 기존 회차와 중복 회피

새 회차 생성 전 반드시 기존 회차 파일을 모두 읽는다.

대상 파일:

```text
docs/exam/milecatch_exam_round_*.json
```

중복 회피 기준:

- 기존 `questionDocuments[].data.sourceArticleIds`에 들어간 article ID는 새 문제에서 사용하지 않는다.
- 같은 article ID가 아니어도 문제의 핵심 주제가 기존 회차와 사실상 같으면 피한다.
- 같은 이미지 URL을 재사용하지 않는다.
- 같은 계산 구조나 같은 정답 포인트를 반복하지 않는다.
- 새 회차의 `qualityChecklist`에 `avoidsPreviousRoundSourceOverlap: true`를 넣고 실제 검증도 한다.

기존 source ID 수집 예시:

```bash
node - <<'NODE'
const fs = require('fs');
const files = fs.readdirSync('docs/exam')
  .filter(f => /^milecatch_exam_round_\d+\.json$/.test(f))
  .map(f => `docs/exam/${f}`);
const used = new Set();
for (const file of files) {
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  for (const q of json.questionDocuments || []) {
    for (const id of q.data?.sourceArticleIds || []) used.add(Number(id));
  }
}
console.log([...used].sort((a, b) => a - b).join(','));
NODE
```

## 생성 산출물 스키마

반드시 아래 최상위 키를 가진 단일 JSON 객체로 저장한다.

```json
{
  "examDocument": {},
  "questionDocuments": [],
  "answerKeyDocuments": [],
  "qualityChecklist": {}
}
```

`examDocument` 예:

```json
{
  "path": "mockExam/main/exams/exam_005",
  "data": {
    "title": "제5회 마일캐치 모의고사",
    "description": "실전 사례로 항공, 카드, 상품권, 호텔 판단력을 확인하는 모의고사",
    "status": "locked",
    "roundNo": 5,
    "questionCount": 20,
    "totalScore": 100,
    "categories": [
      "airline",
      "card",
      "giftcard",
      "hotel"
    ],
    "timeLimitSeconds": 600,
    "rankingPeriod": "weekly",
    "unlockRule": {
      "type": "always_open"
    },
    "sourceJsonPath": "docs/exam/susasa_qns_20260603.json",
    "createdAt": "serverTimestamp",
    "updatedAt": "serverTimestamp"
  }
}
```

`questionDocuments[]` 예:

```json
{
  "path": "mockExam/main/exams/exam_005/questions/q001",
  "data": {
    "questionId": "q001",
    "sourceQuestionId": "susasa_1961234",
    "category": "airline",
    "order": 1,
    "score": 5,
    "difficulty": "easy",
    "question": "문제 본문",
    "imageUrl": null,
    "choices": [
      { "id": "a", "text": "선택지 A" },
      { "id": "b", "text": "선택지 B" },
      { "id": "c", "text": "선택지 C" },
      { "id": "d", "text": "선택지 D" }
    ],
    "tags": [
      "태그"
    ],
    "sourceArticleIds": [
      1961234
    ],
    "sourceUrls": [
      "https://..."
    ]
  }
}
```

`answerKeyDocuments[]` 예:

```json
{
  "path": "mockExam/main/answerKeys/exam_005/questions/q001",
  "data": {
    "correctChoiceId": "c",
    "answerText": "정답 선택지 텍스트",
    "explanation": "왜 정답인지, 다른 선택지는 왜 아닌지 초보자도 이해할 수 있게 2~4문장으로 설명한다.",
    "score": 5,
    "category": "airline",
    "tags": [
      "태그"
    ],
    "sourceArticleIds": [
      1961234
    ],
    "sourceUrls": [
      "https://..."
    ]
  }
}
```

`qualityChecklist` 예:

```json
{
  "totalQuestionCount": 20,
  "categoryCounts": {
    "airline": 5,
    "card": 5,
    "giftcard": 5,
    "hotel": 5
  },
  "difficultyCounts": {
    "easy": 10,
    "normal": 8,
    "hard": 2
  },
  "answerDistribution": {
    "a": 5,
    "b": 5,
    "c": 5,
    "d": 5
  },
  "imageQuestionCount": 0,
  "hasSeparatedAnswerKeys": true,
  "hasNoAnswerInQuestionDocuments": true,
  "hasSourceForEveryQuestion": true,
  "avoidsPreviousRoundSourceOverlap": true
}
```

## 작성 후 검증 스크립트

파일 작성 후 업로드 전 반드시 검증한다. `ROUND` 값만 바꿔 실행한다.

```bash
ROUND=5 node - <<'NODE'
const fs = require('fs');
const round = Number(process.env.ROUND);
const examId = `exam_${String(round).padStart(3, '0')}`;
const file = `docs/exam/milecatch_exam_round_${round}.json`;
const j = JSON.parse(fs.readFileSync(file, 'utf8'));
const errors = [];
const cat = {};
const diff = {};
const ans = { a: 0, b: 0, c: 0, d: 0 };

if (j.examDocument.path !== `mockExam/main/exams/${examId}`) errors.push('bad exam path');
if (j.examDocument.data.status !== 'locked') errors.push('status must be locked');
if (j.examDocument.data.roundNo !== round) errors.push('bad roundNo');
if (j.questionDocuments.length !== 20) errors.push('question count must be 20');
if (j.answerKeyDocuments.length !== 20) errors.push('answer key count must be 20');

const qById = new Map();
for (const q of j.questionDocuments) {
  const d = q.data;
  cat[d.category] = (cat[d.category] || 0) + 1;
  diff[d.difficulty] = (diff[d.difficulty] || 0) + 1;
  if (q.path !== `mockExam/main/exams/${examId}/questions/${d.questionId}`) errors.push(`bad q path ${d.questionId}`);
  if (qById.has(d.questionId)) errors.push(`duplicate q ${d.questionId}`);
  qById.set(d.questionId, q);
  if (/correctChoiceId|answerText|explanation/.test(JSON.stringify(d))) errors.push(`answer leaked in ${d.questionId}`);
  if ((d.sourceArticleIds || []).length === 0 || (d.sourceUrls || []).length === 0) errors.push(`missing source ${d.questionId}`);
}

for (const a of j.answerKeyDocuments) {
  const id = a.path.split('/').pop();
  const q = qById.get(id);
  if (!q) {
    errors.push(`answer without question ${id}`);
    continue;
  }
  const d = a.data;
  ans[d.correctChoiceId] = (ans[d.correctChoiceId] || 0) + 1;
  if (a.path !== `mockExam/main/answerKeys/${examId}/questions/${id}`) errors.push(`bad answer path ${id}`);
  if (d.category !== q.data.category) errors.push(`category mismatch ${id}`);
  const choice = q.data.choices.find(c => c.id === d.correctChoiceId);
  if (!choice) errors.push(`missing correct choice ${id}`);
  else if (choice.text !== d.answerText) errors.push(`answerText mismatch ${id}`);
}

for (const [category, count] of Object.entries({ airline: 5, card: 5, giftcard: 5, hotel: 5 })) {
  if (cat[category] !== count) errors.push(`bad category count ${category}: ${cat[category]}`);
}
for (const [difficulty, count] of Object.entries({ easy: 10, normal: 8, hard: 2 })) {
  if (diff[difficulty] !== count) errors.push(`bad difficulty count ${difficulty}: ${diff[difficulty]}`);
}
for (const [choice, count] of Object.entries({ a: 5, b: 5, c: 5, d: 5 })) {
  if (ans[choice] !== count) errors.push(`bad answer distribution ${choice}: ${ans[choice]}`);
}

const previousFiles = fs.readdirSync('docs/exam')
  .filter(f => /^milecatch_exam_round_\d+\.json$/.test(f) && f !== `milecatch_exam_round_${round}.json`)
  .map(f => `docs/exam/${f}`);
const usedIds = new Set();
const usedImages = new Set();
for (const previousFile of previousFiles) {
  const previous = JSON.parse(fs.readFileSync(previousFile, 'utf8'));
  for (const q of previous.questionDocuments || []) {
    for (const sourceId of q.data?.sourceArticleIds || []) usedIds.add(Number(sourceId));
    if (q.data?.imageUrl) usedImages.add(q.data.imageUrl);
  }
}
const overlapIds = [];
const overlapImages = [];
for (const q of j.questionDocuments) {
  for (const sourceId of q.data.sourceArticleIds || []) {
    if (usedIds.has(Number(sourceId))) overlapIds.push(sourceId);
  }
  if (q.data.imageUrl && usedImages.has(q.data.imageUrl)) overlapImages.push(q.data.imageUrl);
}
if (overlapIds.length) errors.push(`source overlap: ${[...new Set(overlapIds)].join(',')}`);
if (overlapImages.length) errors.push(`image overlap: ${[...new Set(overlapImages)].join(',')}`);

console.log(errors.length ? errors.join('\n') : `${file} validation ok`);
console.log({ categories: cat, difficulties: diff, answers: ans, images: j.questionDocuments.filter(q => q.data.imageUrl).length });
process.exit(errors.length ? 1 : 0);
NODE
```

## Firestore 업로드 절차

업로드는 Firebase Admin SDK를 사용한다.

기본 서비스 계정 경로:

```text
env/mileagethief-firebase-adminsdk-8gdf2-49e348f31e.json
```

만약 파일명이 바뀌었으면 `env/*firebase-adminsdk*.json`에서 실제 서비스 계정 파일을 찾아 사용한다.

업로드 전제:

- `functions/node_modules/firebase-admin`이 있어야 한다.
- 없으면 `functions` 디렉터리에서 의존성을 설치해야 한다.

업로드 스크립트:

```bash
ROUND=5 node - <<'NODE'
const fs = require('fs');
const path = require('path');
const admin = require('./functions/node_modules/firebase-admin');

const round = Number(process.env.ROUND);
const examId = `exam_${String(round).padStart(3, '0')}`;
const serviceAccountPath = fs.existsSync('env/mileagethief-firebase-adminsdk-8gdf2-49e348f31e.json')
  ? path.resolve('env/mileagethief-firebase-adminsdk-8gdf2-49e348f31e.json')
  : path.resolve(fs.readdirSync('env').find(f => /firebase-adminsdk.*\.json$/.test(f)) ? `env/${fs.readdirSync('env').find(f => /firebase-adminsdk.*\.json$/.test(f))}` : '');
const examJsonPath = path.resolve(`docs/exam/milecatch_exam_round_${round}.json`);
const payload = JSON.parse(fs.readFileSync(examJsonPath, 'utf8'));

if (!fs.existsSync(serviceAccountPath)) {
  throw new Error(`Service account not found: ${serviceAccountPath}`);
}
if (payload.examDocument.path !== `mockExam/main/exams/${examId}`) {
  throw new Error(`Exam path mismatch: ${payload.examDocument.path}`);
}
if (payload.examDocument.data.status !== 'locked') {
  throw new Error(`Refusing upload because status is not locked: ${payload.examDocument.data.status}`);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'))),
});

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function materialize(value) {
  if (Array.isArray(value)) return value.map(materialize);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, materialize(v)]));
  }
  return value === 'serverTimestamp' ? FieldValue.serverTimestamp() : value;
}

async function deleteCollection(collectionRef) {
  const snap = await collectionRef.get();
  if (snap.empty) return 0;
  let batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    count += 1;
    if (count % 450 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  await batch.commit();
  return count;
}

async function main() {
  const examRef = db.doc(payload.examDocument.path);
  const answerRootRef = db.doc(`mockExam/main/answerKeys/${examId}`);

  const deletedQuestions = await deleteCollection(examRef.collection('questions'));
  const deletedAnswers = await deleteCollection(answerRootRef.collection('questions'));

  const batch = db.batch();
  batch.set(examRef, materialize(payload.examDocument.data));
  for (const q of payload.questionDocuments) {
    batch.set(db.doc(q.path), materialize(q.data));
  }
  for (const a of payload.answerKeyDocuments) {
    batch.set(db.doc(a.path), materialize(a.data));
  }
  await batch.commit();

  const [examSnap, qSnap, aSnap] = await Promise.all([
    examRef.get(),
    examRef.collection('questions').get(),
    answerRootRef.collection('questions').get(),
  ]);
  const exam = examSnap.data();
  const dist = { a: 0, b: 0, c: 0, d: 0 };
  for (const doc of aSnap.docs) {
    const id = doc.data().correctChoiceId;
    dist[id] = (dist[id] || 0) + 1;
  }
  console.log(JSON.stringify({
    uploaded: true,
    examPath: payload.examDocument.path,
    status: exam.status,
    roundNo: exam.roundNo,
    questionCount: qSnap.size,
    answerKeyCount: aSnap.size,
    imageQuestionCount: qSnap.docs.filter(d => d.data().imageUrl).length,
    answerDistribution: dist,
    deletedQuestions,
    deletedAnswers
  }, null, 2));
}

main()
  .then(() => admin.app().delete())
  .catch(async err => {
    console.error(err);
    try { await admin.app().delete(); } catch (_) {}
    process.exit(1);
  });
NODE
```

업로드 성공 조건:

- 출력의 `uploaded`가 `true`
- `status`가 `locked`
- `questionCount`가 `20`
- `answerKeyCount`가 `20`
- `answerDistribution`이 가능하면 `a/b/c/d = 5/5/5/5`

## 새 회차 생성용 최종 지시문

새 컨텍스트에서 이 파일을 근거로 회차 N을 만들 때는 아래 지시를 그대로 따른다.

```text
너는 마일캐치 실전 모의고사 출제위원장이다.

docs/exam/generate_mock_exam_prompt.md의 모든 규칙을 따른다.
docs/exam/milecatch_exam_round_*.json을 모두 읽어 기존 sourceArticleIds, 이미지 URL, 문제 주제를 파악하고 새 회차와 겹치지 않게 한다.
문제 원천은 사용자가 지정한 docs/exam/susasa_qns_20xxxxxxxx.json을 우선 사용한다.
사용자가 지정하지 않았다면 docs/exam/susasa_qns_*.json 중 최신 날짜 파일을 사용하고, 없으면 docs/exam/susasa_qna_*.json 중 최신 날짜 파일을 fallback으로 사용한다.

새 회차는 총 20문항이다.
항공 airline 5문항, 카드 card 5문항, 상품권 giftcard 5문항, 호텔 hotel 5문항을 만든다.
난이도는 easy 10문항, normal 8문항, hard 2문항이다.
정답 위치는 a, b, c, d 각 5개가 되도록 섞는다.
questionDocuments에는 정답, 정답 선택지 ID, 해설을 넣지 않는다.
answerKeyDocuments에만 correctChoiceId, answerText, explanation을 넣는다.
각 문항에는 sourceArticleIds와 sourceUrls를 반드시 넣는다.
이미지가 문제 이해에 도움이 되면 imageUrl을 적극 사용한다.
기본 톤은 명확하고 실전적인 시험 문제 톤이다. 사용자가 요청하지 않으면 유머러스한 문항을 넣지 않는다.

결과 파일은 docs/exam/milecatch_exam_round_N.json으로 저장한다.
examId는 exam_NNN 형식을 사용한다.
Firestore 경로는 mockExam/main/exams/exam_NNN 및 mockExam/main/answerKeys/exam_NNN/questions/{questionId}를 사용한다.
examDocument.data.status는 기본으로 locked다.

파일 작성 후 검증 스크립트를 실행한다.
검증 통과 후 Firebase Admin SDK로 Firestore에 업로드한다.
업로드 후 Firestore에서 다시 읽어 status, roundNo, questionCount, answerKeyCount, imageQuestionCount, answerDistribution을 확인한다.
최종 응답에는 생성 파일 경로, 업로드 경로, locked 상태, 문항 수, 이미지 문항 수, 정답 분포, 기존 회차 중복 없음 여부를 간결히 보고한다.
```

## 원본 1회 생성 프롬프트 JSON

아래 내용은 `docs/exam/milecatch_exam_round_1_generation_prompt.json`의 원문이다. 위의 “우선 적용 규칙”과 충돌하는 회차 번호, 상태값, 원천 파일명은 새 회차 규칙으로 치환해서 사용한다.

```json
{
  "id": "milecatch_mock_exam_round_1_generation_prompt",
  "title": "마일캐치 모의고사 1회 생성 프롬프트",
  "version": 1,
  "createdAt": "2026-05-28",
  "language": "ko",
  "purpose": "docs/exam/susasa_qna_20260528.json을 근거로 마일캐치 모의고사 1회 20문항을 생성한다.",
  "referenceDocuments": [
    {
      "path": "docs/exam/milecatch_mock_exam_spec.md",
      "usage": "모의고사 기능 정의, 점수 체계, Firestore 구조, 문제/정답 분리 원칙을 따른다."
    },
    {
      "path": "docs/exam/susasa_qna_20260528.json",
      "usage": "스사사 질문게시판의 질문, 본문, 댓글, 이미지, 빈도 높은 관심사를 문제 출제 근거로 사용한다."
    }
  ],
  "persona": {
    "role": "너는 마일캐치 제1회 모의고사 출제위원장이다.",
    "expertise": [
      "항공 마일리지",
      "신용카드 혜택",
      "상품권/상테크",
      "호텔 포인트와 멤버십"
    ],
    "tone": "친절하지만 시험 문제답게 명확하고, 초보자도 풀어볼 수 있을 만큼 쉬운 표현을 사용한다.",
    "principles": [
      "너무 지엽적인 커뮤니티 내부 은어보다 많은 사용자가 한 번쯤 접했을 정보를 우선한다.",
      "스사사 JSON에서 반복적으로 등장하거나 사용자들이 자주 질문한 주제를 우선한다.",
      "한 문제에는 하나의 명확한 정답만 있어야 한다.",
      "문제는 재미있고 공유하고 싶어야 하지만, 낚시성 문항이나 애매한 정답은 피한다.",
      "시점에 따라 바뀔 수 있는 정보는 반드시 JSON 근거 또는 일반적으로 안정적인 사실에 기반해 출제한다.",
      "법률, 세금, 카드 약관, 항공/호텔 정책처럼 변경 가능성이 큰 내용은 단정하지 말고 문제 난이도를 낮추거나 제외한다.",
      "정답과 해설은 클라이언트 표시용 문제 문서에 넣지 않고 answerKeys 문서로 분리한다."
    ]
  },
  "task": {
    "summary": "마일캐치 모의고사 1회용 20문항을 생성한다.",
    "examId": "exam_001",
    "roundNo": 1,
    "examTitle": "제1회 마일캐치 모의고사",
    "questionCount": 20,
    "totalScore": 100,
    "scorePerQuestion": 5,
    "categories": [
      {
        "id": "airline",
        "label": "항공",
        "questionCount": 5,
        "topicHints": [
          "마일리지 사용",
          "항공사 통합/제휴",
          "좌석과 발권",
          "마일리지 가치",
          "가족 합산/양도 같은 기본 개념"
        ]
      },
      {
        "id": "card",
        "label": "카드",
        "questionCount": 5,
        "topicHints": [
          "카드 혜택",
          "전월 실적",
          "포인트 전환",
          "마일리지 적립",
          "프리미엄 카드와 호텔/항공 혜택"
        ]
      },
      {
        "id": "giftcard",
        "label": "상품권",
        "questionCount": 5,
        "topicHints": [
          "상품권 할인율",
          "실질 구매가",
          "매입가",
          "상테크 기본 계산",
          "수수료와 실적 인정 여부"
        ]
      },
      {
        "id": "hotel",
        "label": "호텔",
        "questionCount": 5,
        "topicHints": [
          "호텔 티어",
          "포인트 숙박",
          "포인트 전환",
          "숙박권",
          "프로모션과 패스트트랙"
        ]
      }
    ]
  },
  "sourceDataInstructions": {
    "inputJsonPath": "docs/exam/susasa_qna_20260528.json",
    "expectedShape": {
      "meta": "수집 출처, 게시판, 수집 시점, articleCount, commentCount 등",
      "articles[]": {
        "articleId": "게시글 ID",
        "url": "원문 URL",
        "title": "게시글 제목",
        "summary": "요약",
        "body.plainText": "본문 텍스트",
        "body.sanitizedHtml": "이미지 URL 등 HTML 포함 가능",
        "comments[].plainText": "댓글 내용",
        "stats": "조회수, 좋아요, 댓글 수"
      }
    },
    "howToUse": [
      "articles의 title, summary, body.plainText, comments[].plainText를 모두 참고한다.",
      "이미지가 있는 게시글은 imageUrl 후보로 활용할 수 있으나, 문제 풀이에 이미지가 필수일 때만 imageUrl을 넣는다.",
      "sourceArticleIds에는 근거가 된 articleId를 1개 이상 넣는다.",
      "sourceUrls에는 근거가 된 url을 1개 이상 넣는다.",
      "질문게시판의 실제 고민을 바탕으로 하되, 개인정보나 특정 작성자를 드러내지 않는다.",
      "원문 문장을 길게 그대로 복사하지 말고, 문제와 해설은 새 문장으로 재구성한다."
    ]
  },
  "questionDesignRules": {
    "format": "4지선다 객관식",
    "choiceIds": [
      "a",
      "b",
      "c",
      "d"
    ],
    "difficultyMix": {
      "easy": 10,
      "normal": 8,
      "hard": 2
    },
    "readability": [
      "문제는 1~2문장으로 짧게 쓴다.",
      "선택지는 서로 길이가 너무 차이나지 않게 쓴다.",
      "부정형 문제는 최소화한다. 필요하면 '아닌 것은?'을 굵게 의식해도 헷갈리지 않게 쓴다.",
      "정답은 하나만 존재해야 한다.",
      "초보 사용자가 찍어도 배울 수 있게 해설을 쉽게 쓴다."
    ],
    "popularInformationRule": [
      "가장 알기 쉽고 누구나 많이 접해봤을 정보를 우선 출제한다.",
      "예: '아시아나는 대한항공과 통합 절차를 밟고 있다'처럼 많은 사용자가 들어본 항공 업계 이슈를 쉬운 O/X 또는 객관식으로 바꿀 수 있다.",
      "단, 최신 상태가 중요한 문항은 JSON 근거가 없으면 단정하지 않는다.",
      "커뮤니티에서 반복되는 실전 질문을 일반화해서 낸다. 예: 포인트 전환, 카드 실적, 호텔 티어, 상품권 할인율 계산."
    ],
    "avoid": [
      "정답이 여러 개인 문제",
      "출처 JSON에서 근거를 찾기 어려운 세부 약관 문제",
      "특정 개인의 경험만 알아야 맞힐 수 있는 문제",
      "시세나 프로모션처럼 시점에 따라 쉽게 바뀌는데 날짜 기준이 없는 문제",
      "커뮤니티 원문을 과도하게 그대로 베낀 문장",
      "정답 선택지를 지나치게 티 나게 만드는 구성"
    ]
  },
  "firestoreTarget": {
    "root": "mockExam/main",
    "examDocumentPath": "mockExam/main/exams/exam_001",
    "questionDocumentPathPattern": "mockExam/main/exams/exam_001/questions/{questionId}",
    "answerKeyDocumentPathPattern": "mockExam/main/answerKeys/exam_001/questions/{questionId}",
    "importantRule": "questionDocuments에는 correctChoiceId, answerText, explanation을 넣지 않는다. 정답과 해설은 answerKeyDocuments에만 넣는다."
  },
  "requiredOutput": {
    "type": "single_json_object",
    "noMarkdown": true,
    "description": "반드시 JSON 객체만 출력한다. 설명 문장, 마크다운 코드블록, 주석을 출력하지 않는다.",
    "topLevelKeys": [
      "examDocument",
      "questionDocuments",
      "answerKeyDocuments",
      "qualityChecklist"
    ],
    "schema": {
      "examDocument": {
        "path": "mockExam/main/exams/exam_001",
        "data": {
          "title": "제1회 마일캐치 모의고사",
          "description": "항공, 카드, 상품권, 호텔 기본기를 확인하는 모의고사",
          "status": "draft",
          "roundNo": 1,
          "questionCount": 20,
          "totalScore": 100,
          "categories": [
            "airline",
            "card",
            "giftcard",
            "hotel"
          ],
          "timeLimitSeconds": 600,
          "rankingPeriod": "weekly",
          "unlockRule": {
            "type": "always_open"
          }
        }
      },
      "questionDocuments[]": {
        "path": "mockExam/main/exams/exam_001/questions/{questionId}",
        "data": {
          "sourceQuestionId": "원천 질문 ID 또는 생성 ID",
          "category": "airline|card|giftcard|hotel",
          "order": 1,
          "score": 5,
          "difficulty": "easy|normal|hard",
          "question": "문제 본문",
          "imageUrl": null,
          "choices": [
            {
              "id": "a",
              "text": "선택지 A"
            },
            {
              "id": "b",
              "text": "선택지 B"
            },
            {
              "id": "c",
              "text": "선택지 C"
            },
            {
              "id": "d",
              "text": "선택지 D"
            }
          ],
          "tags": [
            "태그"
          ],
          "sourceArticleIds": [
            1964284
          ],
          "sourceUrls": [
            "https://..."
          ]
        }
      },
      "answerKeyDocuments[]": {
        "path": "mockExam/main/answerKeys/exam_001/questions/{questionId}",
        "data": {
          "correctChoiceId": "a|b|c|d",
          "answerText": "정답 선택지 텍스트",
          "explanation": "해설. 왜 정답인지, 나머지는 왜 아닌지 초보자도 이해할 수 있게 2~4문장으로 설명한다.",
          "score": 5,
          "category": "airline|card|giftcard|hotel",
          "tags": [
            "태그"
          ],
          "sourceArticleIds": [
            1964284
          ],
          "sourceUrls": [
            "https://..."
          ]
        }
      },
      "qualityChecklist": {
        "totalQuestionCount": 20,
        "categoryCounts": {
          "airline": 5,
          "card": 5,
          "giftcard": 5,
          "hotel": 5
        },
        "scorePerQuestion": 5,
        "totalScore": 100,
        "hasSeparatedAnswerKeys": true,
        "hasNoAnswerInQuestionDocuments": true,
        "hasSourceForEveryQuestion": true
      }
    }
  },
  "finalPrompt": [
    "너는 마일캐치 제1회 모의고사 출제위원장이다.",
    "입력으로 제공되는 docs/exam/susasa_qna_20260528.json의 articles, body, comments, stats를 분석해서 항공 5문항, 카드 5문항, 상품권 5문항, 호텔 5문항, 총 20문항을 만들어라.",
    "각 문항은 4지선다 객관식이며 배점은 5점이다. 총점은 100점이다.",
    "가장 알기 쉽고 누구나 많이 접해봤을 정보를 우선한다. 예를 들어 항공 분야에서는 '아시아나는 대한항공과 통합 절차를 밟고 있다'처럼 많은 사용자가 들어본 주제를 쉬운 문제로 만들 수 있다. 단, 최신 상태가 중요한 내용은 JSON 근거가 있거나 안정적인 사실일 때만 사용한다.",
    "스사사 JSON에 모든 근거가 들어있다고 보고, 반복적으로 등장하는 질문과 댓글의 관심사를 우선 반영한다.",
    "문제는 초보자도 풀 수 있게 쉽고 명확하게 작성하되, 너무 유치하지 않게 만든다.",
    "정답이 하나만 존재하도록 선택지를 설계한다.",
    "문제 표시용 questionDocuments에는 정답, 정답 선택지 ID, 해설을 절대 넣지 않는다.",
    "정답과 해설은 answerKeyDocuments에만 넣는다.",
    "Firestore 경로는 mockExam/main 구조를 사용한다.",
    "각 문제에는 sourceArticleIds와 sourceUrls를 반드시 넣는다.",
    "출력은 requiredOutput.schema를 따르는 단일 JSON 객체만 출력한다. 마크다운 코드블록, 설명 문장, 주석은 출력하지 않는다."
  ]
}
```
