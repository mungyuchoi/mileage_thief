/**
 * 탐험 랭킹 카운터 1회 백필.
 * 기존 유저의 users/{uid}.lb.* / lbW.* 를 현재 데이터로 채운다.
 * (이 스크립트는 "과거 데이터 보정"용 1회성. 이후로는 index.js 의
 *  lbOn* 트리거가 자동으로 카운터를 유지한다.)
 *
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-*.json \
 *     node scripts/backfillLeaderboard.js [--dry]
 *
 * --dry : 실제 쓰기 없이 집계 결과만 출력.
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const DRY = process.argv.includes("--dry");
const PAGE = 300;

// 백필 성능/호환성 이슈 회피: contributors는 컬렉션 그룹 인덱스 없이도
// hotels/{hotelId}/contributors/{uid} 문서 단위로 직접 집계.
const hotelCachePromise = db.collection("hotels").select().get();

const LB_FIELDS = [
  "country", "city", "hotel", "quiz", "stampLifetime", "game",
];

// KST 기준 ISO 주차 키 (index.js 의 currentWeekKeyKst 와 동일 로직).
function currentWeekKeyKst() {
  const kst = new Date(Date.now() + 9 * 3600 * 1000);
  const d = new Date(Date.UTC(
      kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate()));
  const dayNum = (d.getUTCDay() + 6) % 7;
  d.setUTCDate(d.getUTCDate() - dayNum + 3);
  const firstThursday = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const week = 1 + Math.round(
      ((d.getTime() - firstThursday.getTime()) / 86400000 -
        3 + ((firstThursday.getUTCDay() + 6) % 7)) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

// 유저 1명의 현재 누적 점수를 집계(count() 사용 → 유저당 read 최소).
async function userStats(uid) {
  const base = `users/${uid}`;
  const hotelSnap = await hotelCachePromise;
  const contribRefs = hotelSnap.docs.map((h) =>
    db.doc(`hotels/${h.id}/contributors/${uid}`).get(),
  );
  const r = await Promise.all([
    db.collection(`${base}/worldUnlocks`).count().get(),
    db.collection(`${base}/cityUnlocks`).count().get(),
    ...contribRefs,
    db.doc(`${base}/exploreWallet/main`).get(),
    db.doc(`${base}/explorePuzzleProgress/main`).get(),
  ]);
  // 호텔=등록+출제+꿀팁, 퀴즈=출제+정답 (모든 호텔 contributor breakdown 합산)
  let hotel = 0;
  let quiz = 0;
  const contribDocs = r.slice(2, 2 + contribRefs.length);
  contribDocs.forEach((cdoc) => {
    if (!cdoc.exists) return;
    const bk = (cdoc.data() || {}).breakdown || {};
    const n = (x) => Number(x || 0);
    hotel += n(bk.added) + n(bk.quizCreated) + n(bk.tipCreated);
    quiz += n(bk.quizCreated) + n(bk.quizSolved);
  });
  // wallet/puzzle 는 contribRefs(N개) 뒤에 오므로 동적 인덱스로 읽어야 한다.
  const walletDoc = r[2 + contribRefs.length];
  const puzzleDoc = r[2 + contribRefs.length + 1];
  const puzzle = puzzleDoc.data() || {};
  return {
    country: r[0].data().count || 0,
    city: r[1].data().count || 0,
    hotel: hotel,
    quiz: quiz,
    stampLifetime: Number((walletDoc.data() || {}).passportStamps || 0),
    game: Math.max(0, Number(puzzle.currentLevelNumber || 1) - 1),
  };
}

async function run() {
  const weekKey = currentWeekKeyKst();
  const idPath = admin.firestore.FieldPath.documentId();
  let startAfter = null;
  let total = 0;
  let withData = 0;

  for (;;) {
    let q = db.collection("users").orderBy(idPath).limit(PAGE);
    if (startAfter) q = q.startAfter(startAfter);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const lb = await userStats(doc.id);
      const sum = LB_FIELDS.reduce((s, f) => s + (lb[f] || 0), 0);
      if (sum > 0) withData += 1;
      total += 1;
      if (!DRY) {
        const lbW = {weekKey};
        for (const f of LB_FIELDS) lbW[f] = 0;
        await doc.ref.set({lb, lbW}, {merge: true});
      }
      if (total % 100 === 0) console.log(`...${total}명 처리`);
    }

    startAfter = snap.docs[snap.docs.length - 1].id;
    if (snap.size < PAGE) break;
  }

  console.log(
      `${DRY ? "[DRY] " : ""}완료: 총 ${total}명, ` +
      `점수 있는 유저 ${withData}명, weekKey=${weekKey}`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
