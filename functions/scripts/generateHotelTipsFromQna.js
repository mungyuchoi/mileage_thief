/**
 * susasa_qna(카페 Q&A) -> 호텔 추가 후보 + 꿀팁 후보 생성/승인 반영.
 *
 * Dry-run:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-*.json \
 *     node scripts/generateHotelTipsFromQna.js --dry
 *
 * Apply approved:
 *   node scripts/generateHotelTipsFromQna.js --apply-approved ../docs/exam/hotel_tip_candidates_dryrun.json
 *
 * 원문은 복사하지 않는다. source.title/url은 검수 추적용이고,
 * content는 주제/호텔명 기반으로 재작성한 팁 문장만 저장한다.
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const AUTHOR_UID = "aP3C0N511beyK7QZG9GyChs5oqO2";
const AUTHOR_NICKNAME = "마일캐치";
const QNA_DIR = path.join(__dirname, "..", "..", "docs", "exam");
const OUT_PATH = readArg("--out") ||
  path.join(QNA_DIR, "hotel_tip_candidates_dryrun.json");
const APPLY_PATH = readArg("--apply-approved");
const MAX_TIPS_PER_EXISTING_HOTEL = readNumberArg("--max-existing-tips", 12);
const MAX_TIPS_PER_NEW_HOTEL = readNumberArg("--max-new-tips", 6);
const MIN_NEW_HOTEL_MENTIONS = readNumberArg("--min-new-mentions", 3);

const BRAND_RULES = [
  ["marriott", /메리어트|본보이|marriott|bonvoy|jw|웨스틴|westin|쉐라톤|sheraton|리츠|ritz|르\s*메르디앙|le\s*meridien/i],
  ["hilton", /힐튼|hilton|콘래드|conrad|waldorf|월도프/i],
  ["hyatt", /하얏트|hyatt|안다즈|andaz/i],
  ["accor", /아코르|accor|소피텔|sofitel|페어몬트|fairmont|노보텔|novotel|래플스|raffles/i],
  ["ihg", /ihg|인터컨|인터컨티넨탈|intercontinental|홀리데이\s*인|holiday\s*inn|킴튼|kimpton/i],
];

const COUNTRY_HINTS = [
  ["kr", /한국|국내|서울|제주|부산|인천|동대문|명동|강남|여의도/],
  ["jp", /일본|도쿄|오사카|교토|후쿠오카|삿포로|오키나와/],
  ["us", /미국|하와이|와이키키|호놀룰루|뉴욕|샌프란|LA|로스앤젤레스/i],
  ["vn", /베트남|다낭|나트랑|하노이|호치민|푸꾸옥|깜란/],
  ["th", /태국|방콕|푸켓|카오락|치앙마이|파타야/],
  ["sg", /싱가포르|마리나베이|센토사/],
  ["hk", /홍콩/],
  ["mo", /마카오/],
  ["id", /발리|우붓|인도네시아/],
  ["gb", /런던|영국/],
  ["fr", /파리|프랑스/],
];

const CITY_HINTS = [
  "서울", "제주", "부산", "인천", "명동", "동대문", "여의도",
  "하와이", "와이키키", "호놀룰루", "도쿄", "오사카", "교토",
  "다낭", "나트랑", "하노이", "방콕", "푸켓", "카오락", "싱가포르",
  "홍콩", "마카오", "발리", "우붓", "런던", "파리",
];

const HOTEL_PATTERNS = [
  /JW\s*메리어트\s*[가-힣A-Za-z0-9 ]{0,18}/gi,
  /JW\s*Marriott\s*[A-Za-z ]{0,32}/gi,
  /메리어트\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /힐튼\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /하와이안\s*빌리지/g,
  /콘래드\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /쉐라톤\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /웨스틴\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /파크\s*하얏트\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /그랜드\s*하얏트\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /하얏트\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /소피텔\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /페어몬트\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /인터컨티넨탈\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /안다즈\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /리츠\s*칼튼\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /르\s*메르디앙\s*[가-힣A-Za-z0-9 ]{0,18}/g,
  /파르나스\s*제주|제주\s*파르나스/g,
  /신라\s*호텔|서울\s*신라|제주\s*신라/g,
];

const TAG_RULES = [
  ["upgrade", /업글|업그레이드|스위트|suite|티어|다이아|플랫|티타늄|엘리트/i],
  ["view", /오션뷰|시티뷰|리버뷰|전망|뷰|타워|레인보우|파샬/i],
  ["value", /포인트|포숙|무료숙박|바우처|숙박권|가격|요금|가성비|BRG|세전|세후|크레딧|조식권/i],
  ["parents", /부모님|가족|아이|아기|키즈|수영장|동반|효도/i],
  ["honeymoon", /신혼|허니문|기념일|프로포즈/i],
  ["general", /체크인|체크아웃|라운지|조식|주차|예약|취소|환불|위치|동선|후기/i],
];

function readArg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? String(process.argv[i + 1] || "") : "";
}

function readNumberArg(name, fallback) {
  const raw = readArg(name);
  if (!raw) return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

function cleanText(s) {
  return String(s || "").replace(/\u200b/g, " ").replace(/\s+/g, " ").trim();
}

function norm(s) {
  return cleanText(s).toLowerCase()
      .replace(/[()[\]{}'"`.,/\\|:;!?·ㆍ&+_\-]/g, "")
      .replace(/\s+/g, "");
}

function hashId(prefix, value) {
  return `${prefix}_${crypto.createHash("sha1").update(value).digest("hex").slice(0, 16)}`;
}

function articleText(article) {
  const body = (article.body && article.body.plainText) || "";
  const comments = Array.isArray(article.comments) ?
    article.comments.map((c) => c.plainText || "").join(" ") : "";
  return cleanText(`${article.title || ""} ${article.summary || ""} ${body} ${comments}`);
}

function loadArticles() {
  const files = fs.readdirSync(QNA_DIR)
      .filter((f) => /^susasa_qna_.*\.json$/.test(f))
      .sort();
  const seen = new Set();
  const articles = [];
  for (const file of files) {
    const parsed = JSON.parse(fs.readFileSync(path.join(QNA_DIR, file), "utf8"));
    for (const article of parsed.articles || []) {
      const articleId = String(article.articleId || "");
      if (!articleId || seen.has(articleId)) continue;
      seen.add(articleId);
      articles.push({...article, sourceFile: file});
    }
  }
  return articles;
}

function detectBrand(text) {
  for (const [brand, re] of BRAND_RULES) {
    if (re.test(text)) return brand;
  }
  return "other";
}

function detectCountry(text) {
  for (const [countryCode, re] of COUNTRY_HINTS) {
    if (re.test(text)) return countryCode;
  }
  return "";
}

function detectCity(text) {
  return CITY_HINTS.find((city) => text.includes(city)) || "";
}

function detectTag(text) {
  for (const [tag, re] of TAG_RULES) {
    if (re.test(text)) return tag;
  }
  return "general";
}

function cleanHotelName(raw, fullText) {
  let name = cleanText(raw)
      .replace(/\s+(vs|VS)\s+.*/g, "")
      .replace(/(추천|예약|질문|후기|가격|조식|포숙|BRG|성공|문의|크레딧|가능|어디|가보신|갈만|고민).*$/i, "")
      .replace(/[~?!,.]+$/g, "")
      .trim();
  if (/본보이|플랫|플래|골드|다이아|무료숙박권|포인트|친구|신용카드|카드|공홈|등급|티어/i.test(name)) {
    return "";
  }
  if (/계열|계열\s*호텔|메리어트는|콘래드는|힐튼계열|메리어트\s*4/i.test(name)) {
    return "";
  }
  if (/^하와이안\s*빌리지$/.test(name) && /힐튼/.test(fullText)) {
    name = "힐튼 하와이안 빌리지";
  }
  if (/^페어몬트$/.test(name) && /서울/.test(fullText)) name = "페어몬트 서울";
  if (/^그랜드\s*하얏트$/.test(name) && /서울/.test(fullText)) name = "그랜드 하얏트 서울";
  if (/^그랜드\s*하얏트$/.test(name) && /제주/.test(fullText)) name = "그랜드 하얏트 제주";
  if (/^파크\s*하얏트$/.test(name) && /부산/.test(fullText)) name = "파크 하얏트 부산";
  if (/^파크\s*하얏트$/.test(name) && /니세코/.test(fullText)) name = "파크 하얏트 니세코";
  if (/^르\s*메르디앙$/.test(name) && /명동|서울/.test(fullText)) name = "르메르디앙 서울 명동";
  if (/^인터컨티넨탈$/.test(name) && /파르나스/.test(fullText)) {
    name = "인터컨티넨탈 그랜드 서울 파르나스";
  }
  if (/^인터컨티넨탈$/.test(name) && /다낭/.test(fullText)) {
    name = "인터컨티넨탈 다낭";
  }
  if (/제주\s*파르나스/.test(name)) name = "파르나스 제주";
  if (/^파르나스제주$/.test(name)) name = "파르나스 제주";
  if (/^제주\s*신라$/.test(name)) name = "제주 신라호텔";
  if (/^서울신라$/.test(name)) name = "서울 신라호텔";
  if (/^신라\s*호텔$/.test(name) && /제주/.test(fullText)) name = "제주 신라호텔";
  if (/^신라\s*호텔$/.test(name) && /서울/.test(fullText)) name = "서울 신라호텔";
  if (/^신라\s*호텔$/.test(name)) return "";
  if (/^르메르디앙명동$/.test(name)) name = "르메르디앙 서울 명동";
  if (/^콘래드서울$/.test(name)) name = "콘래드 서울";
  if (/JW\s*메리어트\s*제주/i.test(name)) {
    name = "JW 메리어트 제주 리조트 &스파";
  }
  if (/힐튼\s*하와이안\s*빌리지|힐튼하와이안빌리지/.test(name)) {
    name = "힐튼 하와이안 빌리지";
  }
  return name;
}

function extractHotelNames(text) {
  const out = new Set();
  for (const pattern of HOTEL_PATTERNS) {
    for (const m of text.matchAll(pattern)) {
      const name = cleanHotelName(m[0], text);
      if (!isLikelyHotelName(name, text)) continue;
      if (norm(name).length >= 4 && norm(name).length <= 36) out.add(name);
    }
  }
  return [...out];
}

function isLikelyHotelName(name, fullText) {
  if (!name) return false;
  const n = norm(name);
  if (/본보이|플랫|플래|골드|다이아|무료숙박권|포인트|친구|신용카드|공홈|등급|티어/i.test(name)) {
    return false;
  }
  if (/계열|메리어트는|콘래드는|힐튼계열|메리어트\s*4/i.test(name)) {
    return false;
  }
  if (/^(메리어트|힐튼|하얏트|페어몬트|리츠칼튼|인터컨티넨탈|르메르디앙|쉐라톤|웨스틴|하얏트리젠시)$/i.test(name)) {
    return false;
  }
  if (/메리어트호텔|힐튼호텔/.test(n) && !CITY_HINTS.some((city) => fullText.includes(city))) {
    return false;
  }
  return true;
}

function hotelAliases(hotel) {
  const name = cleanText(hotel.name);
  const values = new Set([name]);
  values.add(name.replace(/호텔|리조트|스파|더|앤드/g, " "));
  values.add(name.replace(/\b(hotel|resort|spa|and|the)\b/gi, " "));
  if (/JW\s*메리어트\s*제주/i.test(name)) values.add("JW 메리어트 제주");
  if (/힐튼\s*하와이안\s*빌리지/.test(name)) {
    values.add("하와이안 빌리지");
    values.add("힐튼빌리지");
  }
  return [...values].map(cleanText).filter((v) => norm(v).length >= 4);
}

function matchExistingHotel(name, existingHotels) {
  const n = norm(name);
  return existingHotels.find((hotel) =>
    hotel.aliases.some((alias) => n.includes(norm(alias)) || norm(alias).includes(n)));
}

function tipContent(hotelName, tag) {
  const topic = `${hotelName}${hasFinalConsonant(hotelName) ? "은" : "는"}`;
  const map = {
    upgrade: `${topic} 객실 업그레이드나 티어 혜택 기대치가 자주 언급됩니다. 예약 채널, 객실 타입, 투숙일 혼잡도에 따라 체감 차이가 날 수 있어 체크인 전 조건 확인이 좋습니다.`,
    view: `${topic} 뷰와 타워, 객실 위치에 따른 만족도 차이를 확인해볼 만합니다. 오션뷰·시티뷰처럼 이름이 비슷한 객실도 실제 전망이 다를 수 있습니다.`,
    value: `${topic} 포인트 숙박, 현금가, 바우처, 조식 포함 여부를 함께 비교하는 것이 좋습니다. 같은 일정이라도 예약 조건에 따라 체감 가치가 달라질 수 있습니다.`,
    parents: `${topic} 가족 동반이라면 수영장, 키즈 프로그램, 조식 동선, 침대 구성 같은 실사용 조건을 먼저 확인하는 편이 좋습니다.`,
    honeymoon: `${topic} 기념일이나 신혼 여행 목적이라면 객실 전망, 레이트 체크아웃, 웰컴 어메니티 가능 여부를 사전에 문의해볼 만합니다.`,
    general: `${topic} 체크인/체크아웃, 조식, 라운지, 주차, 예약 변경 조건처럼 현장에서 체감되는 운영 정보를 미리 확인해두는 것이 좋습니다.`,
  };
  return map[tag] || map.general;
}

function hasFinalConsonant(value) {
  const last = cleanText(value).slice(-1);
  const code = last.charCodeAt(0);
  if (code < 0xac00 || code > 0xd7a3) return true;
  return (code - 0xac00) % 28 !== 0;
}

async function loadExistingHotels() {
  const snap = await db.collection("hotels").get();
  return snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      id: doc.id,
      name: cleanText(d.name),
      brand: String(d.brand || "other"),
      countryCode: String(d.countryCode || ""),
      city: String(d.city || ""),
      aliases: hotelAliases(d),
    };
  }).filter((h) => h.name);
}

function sourceOf(article) {
  return {
    articleId: String(article.articleId || ""),
    sourceFile: String(article.sourceFile || ""),
    url: String(article.url || ""),
    title: cleanText(article.title || article.summary || "").slice(0, 120),
    writtenAt: String(article.writtenAt || ""),
  };
}

function makeTip(hotelId, hotelName, article, tag, mode) {
  return {
    approved: false,
    mode,
    tipId: hashId("qna_tip", `${hotelId}:${article.articleId}:${tag}`),
    hotelId,
    hotelName,
    tag,
    content: tipContent(hotelName, tag),
    linkUrl: String(article.url || ""),
    imageUrls: [],
    authorUid: AUTHOR_UID,
    authorNickname: AUTHOR_NICKNAME,
    source: sourceOf(article),
  };
}

function addLimitedTip(bucket, key, tip, max) {
  const list = bucket.get(key) || [];
  if (list.length >= max) return;
  if (list.some((x) => x.content === tip.content && x.tag === tip.tag)) return;
  list.push(tip);
  bucket.set(key, list);
}

async function dryRun() {
  const existingHotels = await loadExistingHotels();
  const articles = loadArticles();
  const existingTips = new Map();
  const newHotelMap = new Map();

  for (const article of articles) {
    const text = articleText(article);
    if (!/호텔|숙박|조식|체크인|메리어트|힐튼|하얏트|아코르|ihg|콘래드|소피텔|웨스틴|쉐라톤|파르나스/i.test(text)) {
      continue;
    }
    const names = extractHotelNames(text);
    if (names.length === 0) continue;
    const tag = detectTag(text);
    for (const name of names) {
      const existing = matchExistingHotel(name, existingHotels);
      if (existing) {
        const tip = makeTip(existing.id, existing.name, article, tag, "existingHotelTip");
        addLimitedTip(existingTips, existing.id, tip, MAX_TIPS_PER_EXISTING_HOTEL);
        continue;
      }
      const key = norm(name);
      const prev = newHotelMap.get(key) || {
        approved: false,
        candidateHotelId: hashId("qna_hotel", key),
        name,
        brand: detectBrand(text),
        countryCode: detectCountry(text),
        city: detectCity(text),
        lat: null,
        lng: null,
        needsLocation: true,
        mentionCount: 0,
        sourceTitles: [],
        tips: [],
      };
      prev.mentionCount += 1;
      if (prev.sourceTitles.length < 5) prev.sourceTitles.push(sourceOf(article));
      addLimitedTip({
        get: () => prev.tips,
        set: (_k, list) => {
          prev.tips = list;
        },
      }, key, makeTip(prev.candidateHotelId, name, article, tag, "newHotelTip"), MAX_TIPS_PER_NEW_HOTEL);
      newHotelMap.set(key, prev);
    }
  }

  const newHotelCandidates = [...newHotelMap.values()]
      .filter((h) => h.mentionCount >= MIN_NEW_HOTEL_MENTIONS)
      .sort((a, b) => b.mentionCount - a.mentionCount || a.name.localeCompare(b.name));
  const existingHotelTips = [...existingTips.values()].flat();
  const payload = {
    generatedAt: new Date().toISOString(),
    mode: "dry-run",
    authorUid: AUTHOR_UID,
    authorNickname: AUTHOR_NICKNAME,
    notes: [
      "JSON 저장만으로는 서버에 반영되지 않습니다.",
      "approved=true 항목만 --apply-approved 실행 시 Firestore에 반영됩니다.",
      "신규 호텔은 lat/lng/countryCode가 채워져야 지도에 표시됩니다.",
      "content는 원문 복사가 아니라 규칙 기반으로 재작성한 팁 문장입니다.",
    ],
    summary: {
      articlesCount: articles.length,
      existingHotelsCount: existingHotels.length,
      existingHotelTipCandidates: existingHotelTips.length,
      newHotelCandidates: newHotelCandidates.length,
    },
    existingHotelTips,
    newHotelCandidates,
  };
  fs.writeFileSync(OUT_PATH, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`articles=${articles.length}`);
  console.log(`existingHotels=${existingHotels.length}`);
  console.log(`existingHotelTipCandidates=${existingHotelTips.length}`);
  console.log(`newHotelCandidates=${newHotelCandidates.length}`);
  console.log(`out=${OUT_PATH}`);
}

function tipWritePayload(tip) {
  return {
    tag: tip.tag || "general",
    content: cleanText(tip.content).slice(0, 500),
    linkUrl: String(tip.linkUrl || ""),
    imageUrls: Array.isArray(tip.imageUrls) ? tip.imageUrls.map(String) : [],
    authorUid: AUTHOR_UID,
    authorNickname: AUTHOR_NICKNAME,
    likeCount: 0,
    source: tip.source || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function applyApproved(filePath) {
  const fullPath = path.resolve(process.cwd(), filePath);
  const parsed = JSON.parse(fs.readFileSync(fullPath, "utf8"));
  const now = admin.firestore.FieldValue.serverTimestamp();
  const authorSnap = await db.doc(`users/${AUTHOR_UID}`).get();
  const authorPhoto = String((authorSnap.data() || {}).photoURL || "");
  let hotelsWritten = 0;
  let tipsWritten = 0;

  for (const hotel of parsed.newHotelCandidates || []) {
    if (hotel.approved !== true) continue;
    const lat = Number(hotel.lat);
    const lng = Number(hotel.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new Error(`신규 호텔 ${hotel.name} lat/lng가 필요합니다.`);
    }
    if (!/^[a-z]{2}$/.test(String(hotel.countryCode || ""))) {
      throw new Error(`신규 호텔 ${hotel.name} countryCode가 필요합니다.`);
    }
    const ref = db.collection("hotels").doc(hotel.candidateHotelId);
    await ref.set({
      name: cleanText(hotel.name),
      brand: hotel.brand || "other",
      lat,
      lng,
      countryCode: String(hotel.countryCode).toLowerCase(),
      city: cleanText(hotel.city || ""),
      stars: Math.max(0, Math.min(5, Math.round(Number(hotel.stars) || 0))),
      description: cleanText(hotel.description || ""),
      coverImageUrl: String(hotel.coverImageUrl || ""),
      pointHotelId: null,
      topContributorUid: AUTHOR_UID,
      topContributorName: AUTHOR_NICKNAME,
      topContributorPhoto: authorPhoto,
      topContributorScore: 3,
      lastContribAt: now,
      totalQuizCount: 0,
      totalTipCount: 0,
      createdBy: AUTHOR_UID,
      createdAt: now,
    }, {merge: true});
    await ref.collection("contributors").doc(AUTHOR_UID).set({
      uid: AUTHOR_UID,
      displayName: AUTHOR_NICKNAME,
      photoURL: authorPhoto,
      score: admin.firestore.FieldValue.increment(3),
      breakdown: {added: admin.firestore.FieldValue.increment(1)},
      updatedAt: now,
    }, {merge: true});
    hotelsWritten += 1;
  }

  const allTips = [
    ...(parsed.existingHotelTips || []),
    ...(parsed.newHotelCandidates || []).flatMap((h) => h.tips || []),
  ].filter((tip) => tip.approved === true);

  for (const tip of allTips) {
    const hotelRef = db.collection("hotels").doc(tip.hotelId);
    const tipRef = hotelRef.collection("tips").doc(tip.tipId);
    const batch = db.batch();
    batch.set(tipRef, tipWritePayload(tip), {merge: true});
    batch.set(hotelRef, {
      totalTipCount: admin.firestore.FieldValue.increment(1),
      lastContribAt: now,
    }, {merge: true});
    batch.set(hotelRef.collection("contributors").doc(AUTHOR_UID), {
      uid: AUTHOR_UID,
      displayName: AUTHOR_NICKNAME,
      photoURL: authorPhoto,
      score: admin.firestore.FieldValue.increment(1),
      breakdown: {tipCreated: admin.firestore.FieldValue.increment(1)},
      updatedAt: now,
    }, {merge: true});
    await batch.commit();
    tipsWritten += 1;
  }
  console.log(`hotelsWritten=${hotelsWritten}`);
  console.log(`tipsWritten=${tipsWritten}`);
}

if (APPLY_PATH) {
  applyApproved(APPLY_PATH).then(() => process.exit(0)).catch((e) => {
    console.error(e);
    process.exit(1);
  });
} else {
  dryRun().then(() => process.exit(0)).catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
