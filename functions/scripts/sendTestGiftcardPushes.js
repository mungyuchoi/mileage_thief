/**
 * 상품권 푸시(P1~P4) 테스트 발송.
 * displayName(기본 '마일캐치')으로 유저를 찾아 실제 운영과 동일한
 * payload 로 발송한다. 딥링크/채널/알림함까지 그대로 검증 가능.
 *
 * 실행:
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../env/mileagethief-firebase-adminsdk-8gdf2-49e348f31e.json \
 *     node scripts/sendTestGiftcardPushes.js            # P1~P4 순차(8초 간격)
 *
 * 옵션:
 *   p1 | p2 | p3 | p4      해당 푸시 1건만 발송 (예: node ... p2)
 *   --uid=XXXX             displayName 검색 대신 uid 직접 지정
 *   --name=닉네임           검색할 displayName 변경
 *   --delay=5              순차 발송 간격(초, 기본 8)
 *   --dry                  발송 없이 대상/payload 만 출력
 */
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const ARGS = process.argv.slice(2);
const DRY = ARGS.includes("--dry");
const ONLY = ARGS.find((a) => /^p[1-4]$/i.test(a));
const UID_ARG = (ARGS.find((a) => a.startsWith("--uid=")) || "").slice(6);
const NAME_ARG =
  (ARGS.find((a) => a.startsWith("--name=")) || "").slice(7) || "마일캐치";
const DELAY_SEC = Number(
    (ARGS.find((a) => a.startsWith("--delay=")) || "").slice(8)) || 8;

const FACE_VALUE = 100000;
const MILE_VALUE_KRW = 15;

const CHANNELS = {
  giftcard_price_surge: "giftcard_price_surge_notifications",
  giftcard_high_30d: "giftcard_high_30d_notifications",
  giftcard_sangtech: "giftcard_sangtech_notifications",
  giftcard_weekly_brief: "giftcard_weekly_brief_notifications",
};

const won = (n) => `${Math.round(n).toLocaleString("ko-KR")}원`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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

/** displayName 으로 유저 검색(정확 일치 → 앞뒤 공백 변형 스캔) */
async function findUser() {
  if (UID_ARG) {
    const doc = await db.doc(`users/${UID_ARG}`).get();
    if (!doc.exists) throw new Error(`uid ${UID_ARG} 없음`);
    return doc;
  }
  let snap = await db.collection("users")
      .where("displayName", "==", NAME_ARG).limit(3).get();
  if (snap.empty) {
    // 앞부분 일치(뒤에 공백 등 붙은 변형)
    snap = await db.collection("users")
        .where("displayName", ">=", NAME_ARG)
        .where("displayName", "<=", `${NAME_ARG}`)
        .limit(5).get();
  }
  if (snap.empty) throw new Error(`displayName '${NAME_ARG}' 유저를 못 찾음`);
  if (snap.size > 1) {
    console.log("⚠️  복수 매칭 — 첫 번째 사용:");
    snap.forEach((d) => console.log(
        `   ${d.id} → ${JSON.stringify(d.data().displayName)}`));
  }
  return snap.docs[0];
}

/** 매입가 가장 높은 종목 1개(테스트 payload 용 실데이터) */
async function pickGiftcard() {
  const snap = await db.collection("giftcards").get();
  let best = null;
  snap.forEach((doc) => {
    const d = doc.data() || {};
    const price = Number(d.bestSellPrice) || 0;
    if (price > 0 && (!best || price > best.price)) {
      best = {
        id: doc.id,
        name: String(d.name || doc.id),
        price,
        branch: String(d.bestSellBranchName || ""),
      };
    }
  });
  if (!best) throw new Error("giftcards 에 bestSellPrice 있는 종목이 없음");
  return best;
}

/** 유저 카드 중 최고 적립율(%) — 없으면 null */
async function bestCardRate(uid) {
  const snap = await db.collection(`users/${uid}/cards`).limit(10).get();
  let best = null;
  snap.forEach((doc) => {
    const c = doc.data() || {};
    let rate = null;
    if (c.rewardType === "point" && Number(c.pointRatePercent) > 0) {
      rate = Number(c.pointRatePercent);
    } else if (c.rewardType === "mile") {
      const perMile = Number(c.creditPerMileKRW) ||
        Number(c.checkPerMileKRW) || 0;
      if (perMile > 0) rate = (MILE_VALUE_KRW / perMile) * 100;
    }
    if (rate !== null && (!best || rate > best.rate)) {
      best = {name: String(c.name || "내 카드"), rate};
    }
  });
  return best;
}

/** P4 랜딩용 주간 브리핑 문서가 없으면 현재 시세로 생성 */
async function ensureWeeklyBrief() {
  const weekKey = currentWeekKeyKst();
  const ref = db.doc(`giftcardWeeklyBriefs/${weekKey}`);
  const doc = await ref.get();
  if (doc.exists) return weekKey;

  const snap = await db.collection("giftcards").get();
  const items = [];
  snap.forEach((d) => {
    const g = d.data() || {};
    const price = Number(g.bestSellPrice) || 0;
    if (price <= 0) return;
    items.push({
      giftcardId: d.id,
      name: String(g.name || d.id),
      price,
      prevPrice: null,
      changePct: null, // 히스토리 축적 전 — 랜딩에서 '-' 표시
      sellRatePct: (price / FACE_VALUE) * 100,
      bestSellBranchName: String(g.bestSellBranchName || ""),
    });
  });
  if (!DRY) {
    await ref.set({
      weekKey,
      items,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      testSeeded: true,
    });
    console.log(`   (giftcardWeeklyBriefs/${weekKey} 문서 생성 — 랜딩용)`);
  }
  return weekKey;
}

/** 운영 sendPushToUser 와 동일한 발송(토큰 수집 + android 채널) */
async function sendPush(uid, title, body, data, channelId) {
  const tokenSet = new Set();
  const userSnap = await db.doc(`users/${uid}`).get();
  const ft = (userSnap.data() || {}).fcmToken;
  if (typeof ft === "string" && ft) tokenSet.add(ft);
  const sub = await db.collection(`users/${uid}/fcmTokens`).get();
  sub.forEach((d) => d.id && tokenSet.add(d.id));
  const tokens = [...tokenSet];
  if (tokens.length === 0) throw new Error("FCM 토큰 없음");

  const payload = {};
  Object.keys(data).forEach((k) => (payload[k] = String(data[k])));

  if (DRY) {
    console.log("   [dry] tokens:", tokens.length, "payload:", payload);
    return;
  }
  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {title, body},
    data: payload,
    android: {notification: {channelId}},
  });
  console.log(`   토큰 ${tokens.length}개 → 성공 ${res.successCount} / ` +
    `실패 ${res.failureCount}`);
  res.responses.forEach((r, i) => {
    if (!r.success) console.log(`   실패[${i}]: ${r.error && r.error.code}`);
  });

  await db.collection(`users/${uid}/notifications`).add({
    type: data.type,
    giftcardId: data.giftcardId || "",
    title, body, message: body,
    read: false, isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

(async () => {
  const userDoc = await findUser();
  const uid = userDoc.id;
  const u = userDoc.data() || {};
  console.log(`대상: ${uid} / displayName=${JSON.stringify(u.displayName)} ` +
    `/ hasGift=${u.hasGift ?? "없음"}`);

  const gift = await pickGiftcard();
  console.log(`종목: ${gift.name}(${gift.id}) 매입가 ${won(gift.price)}\n`);

  const spreadPct = 100 - (gift.price / FACE_VALUE) * 100;
  const card = await bestCardRate(uid);
  const cardName = card ? card.name : "샘플 카드";
  const cardRate = card ? card.rate : spreadPct + 0.42; // 카드 없으면 +0.42% 예시
  const netPct = cardRate - spreadPct;
  const weekKey = await ensureWeeklyBrief();

  const pushes = {
    p1: {
      type: "giftcard_price_surge",
      title: `📈 ${gift.name} 매입가 급등`,
      body: `${won(gift.price)} (+0.82%)` +
        (gift.branch ? ` · ${gift.branch}` : ""),
      data: {giftcardId: gift.id, giftcardName: gift.name,
        highlight: "surge"},
    },
    p2: {
      type: "giftcard_high_30d",
      title: `💰 ${gift.name} 30일 최고가`,
      body: `매입가 ${won(gift.price)} — 갖고 있다면 지금이 기회` +
        (gift.branch ? ` · ${gift.branch}` : ""),
      data: {giftcardId: gift.id, giftcardName: gift.name,
        highlight: "high30d"},
    },
    p3: {
      type: "giftcard_sangtech",
      title: "💳 상테크 타이밍",
      body: `${cardName} × ${gift.name} 조합, 지금 실질 수익 ` +
        `+${netPct.toFixed(2)}% (적립 ${cardRate.toFixed(2)}% − ` +
        `스프레드 ${spreadPct.toFixed(2)}%)`,
      data: {giftcardId: gift.id, giftcardName: gift.name,
        highlight: "sangtech"},
    },
    p4: {
      type: "giftcard_weekly_brief",
      title: "🧾 주간 상품권 시세 브리핑",
      body: `이번 주 ${gift.name} +0.34% — 주간 변동 한눈에 보기`,
      data: {giftcardId: gift.id, giftcardName: gift.name, weekKey},
    },
  };

  const keys = ONLY ? [ONLY.toLowerCase()] : ["p1", "p2", "p3", "p4"];
  for (let i = 0; i < keys.length; i++) {
    const p = pushes[keys[i]];
    console.log(`▶ ${keys[i].toUpperCase()} (${p.type})`);
    console.log(`   ${p.title} / ${p.body}`);
    await sendPush(uid, p.title, p.body, {
      ...p.data,
      type: p.type,
      channelId: CHANNELS[p.type],
      notificationTitle: p.title,
      notificationBody: p.body,
    }, CHANNELS[p.type]);
    if (i < keys.length - 1) {
      console.log(`   (${DELAY_SEC}초 대기…)\n`);
      await sleep(DELAY_SEC * 1000);
    }
  }
  console.log("\n완료");
  process.exit(0);
})().catch((e) => {
  console.error("오류:", e.message);
  process.exit(1);
});
