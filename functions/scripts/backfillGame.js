/**
 * game 카운터만 1회 백필.
 * lb.game = max(0, explorePuzzleProgress/main.currentLevelNumber - 1) 로 설정.
 * (game 필드가 나중에 추가돼 과거치가 안 들어간 경우 보정용.
 *  lb.country/city/... 와 lbW.* 는 건드리지 않는다 → 주간 리셋 없음.)
 *
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-*.json \
 *     node scripts/backfillGame.js [--dry]
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const DRY = process.argv.includes("--dry");
const PAGE = 300;

async function run() {
  const idPath = admin.firestore.FieldPath.documentId();
  let startAfter = null;
  let total = 0;
  let updated = 0;

  for (;;) {
    let q = db.collection("users").orderBy(idPath).limit(PAGE);
    if (startAfter) q = q.startAfter(startAfter);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      total += 1;
      const ps = await db.doc(`users/${doc.id}/explorePuzzleProgress/main`).get();
      const level = Number((ps.data() || {}).currentLevelNumber || 1);
      const game = Math.max(0, level - 1);
      if (game > 0) {
        if (!DRY) await doc.ref.set({lb: {game}}, {merge: true});
        updated += 1;
        if (updated % 50 === 0) console.log(`...${updated}명 갱신`);
      }
    }

    startAfter = snap.docs[snap.docs.length - 1].id;
    if (snap.size < PAGE) break;
  }

  console.log(`${DRY ? "[DRY] " : ""}완료: 검사 ${total}명, lb.game 갱신 ${updated}명`);
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
