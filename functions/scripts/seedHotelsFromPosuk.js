/**
 * 포숙(pointHotels) → 호텔 캐치(hotels) 시드 스크립트.
 *
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-*.json \
 *     node scripts/seedHotelsFromPosuk.js [--dry]
 *
 * - 5대 브랜드(+좌표 있는) pointHotels 만 대상.
 * - 멱등: hotels/posuk_{pointHotelId} 로 upsert.
 * - countryCode 매핑 실패 호텔은 건너뜀(로그).
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const DRY = process.argv.includes("--dry");

// pointHotels.brand(문자열) → 표준 브랜드
function normBrand(s) {
  const t = String(s || "").toLowerCase();
  if (/marriott|메리어트|본보이|ritz|리츠|웨스틴|쉐라톤|sheraton|st\.? ?regis/
      .test(t)) return "marriott";
  if (/hilton|힐튼|conrad|콘래드|waldorf|월도프/.test(t)) return "hilton";
  if (/accor|아코르|sofitel|소피텔|fairmont|페어몬트|raffles|pullman|novotel/
      .test(t)) return "accor";
  if (/ihg|intercon|인터컨|kimpton|킴튼|holiday ?inn|홀리데이/.test(t)) {
    return "ihg";
  }
  if (/hyatt|하얏트|andaz|안다즈/.test(t)) return "hyatt";
  return "other";
}

// 국가 문자열 → ISO2(소문자). 필요 시 추가.
const COUNTRY_ISO = {
  "대한민국": "kr", "한국": "kr", "south korea": "kr", "korea": "kr",
  "일본": "jp", "japan": "jp",
  "중국": "cn", "china": "cn",
  "대만": "tw", "taiwan": "tw",
  "홍콩": "hk", "hong kong": "hk",
  "태국": "th", "thailand": "th",
  "베트남": "vn", "vietnam": "vn",
  "싱가포르": "sg", "싱가폴": "sg", "singapore": "sg",
  "말레이시아": "my", "malaysia": "my",
  "인도네시아": "id", "indonesia": "id",
  "필리핀": "ph", "philippines": "ph",
  "미국": "us", "usa": "us", "united states": "us",
  "프랑스": "fr", "france": "fr",
  "영국": "gb", "uk": "gb", "united kingdom": "gb",
  "이탈리아": "it", "italy": "it",
  "스페인": "es", "spain": "es",
  "독일": "de", "germany": "de",
  "아랍에미리트": "ae", "uae": "ae", "두바이": "ae",
  "호주": "au", "australia": "au",
};
function isoOf(country) {
  return COUNTRY_ISO[String(country || "").trim().toLowerCase()] || "";
}

async function run() {
  const snap = await db.collection("pointHotels").get();
  console.log(`pointHotels 문서 수: ${snap.size}`);
  let made = 0; let skipped = 0;
  for (const doc of snap.docs) {
    const p = doc.data() || {};
    const brand = normBrand(p.brand || p.name);
    const lat = Number(p.latitude);
    const lng = Number(p.longitude);
    const countryCode = isoOf(p.country);
    const reasons = [];
    if (brand === "other") reasons.push(`brand=other(원본:${p.brand || ""})`);
    if (!Number.isFinite(lat)) reasons.push(`lat없음(${p.latitude})`);
    if (!Number.isFinite(lng)) reasons.push(`lng없음(${p.longitude})`);
    if (!countryCode) reasons.push(`country매핑실패(${p.country || ""})`);
    if (reasons.length > 0) {
      skipped += 1;
      console.log(`  건너뜀 [${doc.id}] ${p.name || ""}: ` +
        reasons.join(", "));
      continue;
    }
    const ref = db.doc(`hotels/posuk_${doc.id}`);
    const payload = {
      name: String(p.name || "").trim(),
      brand,
      lat, lng,
      countryCode,
      city: String(p.city || "").trim(),
      stars: Math.max(0, Math.min(5, Math.round(Number(p.rating) || 0))),
      description: String(p.description || "").slice(0, 500),
      coverImageUrl: String(p.imageUrl || ""),
      pointHotelId: doc.id,
      topContributorUid: null,
      topContributorName: "",
      topContributorPhoto: "",
      topContributorScore: 0,
      lastContribAt: admin.firestore.FieldValue.serverTimestamp(),
      totalQuizCount: 0,
      totalTipCount: 0,
      createdBy: "system",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (DRY) {
      console.log("[dry]", ref.path, payload.name, brand, countryCode);
    } else {
      await ref.set(payload, {merge: true});
    }
    made += 1;
  }
  console.log(`완료: 시드 ${made}개, 건너뜀 ${skipped}개${DRY ? " (dry)" : ""}`);
}

run().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
