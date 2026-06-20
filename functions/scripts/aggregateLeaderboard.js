/**
 * 탐험 랭킹 즉시 집계(수동).
 * users 의 lb.* / lbW.* 카운터를 orderBy+limit 로 상위 N명만 읽어
 * leaderboards/{category}_{scope} 캐시 문서를 만든다.
 * (정기 갱신은 index.js 의 lbAggregateDaily 스케줄이 담당)
 *
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-*.json \
 *     node scripts/aggregateLeaderboard.js [--dry]
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const DRY = process.argv.includes("--dry");
const TOP_N = 100;

const CATEGORIES = [
  {key: "country", field: "country"},
  {key: "city", field: "city"},
  {key: "hotel", field: "hotelStars"},
  {key: "quiz", field: "quizSolved"},
  {key: "stamp", field: "stampLifetime"},
  {key: "game", field: "game"},
];

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

function displayName(u) {
  return String(u.displayName || u.nickname || u.name || u.email || "익명");
}
function photoUrl(u) {
  return String(u.photoUrl || u.photoURL || u.profileImage || "");
}

async function aggregate(categoryKey, field, scope, weekKey) {
  const prefix = scope === "weekly" ? "lbW" : "lb";
  const metricPath = `${prefix}.${field}`;
  let q = db.collection("users");
  if (scope === "weekly") q = q.where("lbW.weekKey", "==", weekKey);
  q = q.where(metricPath, ">", 0).orderBy(metricPath, "desc").limit(TOP_N);
  const snap = await q.get();
  const entries = [];
  let rank = 0;
  snap.forEach((doc) => {
    const u = doc.data() || {};
    const metric = (scope === "weekly" ? u.lbW : u.lb) || {};
    rank += 1;
    entries.push({
      uid: doc.id,
      name: displayName(u),
      photoURL: photoUrl(u),
      value: Number(metric[field] || 0),
      rank,
    });
  });
  if (!DRY) {
    await db.doc(`leaderboards/${categoryKey}_${scope}`).set({
      category: categoryKey,
      scope,
      field,
      weekKey: scope === "weekly" ? weekKey : null,
      count: entries.length,
      entries,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return entries.length;
}

async function run() {
  const weekKey = currentWeekKeyKst();
  for (const cat of CATEGORIES) {
    const a = await aggregate(cat.key, cat.field, "all", weekKey);
    const w = await aggregate(cat.key, cat.field, "weekly", weekKey);
    console.log(`${cat.key}: all=${a}명, weekly=${w}명`);
  }
  console.log(`${DRY ? "[DRY] " : ""}완료 (weekKey=${weekKey})`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
