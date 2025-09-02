### Seats 정적 페이지 생성 최적화 제안: 당일 데이터만 처리

#### 목표
- 빌드 시 Firestore 읽기 수를 크게 줄여 속도/비용 최적화
- seats 정적 페이지는 어차피 당일 게시물 중심이므로, 그날 문서만 대상으로 HTML 생성

#### 배경
- 현재 스크립트(`scripts/generateStaticPages.js`)는 `collectionGroup('posts')`로 모든 날짜의 문서를 조회 후 필터링함.
- Firestore 문서 경로 구조: `posts/{yyyyMMdd}/posts/{postId}`
  - 날짜(파티션) 단위로 상위 컬렉션이 분리되어 있으므로, 해당 날짜 경로로 바로 조회 가능

#### 핵심 아이디어
- 빌드 시점 날짜(기본: KST, Asia/Seoul) 기준 `yyyyMMdd`를 계산
- 그 날짜의 하위 서브컬렉션만 조회: `collection(db, 'posts', yyyyMMdd, 'posts')`
- 기존 필터(게시판/가시성/번호형식)는 동일하게 유지
- 인덱스 페이지(`dist/seats/index.html`)도 당일 문서 기준으로 생성

#### 구현 포인트
- 타임존: KST 기준으로 날짜 문자열 생성이 중요 (자정 경계 오류 방지)
- 조회 변경: `collectionGroup('posts')` → `collection(db, 'posts', yyyyMMdd, 'posts')`
- 증분/백필 옵션 제공(권장)
  - `--date=YYYYMMDD` 전달 시 특정 날짜만 처리
  - `--full` 전달 시 현재처럼 전체 스캔 (백필 또는 점검 용도)
- 기존 출력 규칙, SEO 메타, HTML 템플릿 로직은 그대로 재사용

#### 예시 코드 스니펫 (아이디어)
```js
import { collection, getDocs } from 'firebase/firestore';

function getKstYyyyMmDd() {
  const formatter = new Intl.DateTimeFormat('ko-KR', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const [{ value: year }, , { value: month }, , { value: day }] = formatter.formatToParts(new Date());
  return `${year}${month}${day}`; // e.g., 20250115
}

// argv 파싱(옵션): --date=YYYYMMDD, --full
const args = process.argv.slice(2);
const dateArg = args.find((a) => a.startsWith('--date='))?.split('=')[1];
const fullScan = args.includes('--full');

let postsSnapshot;
if (fullScan) {
  // 기존 collectionGroup 로직
  // postsSnapshot = await getDocs(collectionGroup(db, 'posts'));
} else {
  const yyyyMMdd = dateArg || getKstYyyyMmDd();
  postsSnapshot = await getDocs(collection(db, 'posts', yyyyMMdd, 'posts'));
}
```

#### 예상 효과
- 읽기 범위가 당일 문서로 한정되어 Firestore 읽기/빌드 시간이 크게 감소
- 대량 데이터 시에도 안정적이며, 레이트리밋/비용 리스크 완화

#### 리스크/주의사항
- 빌드 수행 시간이 자정 경계를 넘는 경우, 날짜 계산이 의도와 달라질 수 있음 → KST 고정 계산 필요
- 과거 날짜 정적 페이지가 필요하면 `--date` 또는 `--full` 옵션으로 백필 절차 수행
- 인덱스 페이지가 당일 데이터만 포함됨을 명확히(과거 링크 필요 시 별도 아카이브/페이지 고려)

#### 마이그레이션 제안
1) `generateStaticPages.js`에 `--date`, `--full` CLI 옵션 파싱 추가
2) 기본 동작을 "당일만 처리"로 전환, `--full`일 때만 기존 전체 스캔 사용
3) 타임존 안전한 `yyyyMMdd` 계산 유틸 추가(`Asia/Seoul` 고정)
4) CI/배포 스크립트에서 필요 시 특정 날짜/전체 스캔을 선택적으로 실행

### 커뮤니티 게시글(전 게시판) SSR 설계 및 평가

#### 목표
- Google AdSense 승인과 SEO 강화를 위해 커뮤니티 글 상세 페이지를 정적으로 제공
- Firestore 원본 데이터는 단일 진실 공급원(Single Source of Truth)으로 유지해 데이터 중복 최소화
- 정적 파일은 변경 빈도가 낮은 필드만 탑재하고, 변경/실시간 수치와 서브컬렉션은 동적으로 조회

#### URL/라우팅 원칙
- 기본 규칙: `https://milecatch.com/{boardId}/{postNumber}.html`
  - 예: `.../question/1.html`, `.../review/2.html`, `.../seats/KE-20250903.html`
- 정적 파일 보관 위치: `dist/{boardId}/{postNumber}.html`
- 카테고리 변경 시 정책
  - `postNumber`는 불변. 최초 생성 경로를 기본 URL로 유지하고, 카테고리 이동 시 301 리다이렉트 매핑 추가 또는 `rel=canonical`로 새 경로를 표기
  - 보수적 권장: URL 안정성 최우선(최초 경로 유지 + canonical만 교체)

#### postNumber 정책(제안)
- 요구사항: 사람이 읽기 쉬우며 시간 순서 보존, 짧고 충돌 방지, 보드 독립적
- 포맷 제안: `YYYYMMDD-XXXX` (XXXX=base36 4~5자 난수) 또는 `YYYYMMDDHHmm-XXX`
  - 장점: 날짜 정렬 가능, 짧은 길이, 카테고리 무관, 중복 낮음
  - 좌석 전용 예외: 기존과의 하위호환을 위해 `KE-YYYYMMDD`, `OZ-YYYYMMDD` 유지
- 인덱싱 가속화를 위한 보조 컬렉션(선택): `postNumbers/{postNumber}` → `{ yyyyMMdd, postId, boardId }`
  - 중복은 최소(키-포인터 수준)이며, 조회 속도/유지보수성 향상

#### 정적 페이지에 고정/동적 데이터 구분
- 정적(HTML에 박제)
  - `postId`, `postNumber`, `boardId`(생성 시점), `title`, `contentHtml`(또는 서버 렌더링된 본문), `author`(표시명/프로필 이미지 URL), `createdAt`, `updatedAt`, `canonical`, SEO 메타, OG/Twitter, JSON-LD
  - 이유: AdSense/SEO에 필요한 핵심 콘텐츠는 즉시 렌더되어야 하며 자주 변하지 않음
- 동적(Firestore 클라이언트/경량 JS로 주입)
  - `viewsCount`, `likesCount`, `reportsCount`, `comments`(페이지네이션), `likes/{uid}`, `reports/{uid}` 등 서브컬렉션 기반 데이터
  - 이유: 변동 잦음, 사용자 액션 연동 필요, 실시간성 유리
- 임베딩 방식(권장)
  - HTML 내 `<script type="application/json" id="__POST__">{...}</script>`로 고정 필드만 직렬화 → 초기 하이드레이션에 사용
  - 이후 작은 번들의 JS가 Firestore에서 서브컬렉션/카운트만 추가 조회 후 DOM 업데이트

#### 생성/갱신 워크플로우
- 1) 일일 배치(기본): 당일 `posts/{yyyyMMdd}/posts`만 조회 → 미존재 정적 파일 생성
  - 스크립트: `node scripts/generateStaticPages.js` (옵션 `--date=YYYYMMDD`)
- 2) 1회 백필: `--full`로 전체 기간 생성(마이그레이션 직후 1회 실행)
- 3) 수정 반영 큐(증분 업데이트)
  - 앱에서 게시글 수정 시 `ssr_queue` 컬렉션에 `{ postId, yyyyMMdd, boardId, postNumber, reason: 'update' }` enqueue
  - 크론(또는 Cloud Scheduler)으로 분 단위 소형 잡이 큐를 소비해 해당 파일만 재생성 후 큐 문서 삭제
  - 중복 방지: 동일 `postNumber`는 최근 항목만 남기고 나머지 GC

#### 요청 시 온디맨드 생성(정적 파일 미존재 대응)
- 목적: 사용자가 정적 페이지가 아직 없을 때에도 1st 요청에서 바로 페이지 제공
- 구현 옵션
  - a) 서버/엣지 함수(Cloud Run/Functions/Workers) HTTP 엔드포인트 `/_generate/{boardId}/{postNumber}`
    - 파라미터로 문서 식별 → Firestore fetch → HTML 생성 → 응답 반환과 동시에 스토리지/디스크에도 저장
    - 보안: 내부 호출만 허용(리퍼러/서버사이드 프록시), 사용자 직접 접근 차단
  - b) Nginx/CloudFront 404 fallback → 백엔드 함수 호출 후 결과 캐싱(60s~5m)
- 조회 최적화
  - 보조 인덱스(`postNumbers`)로 O(1)에 가까운 위치 탐색 → `posts/{yyyyMMdd}/posts/{postId}` 직접 조회

#### 마이그레이션 계획(전 게시판 postNumber 주입)
1) 기준 확정: `YYYYMMDD-XXXX` 생성기 도입, 좌석은 기존 규칙 유지
2) 백필 스크립트: 모든 `collectionGroup('posts')` 순회 → 없는 문서에만 `postNumber` 생성 + `postNumbers` 인덱스에 upsert
3) 1회 전체 SSR 생성(`--full`)
4) 앱/웹 게시/수정 플로우에 `postNumber` 생성/인덱스 upsert를 실시간 반영

#### 웹에서 글 작성 시 흐름(예: `boardId=question`)
1) 서버(또는 클라이언트-백엔드)에서 문서 생성
   - 경로: `posts/{yyyyMMdd}/posts/{postId}`
   - 필드: `postId`, `postNumber`, `boardId`, `title`, `contentHtml`, `author`, `createdAt` …
   - 인덱스: `postNumbers/{postNumber}` → `{ yyyyMMdd, postId, boardId }`
2) SSR 생성 트리거
   - 즉시: 경량 HTTP 함수로 싱글 페이지 생성(동기/비동기)
   - 배치: 일일 잡이 보강(미스 케이스 대비)
3) 정적 파일 전달
   - 경로: `/question/{postNumber}.html`
   - 서브컬렉션/카운트는 JS가 Firestore에서 동적 로드

#### SEO/AdSense 체크리스트
- 콘텐츠 본문(`contentHtml`)은 최초 HTML에 포함(렌더블, CLS 최소화)
- `<meta name="description">`, OG/Twitter, JSON-LD(Article) 정확히 채움
- `rel=canonical` 일관성 유지. 카테고리 이동 시에도 중복 컨텐츠 신호 억제
- 정적 파일에는 광고 스크립트 삽입 위치를 고정(Above the fold 과도 노출 금지, 정책 준수)
- 이미지/동영상은 lazy-loading 및 적절한 `alt` 제공

#### 보완 권고(데이터/아키텍처)
- 서브컬렉션 읽기 비용 절감을 위해 댓글은 초기 N개만 로딩, 나머지는 페이지네이션
- 카운트는 Cloud Functions 집계 필드(샤딩 카운터) 사용 권장 → 실시간성과 비용 균형
- 정적 파일 내 `data-updated-at` 메타를 기록 → 재생성 필요성 판단(불필요한 디스크 쓰기 회피)
- 생성기 공통 모듈화: `generatePage(post)` 유틸을 좌석/일반 게시판이 공유하여 템플릿/메타 일관성 확보

#### 평가 요약
- 제안하신 "고정 데이터는 정적, 변동/서브컬렉션은 동적" 전략은 데이터 이중화 최소화와 비용/속도 균형 측면에서 적절함
- `postNumber` 도입과 일일/온디맨드/수정 큐의 3축 운영으로 생성 타이밍 공백을 대부분 해소 가능
- 보조 인덱스(`postNumbers`)를 도입하면 온디맨드 경로 탐색이 단순/고속화되어 운영 안정성이 높아짐
- 카테고리 변경/중복 URL에 대한 리다이렉트/캐노니컬 전략만 명확히 하면 SEO 리스크도 낮음

### 자원 제약 고려: 배치(매일 10시) + 최근 7일 생성 + 온디맨드 Fallback

#### 전제
- 이벤트 기반 SSR(Functions 트리거)은 미사용. 배치 스케줄: 매일 10시 `generateStaticPages.js` 실행.

#### 배치 전략(최적화)
- 기본 동작: 기준일(KST)로부터 `N`일 범위를 조회하여 정적 페이지 생성(중복 스킵)
  - 옵션 예시: `--range=7` → `posts/{yyyyMMdd}/posts`를 오늘 포함 최근 7일만 순회
  - 당일 우선 생성 후 과거일(1~6일 전) 순으로 처리
- 수정 큐 병행: `ssr_queue`에 누적된 항목은 날짜 범위와 무관하게 우선 처리
- 해시 기반 스킵: 각 문서의 `contentHtmlHash`가 기존 파일과 동일하면 재생성 스킵

#### 정적 미존재 시 Fallback(온디맨드)
- 라우팅: 정적 파일 404 시 `/_dynamic/{boardId}/{postNumber}`로 내부 리라이트
  - 이 페이지는 Firestore에서 해당 문서를 읽어 즉시 화면에 렌더(SEO 대비 최소 템플릿 포함)
  - 동시에 백그라운드로 두 가지 중 하나 수행
    1) `ssr_queue`에 `{ postNumber, yyyyMMdd, postId, boardId, reason: 'first-view' }` enqueue
    2) 리소스가 허용되면 내부 HTTP(Webhook)로 `webhook-server.cjs` 호출 → `generateSinglePage.js` 또는 동일 로직을 재사용해 해당 페이지만 즉시 생성
- 캐시: 백엔드 응답은 짧은 TTL로 CDN 캐싱, 이후 배치/큐가 정적 파일을 생성하면 다음 요청부터 정적 제공

#### CLI/동작 예시(아이디어)
```bash
# 최근 7일 범위 생성(기본)
node scripts/generateStaticPages.js --range=7

# 특정 날짜만(운영 보정)
node scripts/generateStaticPages.js --date=20250902

# 전체 백필(1회)
node scripts/generateStaticPages.js --full
```

### postNumber: 짧은 숫자 위주의 정책 제안

#### 질문에 대한 답변
- 이전 제안은 base36(0-9A-Z)이며, base64가 아님. URL 안전성과 길이 효율 때문에 base36을 권장했음.
- "숫자만"으로 짧게 만들면 압축 효율이 떨어져 전체 길이가 길어질 수밖에 없음(표현력 제한). 다만 운영 난이도가 낮다는 장점은 있음.

#### 숫자 전용 포맷(권장안)
- 포맷: `YYYYMMDD-rrrrrr` (r=랜덤 숫자 6자리)
  - 예: `20250902-384192`
  - 충돌 대응: 발급 시 `postNumbers/{candidate}` 존재 여부 확인 → 충돌 시 재시도(최대 3회)
  - 일일 작성량이 수천 건 이하라면 충돌 확률은 매우 낮음(1e-6 수준)
- 단축형(선택): `YYDDD-rrrrr` (DDD=연중 일수 001~366, r=5자리)
  - 예: `25345-59310` (2025년 345일차)
  - 장점: 길이 단축, 날짜 식별 가능. 단점: 가독성/명시성이 표준형보다 약함

#### 하이픈 없는(순수 숫자) 포맷 제안
- 질문에 대한 보충: 위 예시의 `59310`은 0~99999 랜덤 5자리의 예시값이었음(임의 난수). 하이픈이 마음에 들지 않는 경우 아래 포맷을 권장.
- 포맷 A(대안): `YYDDDSSSSSFF`
  - `YYDDD`: 연도 2자리 + 연중 일수(001~366)
  - `SSSSS`: 자정 기준 누적 초(0~86399 → 5자리)
  - `FF`: 1/100초(밀리초/10, 00~99)
  - 길이: 12자리. 예: `254523453607` (예시: 2025년 345일차, 45,236초 시점, 07=70ms 근처)
  - 충돌 가능성: 같은 10ms 윈도우에 2건 이상 생성 시만 충돌. 현실적으로 매우 희박. 충돌 시 `FF`를 +1 증가(롤오버 허용) 또는 마지막 2자리 난수 대체 후 재시도.
- 포맷 B(권장): `YYDDDHHmmss`
  - 길이: 11자리. 같은 초에 2건 이상 생성 시 충돌 가능 → 충돌 시 뒤에 2자리 시퀀스/난수 추가(`YYDDDHHmmsscc`, 13자리)로 해소.

#### 생성기 의사코드(포맷 A: YYDDDSSSSSFF)
```js
function toKstDate(date = new Date()) {
  // KST로 변환된 시각 구성
  const utc = date.getTime() + (date.getTimezoneOffset() * 60 * 1000);
  return new Date(utc + (9 * 60 * 60 * 1000));
}

function getDayOfYearKst(date = new Date()) {
  const kst = toKstDate(date);
  const start = new Date(kst.getFullYear(), 0, 0);
  const diff = kst.getTime() - start.getTime();
  const oneDay = 24 * 60 * 60 * 1000;
  return Math.floor(diff / oneDay); // 1~366
}

function generateYYDDDSSSSSFF(now = new Date()) {
  const kst = toKstDate(now);
  const yy = (kst.getFullYear() % 100).toString().padStart(2, '0');
  const ddd = getDayOfYearKst(now).toString().padStart(3, '0');
  const secondsOfDay = kst.getHours() * 3600 + kst.getMinutes() * 60 + kst.getSeconds();
  const sssss = secondsOfDay.toString().padStart(5, '0');
  const ff = Math.floor(kst.getMilliseconds() / 10).toString().padStart(2, '0');
  return `${yy}${ddd}${sssss}${ff}`; // 12자리 숫자
}

// 충돌 처리(요약): postNumbers/{id} 선점 트랜잭션, 실패 시 ff+1 또는 2자리 난수로 교체 후 재시도(최대 3회)
```

#### 생성기 의사코드(포맷 B: YYDDDHHmmss[cc])
```js
function toKstDate(date = new Date()) {
  const utc = date.getTime() + (date.getTimezoneOffset() * 60 * 1000);
  return new Date(utc + (9 * 60 * 60 * 1000));
}

function getDayOfYearKst(date = new Date()) {
  const kst = toKstDate(date);
  const start = new Date(kst.getFullYear(), 0, 0);
  const diff = kst.getTime() - start.getTime();
  const oneDay = 24 * 60 * 60 * 1000;
  return Math.floor(diff / oneDay); // 1~366
}

async function generateYYDDDHHmmss(db, now = new Date()) {
  const kst = toKstDate(now);
  const yy = (kst.getFullYear() % 100).toString().padStart(2, '0');
  const ddd = getDayOfYearKst(now).toString().padStart(3, '0');
  const hh = kst.getHours().toString().padStart(2, '0');
  const mm = kst.getMinutes().toString().padStart(2, '0');
  const ss = kst.getSeconds().toString().padStart(2, '0');
  const base = `${yy}${ddd}${hh}${mm}${ss}`; // 11자리

  // 선점 검사로 충돌 회피(postNumbers 인덱스 사용 권장)
  const tryIds = [base, `${base}01`, `${base}02`, `${base}${Math.floor(Math.random() * 90 + 10)}`];
  for (const candidate of tryIds) {
    const ok = await tryReservePostNumber(db, candidate); // 트랜잭션/조건부 쓰기
    if (ok) return candidate;
  }
  throw new Error('Failed to allocate postNumber');
}

// 예시: 조건부 선점(개념용)
async function tryReservePostNumber(db, id) {
  // postNumbers/{id} 문서가 없을 때만 생성하는 원자적 연산 수행
  // 충돌 시 false 반환
  return true;
}
```

### postNumber 정책: 전역 오토인크리먼트(1부터, 패딩 없음)

#### 개념/규칙
- 전역 단일 시퀀스를 1씩 증가시켜 `postNumber`로 사용합니다. 예: `1`, `2`, `3`, ...
- URL 예: `/question/1.html`, `/review/2.html`
- 좌석 전용 예외(기존 하위호환)는 유지 가능: `/seats/KE/KE-20250903.html`

#### 전역 카운터(단일 문서) 방식
- 카운터 문서: `counters/postNumber/global` with `{ seq: number }` (초기값 0)
- 트랜잭션 의사코드
```js
import { runTransaction, doc } from 'firebase/firestore';

async function allocatePostNumber(db) {
  const ref = doc(db, 'counters', 'postNumber', 'global');
  const next = await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const current = (snap.exists() ? snap.data().seq : 0) ?? 0;
    const value = current + 1; // 1,2,3,...
    tx.set(ref, { seq: value }, { merge: true });
    return value;
  });
  return String(next); // 패딩 없음
}
```
- 처리량: 단일 문서 경합이 커지면 충돌/재시도 증가. 트래픽이 높다면 블록 할당 방식을 사용하세요.

#### 블록 할당(분산) 방식 — 권장(트래픽 높을 때)
- 아이디어: 전역 카운터에서 한 번에 `blockSize`만큼 범위를 리스(선점)하고 로컬에서 순차 소비
- 스키마: `counters/postNumber/allocator { next: number }`
- 의사코드
```js
async function leaseBlock(db, blockSize = 100) {
  const ref = doc(db, 'counters', 'postNumber', 'allocator');
  const { from, to } = await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const start = (snap.exists() ? snap.data().next : 0) ?? 0; // 0 기반
    const end = start + blockSize; // 미포함 경계
    tx.set(ref, { next: end }, { merge: true });
    return { from: start + 1, to: end }; // 1..end 범위(포함)
  });
  return { cursor: from, end: to };
}

function takeNext(local) {
  if (local.cursor > local.end) return null; // 재리스 필요
  return String(local.cursor++); // 패딩 없음
}
```

#### 운영 가이드
- 갭 허용 여부 결정: 블록 방식은 미사용 블록으로 번호 갭이 생길 수 있음(대부분 허용 가능)
- 블록 크기 튜닝: 기본 100~1000. 생성 속도/경합/미사용률을 보고 조정
- 매핑 인덱스 유지: `postNumbers/{postNumber} → { postRef, boardId, createdAt }` upsert로 역조회/중복 방지
- 승격 정책: 상한선 없음(정수 증가). 숫자 자릿수 증가는 URL에 그대로 반영하며 SEO에 문제 없음

### 오토인크리먼트(순차 증가형) 8자리: YYDDDSSS

#### 개념
- RDB의 auto-increment처럼 중앙 카운터를 트랜잭션으로 증가시키며, 발급된 값을 `postNumber`로 사용
- 포맷: `YYDDDSSS` (SSS=당일 시퀀스 000~999)
  - 예: 2025-09-02 기준 첫 3건 → `25245000`, `25245001`, `25245002`

#### 장점
- 완전한 순차성(사람이 읽기 쉬움), 충돌 없음(트랜잭션)
- 8자리 유지 용이, 구현 단순

#### 단점/주의
- 특정 문서(일일 카운터)에 쓰기 병목이 생김 → Firestore의 단일 문서 경합/재시도 비용 증가
- 1일 1000건 초과 시 8자리 한계(SSS 포화) → 9자리로 자동 승격 필요(`YYDDDSSSS`)
- 피크 시간대에 동시 생성이 많은 경우 트랜잭션 충돌 가능 → SDK 재시도와 백오프 필수

#### 설계
- 카운터 문서: `counters/posts/daily/{YYDDD}` with `{ seq: number }`
- 트랜잭션 흐름
  1) `get(doc)` → 없으면 `{ seq: -1 }` 가정
  2) `next = seq + 1`; if `next > 999` → 승격(9자리) 또는 에러
  3) `update(doc, { seq: next })`
  4) `postNumber = YYDDD + pad3(next)`

#### 의사코드
```js
import { runTransaction, doc, getDoc, setDoc } from 'firebase/firestore';

async function allocateAutoIncYYDDDSSS(db, now = new Date()) {
  const kst = toKstDate(now);
  const yy = (kst.getFullYear() % 100).toString().padStart(2, '0');
  const ddd = getDayOfYearKst(now).toString().padStart(3, '0');
  const key = `${yy}${ddd}`; // 일일 파티션 키
  const ref = doc(db, 'counters', 'posts', 'daily', key);

  const next = await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists()) {
      tx.set(ref, { seq: 0 });
      return 0;
    }
    const current = snap.data().seq ?? 0;
    if (current >= 999) throw new Error('DAILY_SEQUENCE_SATURATED');
    const value = current + 1;
    tx.update(ref, { seq: value });
    return value;
  });

  return `${key}${next.toString().padStart(3, '0')}`; // 8자리
}
```

#### 병목/경합 완화 팁
- 게시 빈도가 높아지는 보드만 별도 카운터로 분리: `counters/posts/daily_{boardId}/{YYDDD}`
- 피크 시간대에 한시적으로 9자리 승격 허용(`YYDDDSSSS`) 후, 밤 10시 배치 때 8자리 유지 정책으로 복귀
- 실패 재시도: 지수 백오프(50~300ms), 최대 3~5회. 사용자 체감 최소화 필요 시 대체 포맷(옵션 3)로 폴백
- 운영 모니터링: 카운터 충돌/재시도 횟수 로깅, 임계치 초과 시 알람 → 임시 승격/폴백 전략 가동

### 전역 오토인크리먼트 8자리(1부터 시작, 날짜 완전 배제)

#### 개념/포맷
- 포맷: `NNNNNNNN` (순수 숫자 8자리, `00000001`부터 시작해 1씩 증가)
- 장점: 가장 단순하고 사람이 이해하기 쉬운 연속 번호
- 주의: 단일 카운터 문서에 쓰기 병목 발생 → 동시성 높은 환경에서는 블록 할당으로 분산 필요

#### 전역 카운터(단일 문서) 방식
- 카운터 문서: `counters/postNumber/global` with `{ seq: number }` (초기값 0)
- 트랜잭션 의사코드
```js
import { runTransaction, doc } from 'firebase/firestore';

async function allocateGlobal8(db) {
  const ref = doc(db, 'counters', 'postNumber', 'global');
  const next = await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const current = (snap.exists() ? snap.data().seq : 0) ?? 0;
    const value = current + 1;
    tx.set(ref, { seq: value }, { merge: true });
    return value; // 1,2,3,...
  });
  if (next > 99999999) throw new Error('POST_NUMBER_OVERFLOW');
  return next.toString().padStart(8, '0');
}
```
- 처리량: 단일 문서 경합이 커지면 트랜잭션 충돌/재시도 증가(지속 대략 1~수 writes/sec 기대). 트래픽이 높다면 블록 할당으로 전환 권장.

#### 블록 할당(분산) 방식 — 권장
- 아이디어: 전역 카운터에서 한 번에 `blockSize`만큼 번호 범위를 "리스"(선점)하고, 클라이언트는 그 범위를 로컬에서 순차 소비
- 장점: 전역 카운터 문서 업데이트 빈도를 `1/blockSize`로 감소 → 경합 급감, 처리량↑
- 단점: 일부 클라이언트가 소비하지 못한 블록은 건너뛴 번호가 생김(갭 허용). 대부분의 커뮤니티에서는 허용 가능

- 스키마
  - 전역 문서: `counters/postNumber/allocator` with `{ next: number }` (다음 미할당 시작 값)
  - 리스 기록(선택): `counters/postNumber/leases/{leaseId}` → `{ from, to, leasedAt, by }` (감사/디버깅)

- 트랜잭션: 블록 리스
```js
async function leaseBlock(db, blockSize = 100) {
  const ref = doc(db, 'counters', 'postNumber', 'allocator');
  const { from, to } = await runTransaction(db, async (tx) => {
    const snap = await tx.get(ref);
    const start = (snap.exists() ? snap.data().next : 0) ?? 0; // 0 기반
    const end = start + blockSize; // 미포함 경계
    if (end > 99999999) throw new Error('POST_NUMBER_OVERFLOW');
    tx.set(ref, { next: end }, { merge: true });
    return { from: start + 1, to: end }; // 1..end 범위(포함)
  });
  // 선택: 리스 기록을 남김
  // await setDoc(doc(collection(db, 'counters/postNumber/leases')), { from, to, leasedAt: serverTimestamp() })
  return { cursor: from, end: to };
}

// 소비자 측: 로컬에서 번호 하나씩 소비
function takeNext(local) {
  if (local.cursor > local.end) return null; // 재리스 필요
  const value = local.cursor++;
  return value.toString().padStart(8, '0');
}
```

#### 운영 팁
- 갭 허용 여부: 갭이 절대 불가하면 블록 방식은 부적합(단일 문서 방식 사용). 갭 허용 가능하면 블록=권장
- 블록 크기: 기본 100~1000. 생성 속도/충돌률/미사용 비율을 보고 조정
- 실패/리커버리: 앱 재시작으로 미사용 블록이 남아도 무시(중복은 아님). 임계치 도달 시 `next`만 증가하므로 안전
- 8자리 한계: 99,999,999 초과 시 9자리 승격 정책 명시(문서화 및 코드 가드)
- 매핑 인덱스: `postNumbers/{NNNNNNNN} → { postRef, boardId, createdAt }` 유지로 역조회 최적화 및 중복 방지 검증



#### Alnum(혼합) 대안(길이 최적)
- 포맷: `YYYYMMDD-xxxx` (x=base36 4~5자)
  - 예: `20250902-a9k7`
  - 장점: 더 짧음, 충돌 낮음. 단점: 숫자 전용 요구에는 부합하지 않음

#### 생성기 의사코드(숫자 전용)
```js
function generateNumericPostNumber(date = new Date()) {
  const yyyy = new Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul', year: 'numeric' }).format(date);
  const mm = new Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul', month: '2-digit' }).format(date);
  const dd = new Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul', day: '2-digit' }).format(date);
  const rand = Math.floor(Math.random() * 1_000_000).toString().padStart(6, '0');
  return `${yyyy}${mm}${dd}-${rand}`;
}
```

#### 운영 팁
- `postNumbers/{postNumber}` 인덱스를 항상 upsert해 중복 방지 및 라우팅 O(1) 확보
- 충돌 재시도는 2~3회로 제한하고, 실패 시 자릿수를 1자리 추가하여 재시도(드문 케이스)


