/**
 * pointHotels / hotels 실제 데이터 점검.
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/...adminsdk*.json \
 *     node scripts/inspectHotelData.js
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function run() {
  const ph = await db.collection("pointHotels").get();
  console.log(`=== pointHotels: ${ph.size}개 ===`);
  ph.docs.slice(0, 15).forEach((d) => {
    const p = d.data() || {};
    console.log(
        `[${d.id}] name=${p.name} | brand=${p.brand} | ` +
        `country=${p.country} | city=${p.city} | ` +
        `lat=${p.latitude} | lng=${p.longitude}`);
  });

  const h = await db.collection("hotels").get();
  console.log(`\n=== hotels(캐치): ${h.size}개 ===`);
  h.docs.slice(0, 30).forEach((d) => {
    const x = d.data() || {};
    console.log(
        `[${d.id}] name="${x.name}" | brand=${x.brand} | ` +
        `country=${x.countryCode} | lat=${x.lat} | lng=${x.lng}`);
  });
}

run().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
