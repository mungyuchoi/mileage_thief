/**
 * susasa_qna(카페 Q&A) → 호텔 캐치 팁 시드 스크립트.
 *
 * 선행: seedHotelsFromPosuk.js 로 hotels 가 채워져 있어야 한다(이름 매칭).
 *
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-*.json \
 *     node scripts/seedFromQna.js [--dry]
 *
 * - 글/댓글 텍스트에 호텔명이 등장하면 그 호텔에 '카페 발췌' 팁 시드.
 * - 태그 자동 매핑: 조식→value, 업글→upgrade, 뷰→view, 체크인→general 등.
 * - 멱등: hotels/{id}/tips/qna_{articleId}.
 * - 호텔당 최대 MAX_PER_HOTEL 개.
 */
const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const DRY = process.argv.includes("--dry");
const MAX_PER_HOTEL = 10;
const QNA_DIR = path.join(__dirname, "..", "..", "docs", "exam");

function mapTag(t) {
  if (/신혼|허니문/.test(t)) return "honeymoon";
  if (/부모님|효도/.test(t)) return "parents";
  if (/오션뷰|시티뷰|전망|리버뷰|뷰가|뷰 /.test(t)) return "view";
  if (/업글|업그레이드/.test(t)) return "upgrade";
  if (/조식|가성비|포인트|얼마|가격/.test(t)) return "value";
  return "general"; // 체크인 등 일반
}

function articleText(a) {
  const body = (a.body && a.body.plainText) || "";
  return `${a.title || ""} ${a.summary || ""} ${body}`;
}

function loadArticles() {
  const files = fs.readdirSync(QNA_DIR)
      .filter((f) => /^susasa_qna_.*\.json$/.test(f));
  const seen = new Set();
  const out = [];
  for (const f of files) {
    const j = JSON.parse(fs.readFileSync(path.join(QNA_DIR, f), "utf8"));
    for (const a of (j.articles || [])) {
      if (seen.has(a.articleId)) continue;
      seen.add(a.articleId);
      out.push(a);
    }
  }
  return out;
}

async function run() {
  const hotelsSnap = await db.collection("hotels").get();
  // 이름 3자 이상만(모호 매칭 방지). 공백제거본도 같이 보관해 매칭률↑.
  const hotels = hotelsSnap.docs
      .map((d) => {
        const name = String((d.data() || {}).name || "");
        return {id: d.id, name, nameNS: name.replace(/\s/g, "")};
      })
      .filter((h) => h.nameNS.length >= 3);
  if (hotels.length === 0) {
    console.log("hotels 가 비어 있습니다(이름 3자+ 0개). " +
      "먼저 seedHotelsFromPosuk 로 호텔을 채우세요.");
    process.exit(0);
  }

  const articles = loadArticles();
  console.log(`hotels ${hotels.length} · articles ${articles.length}`);
  console.log("매칭 대상 호텔명(샘플): " +
    hotels.slice(0, 10).map((h) => h.name).join(" / "));

  const perHotel = {};
  let made = 0;
  for (const a of articles) {
    const text = articleText(a);
    if (!/호텔|숙박|조식|체크인|메리어트|힐튼|하얏트|아코르|ihg|콘래드|소피텔/i
        .test(text)) {
      continue;
    }
    const textNS = text.replace(/\s/g, "");
    for (const h of hotels) {
      if ((perHotel[h.id] || 0) >= MAX_PER_HOTEL) continue;
      // 원문/공백제거본 양쪽으로 매칭(표기 흔들림 흡수)
      if (!text.includes(h.name) && !textNS.includes(h.nameNS)) continue;
      perHotel[h.id] = (perHotel[h.id] || 0) + 1;
      const content = String(a.title || a.summary || "").slice(0, 140);
      const tip = {
        tag: mapTag(text),
        content,
        linkUrl: String(a.url || ""),
        imageUrls: [],
        authorUid: "system",
        authorNickname: "카페 발췌",
        likeCount: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      const ref = db.doc(`hotels/${h.id}/tips/qna_${a.articleId}`);
      if (DRY) {
        console.log("[dry]", h.name, "←", tip.tag, content.slice(0, 30));
      } else {
        // eslint-disable-next-line no-await-in-loop
        await ref.set(tip, {merge: true});
      }
      made += 1;
    }
  }
  const matchedHotels = Object.keys(perHotel).length;
  console.log(`매칭된 호텔 ${matchedHotels}개`);
  console.log(`완료: 팁 시드 ${made}개${DRY ? " (dry)" : ""}`);
}

run().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});
