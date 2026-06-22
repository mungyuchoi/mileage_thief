/**
 * 탐험 랭킹 즉시 집계(수동).
 * users 의 lb.* / lbW.* 카운터를 집계해 상위 N명 캐시 문서를 만든다.
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
  {key: "hotel", field: "hotel"},
  {key: "quiz", field: "quiz"},
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

async function loadUsersSnapshot() {
  const snap = await db.collection("users").get();
  return snap.docs;
}

async function aggregate(categoryKey, field, scope, weekKey, userDocs) {
  const metricPath = scope === "weekly" ? "lbW" : "lb";
  const entries = userDocs.reduce((list, doc) => {
    const u = doc.data() || {};
    const metric = (scope === "weekly" ? u.lbW : u.lb) || {};
    if (scope === "weekly" && metric.weekKey !== weekKey) return list;

    const value = Number(metric[field] || 0);
    if (value <= 0) return list;

    list.push({
      uid: doc.id,
      name: displayName(u),
      photoURL: photoUrl(u),
      value,
      rank: 0,
    });
    return list;
  }, []);

  entries.sort((a, b) => {
    if (b.value !== a.value) return b.value - a.value;
    return a.uid.localeCompare(b.uid);
  });

  const topEntries = entries.slice(0, TOP_N).map((entry, idx) => ({
    ...entry,
    rank: idx + 1,
  }));

  if (!DRY) {
    await db.doc(`leaderboards/${categoryKey}_${scope}`).set({
      category: categoryKey,
      scope,
      field,
      weekKey: scope === "weekly" ? weekKey : null,
      count: topEntries.length,
      entries: topEntries,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return topEntries.length;
}

async function run() {
  const weekKey = currentWeekKeyKst();
  const userDocs = await loadUsersSnapshot();

  for (const cat of CATEGORIES) {
    const a = await aggregate(cat.key, cat.field, "all", weekKey, userDocs);
    const w = await aggregate(cat.key, cat.field, "weekly", weekKey, userDocs);
    console.log(`${cat.key}: all=${a}명, weekly=${w}명`);
  }

  console.log(`${DRY ? "[DRY] " : ""}완료 (weekKey=${weekKey})`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
