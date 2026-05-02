/* global globalThis */

/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onRequest, onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

// Firebase Admin SDK 초기화
admin.initializeApp();

const APP_SCHEME = "milecatchoauth";
const OAUTH_REGION = "asia-northeast3";
const NAVER_CLIENT_ID = defineSecret("NAVER_CLIENT_ID");
const NAVER_CLIENT_SECRET = defineSecret("NAVER_CLIENT_SECRET");
const KAKAO_REST_API_KEY = defineSecret("KAKAO_REST_API_KEY");
const KAKAO_CLIENT_SECRET = defineSecret("KAKAO_CLIENT_SECRET");

/**
 * unknown 값을 안전한 문자열 ID로 변환
 * @param {unknown} value
 * @return {string}
 */
function asIdString(value) {
  if (typeof value === "string") {
    return value.trim();
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }

  if (typeof value === "bigint") {
    return value.toString();
  }

  return "";
}

/**
 * optional 문자열 값을 null-safe 처리
 * @param {unknown} value
 * @return {string|null}
 */
function asOptionalString(value) {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * 네이버 프로필 payload를 앱에서 쓰기 쉬운 형태로 정규화
 * @param {Object} payload
 * @return {Object}
 */
function normalizeNaverProfile(payload) {
  return {
    id: asIdString(payload.id),
    email: asOptionalString(payload.email),
    nickname: asOptionalString(payload.nickname),
    name: asOptionalString(payload.name),
    profileImage: asOptionalString(payload.profile_image),
  };
}

/**
 * 카카오 프로필 payload를 앱에서 쓰기 쉬운 형태로 정규화
 * @param {Object} payload
 * @return {Object}
 */
function normalizeKakaoProfile(payload) {
  const kakaoAccount =
    payload && typeof payload.kakao_account === "object" &&
    payload.kakao_account !== null ?
      payload.kakao_account :
      {};
  const profile =
    kakaoAccount && typeof kakaoAccount.profile === "object" &&
    kakaoAccount.profile !== null ?
      kakaoAccount.profile :
      {};

  return {
    id: asIdString(payload.id),
    email: asOptionalString(kakaoAccount.email),
    nickname: asOptionalString(profile.nickname),
    name: asOptionalString(profile.nickname),
    profileImage: asOptionalString(profile.profile_image_url),
  };
}

/**
 * OAuth bridge query를 앱 callback URI로 변환
 * @param {Record<string, unknown>} query
 * @return {string}
 */
function buildNaverAppCallback(query) {
  const callbackUrl = new URL(`${APP_SCHEME}://oauth/naver`);

  const code = asOptionalString(query.code);
  const state = asOptionalString(query.state);
  const error = asOptionalString(query.error);
  const errorDescription = asOptionalString(query.error_description);

  if (code) {
    callbackUrl.searchParams.set("code", code);
  }

  if (state) {
    callbackUrl.searchParams.set("state", state);
  }

  if (error) {
    callbackUrl.searchParams.set("error", error);
  }

  if (errorDescription) {
    callbackUrl.searchParams.set("error_description", errorDescription);
  }

  return callbackUrl.toString();
}

/**
 * OAuth bridge query를 앱 callback URI로 변환
 * @param {string} provider
 * @param {Record<string, unknown>} query
 * @return {string}
 */
function buildOauthAppCallback(provider, query) {
  const callbackUrl = new URL(`${APP_SCHEME}://oauth/${provider}`);

  const code = asOptionalString(query.code);
  const state = asOptionalString(query.state);
  const error = asOptionalString(query.error);
  const errorDescription = asOptionalString(query.error_description);

  if (code) {
    callbackUrl.searchParams.set("code", code);
  }

  if (state) {
    callbackUrl.searchParams.set("state", state);
  }

  if (error) {
    callbackUrl.searchParams.set("error", error);
  }

  if (errorDescription) {
    callbackUrl.searchParams.set("error_description", errorDescription);
  }

  return callbackUrl.toString();
}

/**
 * boardId로 boardName을 가져오는 함수
 * @param {string} boardId - 게시판 ID
 * @return {Promise<string>} 게시판 이름
 */
async function getBoardName(boardId) {
  try {
    const snapshot = await admin.database()
        .ref(`categories/boards/${boardId}`)
        .once("value");

    if (snapshot.exists()) {
      return snapshot.val().name || "자유게시판";
    }
  } catch (error) {
    logger.error(`카테고리 정보 조회 실패: ${error.message}`);
  }

  // 기본값 반환
  const defaultBoardNames = {
    "free": "자유게시판",
    "question": "마일리지",
    "deal": "적립/카드 혜택",
    "seat_share": "좌석 공유",
    "review": "항공 리뷰",
    "error_report": "오류 신고",
    "suggestion": "건의사항",
    "notice": "운영 공지사항",
  };

  return defaultBoardNames[boardId] || "자유게시판";
}

const RADAR_REGION = "asia-northeast3";
const RADAR_CHANNEL_ID = "radar_notifications";
const RADAR_MATCH_COLLECTION = "radar_notifications";
const RADAR_SUBSCRIPTION_COLLECTION = "radar_subscriptions";
const RADAR_SUPPORTED_TYPES = new Set([
  "mileageSeat",
  "cancelAlert",
  "flightDeal",
  "giftcard",
  "benefitNews",
]);
const CARD_REGION = "asia-northeast3";
const CARD_CATALOG_DOC_ID = "catalog";
const CARD_PRODUCT_FIELDS = new Set([
  "name",
  "issuerName",
  "issuerId",
  "cardType",
  "status",
  "rewardProgram",
  "annualFee",
  "previousMonthSpend",
  "brands",
  "primaryBenefits",
  "calculatorRules",
  "exclusions",
  "detailSummary",
  "sourceRefs",
  "images",
  "quality",
]);
const CARD_TYPES = new Set(["credit", "check", "hybrid", "unknown"]);
const CARD_STATUSES = new Set([
  "active",
  "discontinued",
  "hidden",
  "pending",
]);
const CARD_GORILLA_API_BASE = "https://api.card-gorilla.com:8080/v1";
const CARD_IMAGE_BUCKET = "mileagethief.firebasestorage.app";
const CARD_GORILLA_MAX_IMPORT_ID = 100000;
const CARD_SOURCE_SEARCH_CACHE_MS = 10 * 60 * 1000;
let cardSourceSearchCache = {
  fetchedAtMs: 0,
  items: null,
};

/**
 * 숫자형 값을 안전하게 number로 변환
 * @param {unknown} value
 * @return {number|null}
 */
function asOptionalNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value.replace(/,/g, ""));
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

/**
 * Firestore Timestamp/Date/string을 Date로 변환
 * @param {unknown} value
 * @return {Date|null}
 */
function asOptionalDate(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

/**
 * 카드 카탈로그 루트 문서 ref
 * @return {FirebaseFirestore.DocumentReference}
 */
function cardCatalogRef() {
  return admin.firestore().collection("cards").doc(CARD_CATALOG_DOC_ID);
}

/**
 * 로그인 uid를 가져오거나 실패 처리
 * @param {Object} request
 * @return {string}
 */
function requireAuthUid(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return uid;
}

/**
 * roles 필드에서 관리자 권한 여부 확인
 * @param {unknown} roles
 * @return {boolean}
 */
function hasAdminRole(roles) {
  if (Array.isArray(roles)) {
    return roles.some((role) => {
      const value = String(role).trim();
      return value === "admin" || value === "owner";
    });
  }
  if (roles && typeof roles === "object") {
    return roles.admin === true || roles.owner === true;
  }
  if (typeof roles === "string") {
    const value = roles.trim();
    return value === "admin" || value === "owner";
  }
  return false;
}

/**
 * 관리자 권한 확인
 * @param {string} uid
 * @return {Promise<void>}
 */
async function requireCardAdmin(uid) {
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!hasAdminRole(userDoc.data() && userDoc.data().roles)) {
    throw new HttpsError("permission-denied", "관리자 권한이 필요합니다.");
  }
}

/**
 * plain object 여부 확인
 * @param {unknown} value
 * @return {boolean}
 */
function isPlainObject(value) {
  return Boolean(
      value &&
      typeof value === "object" &&
      !Array.isArray(value) &&
      !(value instanceof Date) &&
      typeof value.toDate !== "function",
  );
}

/**
 * Firestore에 저장 가능한 JSON 값을 보수적으로 정리
 * @param {unknown} value
 * @param {number} depth
 * @return {unknown}
 */
function sanitizeCardJsonValue(value, depth = 0) {
  if (depth > 6) {
    throw new HttpsError("invalid-argument", "카드 정보가 너무 깊습니다.");
  }
  if (value === null) {
    return null;
  }
  if (typeof value === "string") {
    return value.trim().slice(0, 20000);
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new HttpsError("invalid-argument", "숫자 값이 올바르지 않습니다.");
    }
    return value;
  }
  if (typeof value === "boolean") {
    return value;
  }
  if (Array.isArray(value)) {
    if (value.length > 200) {
      throw new HttpsError("invalid-argument", "목록 항목이 너무 많습니다.");
    }
    return value.map((item) => sanitizeCardJsonValue(item, depth + 1));
  }
  if (isPlainObject(value)) {
    const output = {};
    const entries = Object.entries(value);
    if (entries.length > 120) {
      throw new HttpsError("invalid-argument", "카드 정보 항목이 너무 많습니다.");
    }
    for (const [key, nestedValue] of entries) {
      const normalizedKey = String(key).trim();
      if (
        !normalizedKey ||
        normalizedKey === "__proto__" ||
        normalizedKey === "constructor" ||
        normalizedKey === "prototype"
      ) {
        continue;
      }
      output[normalizedKey] = sanitizeCardJsonValue(nestedValue, depth + 1);
    }
    return output;
  }

  throw new HttpsError("invalid-argument", "지원하지 않는 카드 정보 값입니다.");
}

/**
 * 카드명/카드사명 필수 문자열 검증
 * @param {unknown} value
 * @param {string} fieldName
 * @return {string}
 */
function requireCardText(value, fieldName) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text) {
    throw new HttpsError("invalid-argument", `${fieldName}은 필수입니다.`);
  }
  return text.slice(0, 200);
}

/**
 * 카드 추가/수정 patch 정규화
 * @param {Record<string, unknown>} input
 * @param {boolean} isCreate
 * @return {Record<string, unknown>}
 */
function normalizeCardPatch(input, isCreate = false) {
  if (!isPlainObject(input)) {
    throw new HttpsError("invalid-argument", "카드 정보가 올바르지 않습니다.");
  }

  const output = {};
  for (const [field, value] of Object.entries(input)) {
    if (!CARD_PRODUCT_FIELDS.has(field)) {
      continue;
    }
    output[field] = sanitizeCardJsonValue(value);
  }

  if (isCreate || Object.prototype.hasOwnProperty.call(output, "name")) {
    output.name = requireCardText(output.name, "카드명");
  }
  if (isCreate || Object.prototype.hasOwnProperty.call(output, "issuerName")) {
    output.issuerName = requireCardText(output.issuerName, "카드사명");
  }

  const rawCardType =
    Object.prototype.hasOwnProperty.call(output, "cardType") ?
      String(output.cardType || "").trim() :
      "";
  if (isCreate || rawCardType) {
    output.cardType = CARD_TYPES.has(rawCardType) ? rawCardType : "unknown";
  }

  const rawStatus =
    Object.prototype.hasOwnProperty.call(output, "status") ?
      String(output.status || "").trim() :
      "";
  if (isCreate || rawStatus) {
    output.status = CARD_STATUSES.has(rawStatus) ? rawStatus : "active";
  }

  if (isCreate) {
    output.sourceType = "userCreated";
    output.quality = {
      status: "needsDetails",
      ...(
        isPlainObject(output.quality) ?
          output.quality :
          {}
      ),
    };
  }

  return output;
}

/**
 * 객체를 dotted path changeSet으로 비교
 * @param {unknown} before
 * @param {unknown} after
 * @param {string} prefix
 * @return {Array<Record<string, unknown>>}
 */
function diffCardValues(before, after, prefix = "") {
  if (cardDeepEqual(before, after)) {
    return [];
  }

  if (isPlainObject(before) && isPlainObject(after)) {
    const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
    const changes = [];
    for (const key of keys) {
      const path = prefix ? `${prefix}.${key}` : key;
      changes.push(...diffCardValues(before[key], after[key], path));
    }
    return changes;
  }

  return [{
    path: prefix,
    oldValue: before === undefined ? null : before,
    newValue: after === undefined ? null : after,
  }];
}

/**
 * 깊은 비교
 * @param {unknown} left
 * @param {unknown} right
 * @return {boolean}
 */
function cardDeepEqual(left, right) {
  if (left === right) {
    return true;
  }
  if (left === undefined || right === undefined) {
    return false;
  }
  if (
    left &&
    right &&
    typeof left.toMillis === "function" &&
    typeof right.toMillis === "function"
  ) {
    return left.toMillis() === right.toMillis();
  }
  if (Array.isArray(left) || Array.isArray(right)) {
    if (!Array.isArray(left) || !Array.isArray(right)) {
      return false;
    }
    if (left.length !== right.length) {
      return false;
    }
    return left.every((item, index) => cardDeepEqual(item, right[index]));
  }
  if (isPlainObject(left) || isPlainObject(right)) {
    if (!isPlainObject(left) || !isPlainObject(right)) {
      return false;
    }
    const leftKeys = Object.keys(left);
    const rightKeys = Object.keys(right);
    if (leftKeys.length !== rightKeys.length) {
      return false;
    }
    return leftKeys.every((key) => cardDeepEqual(left[key], right[key]));
  }
  return false;
}

/**
 * patch를 적용한 다음 문서 스냅샷 계산
 * @param {Record<string, unknown>} current
 * @param {Record<string, unknown>} patch
 * @return {Record<string, unknown>}
 */
function applyCardPatchToObject(current, patch) {
  return {
    ...current,
    ...patch,
  };
}

/**
 * revision에 저장할 카드 문서 스냅샷
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>}
 */
function cardRevisionSnapshot(data) {
  const snapshot = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (typeof value !== "undefined") {
      snapshot[key] = value;
    }
  }
  return snapshot;
}

/**
 * 안정적인 JSON hash 생성
 * @param {unknown} value
 * @return {string}
 */
function cardHash(value) {
  return crypto
      .createHash("sha256")
      .update(JSON.stringify(value))
      .digest("hex");
}

/**
 * 카드고릴라 이미지 URL 정규화
 * @param {unknown} value
 * @return {string|null}
 */
function normalizeCardImageUrl(value) {
  let rawValue = value;
  if (value && typeof value === "object") {
    rawValue = value.url || value.path || value.src;
  }
  const text = asOptionalString(rawValue);
  if (!text) {
    return null;
  }
  if (text.startsWith("//")) {
    return `https:${text}`;
  }
  if (text.startsWith("http://") || text.startsWith("https://")) {
    return text;
  }
  if (text.startsWith("/")) {
    return `https://www.card-gorilla.com${text}`;
  }
  return text;
}

/**
 * content-type/url에서 이미지 확장자 추정
 * @param {string|null} contentType
 * @param {string} url
 * @return {string}
 */
function imageExtensionFor(contentType, url) {
  const type = (contentType || "").toLowerCase();
  if (type.includes("png")) {
    return "png";
  }
  if (type.includes("webp")) {
    return "webp";
  }
  if (type.includes("gif")) {
    return "gif";
  }
  const cleanUrl = url.split("?")[0].toLowerCase();
  const match = cleanUrl.match(/\.([a-z0-9]+)$/);
  if (match && ["jpg", "jpeg", "png", "webp", "gif"].includes(match[1])) {
    return match[1];
  }
  return "jpg";
}

/**
 * 외부 카드 이미지를 Firebase Storage로 복사
 * @param {string} cardId
 * @param {string|null} imageUrl
 * @return {Promise<Object|null>}
 */
async function copyCardImageToStorage(cardId, imageUrl) {
  const normalizedUrl = normalizeCardImageUrl(imageUrl);
  if (!normalizedUrl) {
    return null;
  }

  try {
    const response = await globalThis.fetch(normalizedUrl);
    if (!response.ok) {
      logger.warn("Card image fetch failed", {
        cardId,
        imageUrl: normalizedUrl,
        status: response.status,
      });
      return {
        sourceUrl: normalizedUrl,
        fetchStatus: response.status,
      };
    }

    const contentType = response.headers.get("content-type") || "image/jpeg";
    const buffer = Buffer.from(await response.arrayBuffer());
    const contentHash = crypto
        .createHash("sha256")
        .update(buffer)
        .digest("hex");
    const extension = imageExtensionFor(contentType, normalizedUrl);
    const storagePath =
      `cards/catalog/cardProducts/${cardId}/images/main.${extension}`;
    const token = crypto.randomUUID();

    await admin.storage().bucket(CARD_IMAGE_BUCKET).file(storagePath).save(
        buffer,
        {
          resumable: false,
          metadata: {
            contentType,
            metadata: {
              cardId,
              sourceUrl: normalizedUrl,
              contentHash,
              firebaseStorageDownloadTokens: token,
            },
          },
        },
    );

    return {
      storagePath,
      sourceUrl: normalizedUrl,
      contentHash,
      downloadUrl:
        `https://firebasestorage.googleapis.com/v0/b/${CARD_IMAGE_BUCKET}` +
        `/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`,
      uploadedAtIso: new Date().toISOString(),
    };
  } catch (error) {
    logger.warn("Card image copy failed", {
      cardId,
      imageUrl: normalizedUrl,
      message: error.message,
    });
    return {
      sourceUrl: normalizedUrl,
      error: error.message,
    };
  }
}

/**
 * 카드고릴라 카드사를 내부 issuer 문서로 정규화
 * @param {Object} item
 * @return {Object|null}
 */
function normalizeCardGorillaIssuer(item) {
  if (!item || typeof item !== "object") {
    return null;
  }
  const idx = asIdString(item.idx || item.no);
  const nameKo = asOptionalString(item.name);
  if (!idx || !nameKo) {
    return null;
  }
  return {
    issuerId: `cg_${idx}`,
    data: {
      sourceType: "cardGorilla",
      sourceRefs: {
        cardGorilla: {
          idx,
        },
      },
      nameKo,
      nameEng: asOptionalString(item.name_eng),
      color: asOptionalString(item.color),
      logoUrl: normalizeCardImageUrl(item.logo_img),
      eventEnabled: item.event_yn === "Y" || item.is_event === true,
      isVisible: item.is_visible !== false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

/**
 * 카드고릴라 카드 타입 정규화
 * @param {unknown} value
 * @return {string}
 */
function normalizeCardGorillaCardType(value) {
  const text = String(value || "").trim().toUpperCase();
  if (text === "CHK") {
    return "check";
  }
  if (text === "CRD") {
    return "credit";
  }
  return "unknown";
}

/**
 * 카드고릴라 카드 상태 정규화
 * @param {Object} data
 * @return {string}
 */
function normalizeCardGorillaStatus(data) {
  if (data.is_discon === true || data.is_discon === 1) {
    return "discontinued";
  }
  if (data.is_visible === false || data.is_visible === 0) {
    return "hidden";
  }
  if (data.is_impend === true || data.is_impend === 1) {
    return "pending";
  }
  return "active";
}

/**
 * 카드고릴라 혜택 목록을 사람이 읽는 배열로 축약
 * @param {unknown} value
 * @return {Array<Object>}
 */
function normalizeCardGorillaTopBenefits(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.slice(0, 30).map((item) => {
    if (!item || typeof item !== "object") {
      return {title: String(item || "")};
    }
    return {
      title: asOptionalString(item.title),
      value: asOptionalString(item.inputValue),
      tags: Array.isArray(item.tags) ? item.tags.map(String).slice(0, 20) : [],
      logoUrl: normalizeCardImageUrl(item.logo_img),
    };
  }).filter((item) => item.title || item.value);
}

/**
 * 카드 검색용 문자열을 비교하기 쉬운 형태로 변환
 * @param {unknown} value
 * @return {string}
 */
function normalizeCardSearchText(value) {
  return String(value || "")
      .normalize("NFKC")
      .toLowerCase()
      .replace(/[^\p{L}\p{N}]+/gu, " ")
      .replace(/\s+/g, " ")
      .trim();
}

/**
 * 검색 대상 카드에서 후보 비교 텍스트 구성
 * @param {Object} item
 * @return {string}
 */
function cardSourceCandidateText(item) {
  const corp = item.corp && typeof item.corp === "object" ?
    item.corp :
    {};
  const benefits = normalizeCardGorillaTopBenefits(item.top_benefit)
      .map((benefit) => [benefit.title, benefit.value].filter(Boolean))
      .flat()
      .join(" ");
  return normalizeCardSearchText([
    item.idx,
    item.cid,
    item.name,
    item.corp_txt,
    corp.name,
    item.cate_txt,
    item.brand_txt,
    item.annual_fee_basic,
    benefits,
  ].filter(Boolean).join(" "));
}

/**
 * 카드 후보 검색 점수 계산
 * @param {string} queryText
 * @param {Object} item
 * @return {number}
 */
function scoreCardSourceCandidate(queryText, item) {
  const normalizedQuery = normalizeCardSearchText(queryText);
  if (!normalizedQuery) {
    return 0;
  }

  const queryTerms = normalizedQuery.split(" ").filter(Boolean);
  const haystack = cardSourceCandidateText(item);
  const compactHaystack = haystack.replace(/\s+/g, "");
  const nameText = normalizeCardSearchText(item.name);
  const compactName = nameText.replace(/\s+/g, "");
  let score = 0;

  queryTerms.forEach((term) => {
    const compactTerm = term.replace(/\s+/g, "");
    if (haystack.split(" ").includes(term)) {
      score += 4;
    }
    if (haystack.includes(term)) {
      score += 2;
    }
    if (compactHaystack.includes(compactTerm)) {
      score += 2;
    }
    if (nameText.includes(term)) {
      score += 5;
    }
    if (compactName.includes(compactTerm)) {
      score += 5;
    }
  });

  if (nameText.startsWith(normalizedQuery)) {
    score += 8;
  }
  if (compactName.startsWith(normalizedQuery.replace(/\s+/g, ""))) {
    score += 6;
  }
  return score;
}

/**
 * 카드고릴라 검색 목록을 가져오고 짧게 캐시한다.
 * @return {Promise<Array<Object>>}
 */
async function fetchCardSourceSearchItems() {
  const nowMs = Date.now();
  if (
    cardSourceSearchCache.items &&
    nowMs - cardSourceSearchCache.fetchedAtMs < CARD_SOURCE_SEARCH_CACHE_MS
  ) {
    return cardSourceSearchCache.items;
  }

  const response = await globalThis.fetch(
      `${CARD_GORILLA_API_BASE}/cards/search?p=1&perPage=2000`,
  );
  if (!response.ok) {
    throw new HttpsError("unavailable", "카드 후보 검색에 실패했습니다.");
  }
  const payload = await response.json();
  const items = Array.isArray(payload) ? payload : payload.data || [];
  cardSourceSearchCache = {
    fetchedAtMs: nowMs,
    items,
  };
  return items;
}

/**
 * 원본 카드 목록 item을 앱 표시용 후보로 축약한다.
 * @param {Object} item
 * @param {number} score
 * @return {Object|null}
 */
function normalizeCardSourceCandidate(item, score) {
  const idx = asIdString(item.idx || item.no || item.cid);
  const name = asOptionalString(item.name);
  if (!idx || !name) {
    return null;
  }
  const corp = item.corp && typeof item.corp === "object" ?
    item.corp :
    {};
  const issuerName =
    asOptionalString(item.corp_txt) ||
    asOptionalString(corp.name) ||
    "카드사 미입력";
  const previousMonthSpend = asOptionalNumber(item.pre_month_money);

  return {
    sourceCardId: idx,
    name,
    issuerName,
    cardType: normalizeCardGorillaCardType(item.cate),
    cardTypeLabel: asOptionalString(item.cate_txt) ||
      (normalizeCardGorillaCardType(item.cate) === "check" ? "체크" : "신용"),
    status: normalizeCardGorillaStatus(item),
    annualFeeSummary: asOptionalString(item.annual_fee_basic),
    previousMonthSpendSummary: previousMonthSpend ?
      `${Math.round(previousMonthSpend).toLocaleString("ko-KR")}원` :
      null,
    imageUrl: normalizeCardImageUrl(item.card_img),
    primaryBenefits: normalizeCardGorillaTopBenefits(item.top_benefit)
        .slice(0, 5),
    score,
  };
}

/**
 * 카드고릴라 카드사 목록을 동기화하고 idx->name 맵을 반환한다.
 * @return {Promise<Map<string, string>>}
 */
async function syncCardGorillaIssuers() {
  const issuerNameByIdx = new Map();
  const issuerResponse = await globalThis.fetch(
      `${CARD_GORILLA_API_BASE}/card_corps`,
  );
  if (!issuerResponse.ok) {
    return issuerNameByIdx;
  }

  const issuerPayload = await issuerResponse.json();
  const issuers = Array.isArray(issuerPayload) ?
    issuerPayload :
    issuerPayload.data || [];
  const batch = admin.firestore().batch();
  let writeCount = 0;
  issuers.forEach((item) => {
    const normalized = normalizeCardGorillaIssuer(item);
    if (!normalized) {
      return;
    }
    const idx = normalized.data.sourceRefs.cardGorilla.idx;
    issuerNameByIdx.set(idx, normalized.data.nameKo);
    batch.set(
        cardCatalogRef()
            .collection("cardIssuers")
            .doc(normalized.issuerId),
        normalized.data,
        {merge: true},
    );
    writeCount += 1;
  });
  if (writeCount > 0) {
    await batch.commit();
  }
  return issuerNameByIdx;
}

/**
 * 카드고릴라 카드 상세를 내부 카드 문서로 정규화
 * @param {Object} source
 * @param {Map<string, string>} issuerNameByIdx
 * @param {Object|null} copiedImage
 * @return {Object}
 */
function normalizeCardGorillaProduct(source, issuerNameByIdx, copiedImage) {
  const idx = asIdString(source.idx);
  const corp = source.corp && typeof source.corp === "object" ?
    source.corp :
    {};
  const corpIdx = asIdString(corp.idx || source.corp_idx || source.corp);
  const issuerName =
    asOptionalString(corp.name) ||
    issuerNameByIdx.get(corpIdx) ||
    "카드사 미입력";
  const rawHash = cardHash(source);
  const topBenefits = normalizeCardGorillaTopBenefits(source.top_benefit);

  return {
    name: requireCardText(source.name, "카드명"),
    issuerName,
    issuerId: corpIdx ? `cg_${corpIdx}` : null,
    cardType: normalizeCardGorillaCardType(source.cate),
    status: normalizeCardGorillaStatus(source),
    sourceType: "cardGorilla",
    rewardProgram: asOptionalString(source.c_type),
    annualFee: {
      summary: asOptionalString(source.annual_fee_basic),
      detailHtml: asOptionalString(source.annual_fee_detail),
    },
    previousMonthSpend: {
      summary: asOptionalString(source.pre_month_money),
    },
    brands: sanitizeCardJsonValue(source.brand || []),
    primaryBenefits: topBenefits,
    calculatorRules: [],
    exclusions: [],
    detailSummary: topBenefits
        .map((item) => [item.title, item.value].filter(Boolean).join(" "))
        .filter(Boolean)
        .join("\n"),
    sourceRefs: {
      cardGorilla: {
        idx,
        cid: asOptionalString(source.cid),
        apiUrl: `${CARD_GORILLA_API_BASE}/cards/${idx}`,
        detailUrl: `https://www.card-gorilla.com/card/detail/${idx}`,
        fetchedAtIso: new Date().toISOString(),
        rawHash,
      },
    },
    images: copiedImage ? {main: copiedImage} : {
      main: {
        sourceUrl: normalizeCardImageUrl(source.card_img),
      },
    },
    quality: {
      status: "sourceImported",
      parserVersion: 1,
    },
  };
}

/**
 * 카드고릴라 상세 섹션 정규화
 * @param {Object} source
 * @return {Array<Object>}
 */
function normalizeCardGorillaDetailSections(source) {
  const sections = [];
  const feeHtml = asOptionalString(source.annual_fee_detail);
  if (feeHtml) {
    sections.push({
      id: "annual_fee",
      title: "연회비 상세",
      type: "annualFee",
      html: feeHtml,
      sortOrder: 0,
    });
  }

  const benefits = Array.isArray(source.key_benefit) ?
    source.key_benefit :
    [];
  benefits.slice(0, 80).forEach((benefit, index) => {
    if (!benefit || typeof benefit !== "object") {
      return;
    }
    const title = asOptionalString(benefit.title) ||
      asOptionalString(benefit.comment) ||
      `혜택 ${index + 1}`;
    const html = asOptionalString(benefit.info);
    const body = asOptionalString(benefit.comment);
    if (!html && !body) {
      return;
    }
    sections.push({
      id: `benefit_${index + 1}`,
      title,
      body,
      html,
      type: "benefit",
      sortOrder: index + 10,
      sourceCategory: sanitizeCardJsonValue(benefit.cate || null),
    });
  });

  const censorshipInfo = asOptionalString(source.censorship_info);
  if (censorshipInfo) {
    sections.push({
      id: "censorship_info",
      title: "유의사항",
      type: "notice",
      html: censorshipInfo,
      sortOrder: 900,
    });
  }
  return sections;
}

/**
 * 카드고릴라 카드 문서와 하위 상세 정보를 저장
 * @param {Object} params
 * @return {Promise<string>}
 */
async function upsertCardGorillaProduct(params) {
  const {
    uid,
    runId,
    source,
    issuerNameByIdx,
  } = params;
  const idx = asIdString(source.idx);
  const cardId = `cg_${idx}`;
  const productRef = cardCatalogRef().collection("cardProducts").doc(cardId);
  const snapshotRef = productRef.collection("sourceSnapshots").doc(runId);
  const copiedImage = await copyCardImageToStorage(cardId, source.card_img);
  const normalized = normalizeCardGorillaProduct(
      source,
      issuerNameByIdx,
      copiedImage,
  );
  const detailSections = normalizeCardGorillaDetailSections(source);
  const now = admin.firestore.FieldValue.serverTimestamp();

  await admin.firestore().runTransaction(async (transaction) => {
    const currentDoc = await transaction.get(productRef);
    const current = currentDoc.data() || {};
    const currentVersion = Number(current.version || 0);
    const action = currentDoc.exists ? "importUpdate" : "importCreate";
    const changeSet = [];

    if (currentDoc.exists) {
      for (const [field, value] of Object.entries(normalized)) {
        changeSet.push(...diffCardValues(current[field], value, field));
      }
    } else {
      for (const [path, newValue] of Object.entries(normalized)) {
        changeSet.push({path, oldValue: null, newValue});
      }
    }

    const effectiveChangeSet = changeSet.filter((change) => change.path);
    const nextVersion = effectiveChangeSet.length > 0 ?
      currentVersion + 1 :
      currentVersion || 1;
    const productPayload = {
      ...normalized,
      version: nextVersion,
      updatedAt: now,
      updatedByUid: uid,
    };
    if (!currentDoc.exists) {
      productPayload.createdAt = now;
      productPayload.createdByUid = uid;
    }

    if (currentDoc.exists) {
      if (effectiveChangeSet.length > 0) {
        transaction.update(productRef, productPayload);
      }
    } else {
      transaction.set(productRef, productPayload);
    }

    if (effectiveChangeSet.length > 0 || !currentDoc.exists) {
      const revisionRef = productRef.collection("revisions").doc();
      transaction.set(revisionRef, {
        cardId,
        action,
        status: "applied",
        sourceType: "cardGorilla",
        actorUid: uid,
        importRunId: runId,
        versionFrom: currentVersion,
        versionTo: nextVersion,
        changedFields: effectiveChangeSet.map((change) => change.path),
        changeSet: effectiveChangeSet,
        snapshotBefore: currentDoc.exists ?
          cardRevisionSnapshot(current) :
          null,
        snapshotAfter: cardRevisionSnapshot({
          ...current,
          ...normalized,
          version: nextVersion,
          updatedByUid: uid,
        }),
        createdAt: now,
      });
    }

    transaction.set(snapshotRef, {
      cardId,
      sourceType: "cardGorilla",
      sourceUrl: `${CARD_GORILLA_API_BASE}/cards/${idx}`,
      rawHash: cardHash(source),
      raw: sanitizeCardJsonValue(source),
      fetchedAt: now,
      importRunId: runId,
    });

    detailSections.forEach((section) => {
      transaction.set(
          productRef.collection("detailSections").doc(section.id),
          {
            ...section,
            updatedAt: now,
            sourceType: "cardGorilla",
          },
          {merge: true},
      );
    });
  });

  return cardId;
}

/**
 * 알림 data payload에 넣을 수 있는 문자열로 변환
 * @param {unknown} value
 * @return {string}
 */
function asFcmString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}

/**
 * 비교용 문자열 정규화
 * @param {unknown} value
 * @return {string}
 */
function normalizeRadarText(value) {
  return asFcmString(value).trim().toLowerCase();
}

/**
 * Firestore doc id에 안전한 문자열 생성
 * @param {string} value
 * @return {string}
 */
function sanitizeRadarId(value) {
  const sanitized = value.replace(/[^A-Za-z0-9_-]+/g, "_");
  return sanitized.slice(0, 220) || "radar_match";
}

/**
 * 금액 표시
 * @param {number|null} value
 * @return {string}
 */
function formatWon(value) {
  if (!Number.isFinite(value)) {
    return "";
  }
  return `${Math.round(value).toLocaleString("ko-KR")}원`;
}

/**
 * 레이더 타입 표시명
 * @param {string} type
 * @return {string}
 */
function radarTypeLabel(type) {
  switch (type) {
    case "mileageSeat":
      return "마일리지 좌석";
    case "cancelAlert":
      return "취소표";
    case "flightDeal":
      return "항공 특가";
    case "giftcard":
      return "상품권";
    case "benefitNews":
      return "뉴스/혜택";
    default:
      return "레이더";
  }
}

/**
 * 게시판 표시명
 * @param {string} boardId
 * @return {string}
 */
function radarBoardLabel(boardId) {
  const labels = {
    deal: "적립/카드 혜택",
    news: "오늘의 뉴스",
    seats: "오늘의 좌석",
    seat_share: "좌석 공유",
    aeroroute_news: "AeroRoutes",
    secretflying_news: "SecretFlying",
  };
  return labels[boardId] || boardId || "커뮤니티";
}

/**
 * HTML을 짧은 일반 텍스트로 변환
 * @param {string} html
 * @return {string}
 */
function radarPlainText(html) {
  const text = asFcmString(html)
      .replace(/<[^>]+>/g, " ")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/\s+/g, " ")
      .trim();
  return text.length > 80 ? `${text.slice(0, 80)}...` : text;
}

/**
 * 레이더 item 객체를 표준 형태로 정리
 * @param {string} itemId
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>|null}
 */
function normalizeRadarItem(itemId, data) {
  const itemType = asOptionalString(data.itemType) || "";
  if (!RADAR_SUPPORTED_TYPES.has(itemType)) {
    return null;
  }

  return {
    id: itemId,
    itemType,
    title: asOptionalString(data.title) || "레이더 매칭",
    subtitle: asOptionalString(data.subtitle) || "",
    reason: asOptionalString(data.reason) || "",
    source: asOptionalString(data.source) || "마일캐치",
    route: asOptionalString(data.route) || "",
    dateRange: asOptionalString(data.dateRange) || "",
    price: asOptionalNumber(data.price),
    miles: asOptionalNumber(data.miles),
    cashValue: asOptionalNumber(data.cashValue),
    costPerMile: asOptionalNumber(data.costPerMile),
    urgency: asOptionalString(data.urgency) || "",
    deepLink: asOptionalString(data.deepLink) || "",
    updatedAt: asOptionalDate(data.updatedAt) || new Date(),
    payload: data.payload && typeof data.payload === "object" ?
      data.payload :
      {},
  };
}

/**
 * 항공권 특가 문서를 레이더 item으로 변환
 * @param {string} dealId
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>|null}
 */
function buildFlightDealRadarItem(dealId, data) {
  const price = asOptionalNumber(data.price);
  if (!price || price <= 0) {
    return null;
  }

  const origin = asOptionalString(data.origin_airport) || "";
  const dest = asOptionalString(data.dest_airport) || "";
  const route = origin && dest ? `${origin}-${dest}` : "";
  const priceDisplay = asOptionalString(data.price_display) || formatWon(price);

  return {
    id: `flight_${dealId}`,
    itemType: "flightDeal",
    title: route ? `${route} ${priceDisplay}` : `항공 특가 ${priceDisplay}`,
    subtitle: [
      asOptionalString(data.dest_city),
      asOptionalString(data.airline_name),
    ].filter(Boolean).join(" · "),
    reason: "조건에 맞는 항공권 특가가 갱신되었습니다.",
    source: asOptionalString(data.agency) || "항공권 특가",
    route,
    dateRange: radarDealDateRange(data),
    price,
    miles: null,
    cashValue: price,
    costPerMile: null,
    urgency: "가격 갱신",
    deepLink: asOptionalString(data.booking_url) || "",
    updatedAt: asOptionalDate(data.last_updated) ||
      asOptionalDate(data.updatedAt) ||
      new Date(),
    payload: {
      dealId,
      originAirport: origin,
      destAirport: dest,
      bookingUrl: asOptionalString(data.booking_url) || "",
    },
  };
}

/**
 * 항공권 문서 날짜 범위 추출
 * @param {Record<string, unknown>} data
 * @return {string}
 */
function radarDealDateRange(data) {
  const availableDates = Array.isArray(data.available_dates) ?
    data.available_dates :
    [];
  if (availableDates.length > 0 && typeof availableDates[0] === "object") {
    const first = availableDates[0];
    const departure = asOptionalString(first.departure_date) ||
      asOptionalString(first.departure) ||
      "";
    const arrival = asOptionalString(first.return_date) ||
      asOptionalString(first.return) ||
      "";
    if (departure && arrival) {
      return `${departure}~${arrival}`;
    }
    if (departure) {
      return departure;
    }
  }

  const start =
    formatSupplyDate(asOptionalString(data.supply_start_date) || "");
  const end = formatSupplyDate(asOptionalString(data.supply_end_date) || "");
  return start && end ? `${start}~${end}` : start;
}

/**
 * YYYYMMDD 문자열을 YYYY-MM-DD로 변환
 * @param {string} value
 * @return {string}
 */
function formatSupplyDate(value) {
  if (!/^\d{8}$/.test(value)) {
    return value;
  }
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
}

/**
 * 상품권 문서를 레이더 item으로 변환
 * @param {string} giftcardId
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>|null}
 */
function buildGiftcardRadarItem(giftcardId, data) {
  const price = asOptionalNumber(data.bestSellPrice);
  if (!price || price <= 0) {
    return null;
  }

  const name = asOptionalString(data.name) || giftcardId;
  const branch = asOptionalString(data.bestSellBranchName) ||
    asOptionalString(data.bestSellBranchId) ||
    "상품권 시세";

  return {
    id: `giftcard_${giftcardId}`,
    itemType: "giftcard",
    title: `${name} 매입가 갱신`,
    subtitle: `최고 ${formatWon(price)} · ${branch}`,
    reason: "상품권 매입가가 레이더 조건에 맞게 갱신되었습니다.",
    source: branch,
    route: "",
    dateRange: "",
    price,
    miles: null,
    cashValue: null,
    costPerMile: null,
    urgency: "시세 갱신",
    deepLink: "",
    updatedAt: asOptionalDate(data.updatedAt) || new Date(),
    payload: {
      giftcardId,
      giftcardName: name,
    },
  };
}

/**
 * 커뮤니티 게시글을 레이더 item으로 변환
 * @param {string} date
 * @param {string} postId
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>|null}
 */
function buildPostRadarItem(date, postId, data) {
  const boardId = asOptionalString(data.boardId) || "";
  const allowedBoards = new Set([
    "deal",
    "news",
    "seats",
    "seat_share",
    "aeroroute_news",
    "secretflying_news",
  ]);
  if (!allowedBoards.has(boardId) || data.isDeleted === true) {
    return null;
  }

  const source = radarBoardLabel(boardId);
  return {
    id: `post_${postId}`,
    itemType: "benefitNews",
    title: asOptionalString(data.title) || "커뮤니티 소식",
    subtitle: radarPlainText(asOptionalString(data.contentHtml) || ""),
    reason: `${source} 게시판에 새 정보가 등록되었습니다.`,
    source,
    route: "",
    dateRange: "",
    price: null,
    miles: null,
    cashValue: null,
    costPerMile: null,
    urgency: "새 글",
    deepLink: "",
    updatedAt: asOptionalDate(data.createdAt) || new Date(),
    payload: {
      postId,
      boardId,
      boardName: source,
      dateString: date,
    },
  };
}

/**
 * 인기 취소표 문서를 레이더 item으로 변환
 * @param {string} routeKey
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>|null}
 */
function buildCancelRadarItem(routeKey, data) {
  const count = asOptionalNumber(data.count) || 0;
  const route = routeKey.split("_")[0] || routeKey;
  if (!route) {
    return null;
  }

  return {
    id: `cancel_${routeKey}`,
    itemType: "cancelAlert",
    title: `${route} 취소표 관심 증가`,
    subtitle: `${count}명 구독 중`,
    reason: "관심 구간 취소표 알림 수요가 증가했습니다.",
    source: "취소표 알림",
    route,
    dateRange: "",
    price: null,
    miles: null,
    cashValue: null,
    costPerMile: null,
    urgency: count >= 10 ? "높음" : "관심 증가",
    deepLink: "",
    updatedAt: asOptionalDate(data.lastUpdated) || new Date(),
    payload: {
      routeKey,
      count,
    },
  };
}

/**
 * 좌석 수를 숫자로 변환
 * @param {unknown} cabinData
 * @return {number}
 */
function radarSeatAmount(cabinData) {
  if (cabinData && typeof cabinData === "object") {
    return asOptionalNumber(cabinData.amount) || 0;
  }
  return asOptionalNumber(cabinData) || 0;
}

/**
 * 좌석별 필요 마일 추출
 * @param {unknown} cabinData
 * @return {number|null}
 */
function radarSeatMiles(cabinData) {
  if (cabinData && typeof cabinData === "object") {
    return asOptionalNumber(cabinData.mileage);
  }
  return null;
}

/**
 * 좌석 데이터에서 열린 캐빈 목록 생성
 * @param {Record<string, unknown>} data
 * @return {Array<Record<string, unknown>>}
 */
function radarSeatCabins(data) {
  const labels = {
    economy: "이코노미",
    business: "비즈니스",
    first: "퍼스트",
  };

  return Object.keys(labels)
      .map((key) => {
        const cabinData = data[key];
        return {
          key,
          label: labels[key],
          amount: radarSeatAmount(cabinData),
          miles: radarSeatMiles(cabinData),
        };
      })
      .filter((cabin) => cabin.amount > 0);
}

/**
 * 좌석 수가 새로 생기거나 증가했는지 확인
 * @param {Record<string, unknown>|null} before
 * @param {Record<string, unknown>} after
 * @return {boolean}
 */
function hasSeatCabinIncrease(before, after) {
  const afterCabins = radarSeatCabins(after);
  if (afterCabins.length === 0) {
    return false;
  }
  if (!before) {
    return true;
  }
  return afterCabins.some((cabin) => {
    const beforeAmount = radarSeatAmount(before[cabin.key]);
    return cabin.amount > beforeAmount;
  });
}

/**
 * 좌석 일자 표시 형식 변환
 * @param {string} value
 * @return {string}
 */
function formatRadarSeatDate(value) {
  if (/^\d{8}/.test(value)) {
    return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
  }
  return value;
}

/**
 * 열린 캐빈 중 가장 낮은 필요 마일 반환
 * @param {Array<Record<string, unknown>>} cabins
 * @return {number|null}
 */
function lowestRadarSeatMiles(cabins) {
  const miles = cabins
      .map((cabin) => asOptionalNumber(cabin.miles))
      .filter((value) => value && value > 0);
  if (miles.length === 0) {
    return null;
  }
  return Math.min(...miles);
}

/**
 * 마일리지 좌석 데이터를 레이더 item으로 변환
 * @param {string} airline
 * @param {string} routeDoc
 * @param {string} date
 * @param {Record<string, unknown>} data
 * @return {Record<string, unknown>|null}
 */
function buildMileageSeatRadarItem(airline, routeDoc, date, data) {
  const cabins = radarSeatCabins(data);
  if (cabins.length === 0) {
    return null;
  }

  const departure = asOptionalString(data.departureAirport) ||
    routeDoc.split("-")[0] ||
    "";
  const arrival = asOptionalString(data.arrivalAirport) ||
    routeDoc.split("-")[1] ||
    "";
  const route = departure && arrival ? `${departure}-${arrival}` : routeDoc;
  const dateRange = formatRadarSeatDate(date);
  const cabinText = cabins
      .map((cabin) => `${cabin.label} ${cabin.amount}석`)
      .join(" · ");
  const itemId = sanitizeRadarId([
    "mileage",
    airline,
    route,
    dateRange,
    cabins.map((cabin) => cabin.key).join("_"),
  ].join("_"));

  return {
    id: itemId,
    itemType: "mileageSeat",
    title: `${route} ${airline} 마일리지 좌석`,
    subtitle: `${dateRange} · ${cabinText}`,
    reason: `${airline} ${route} 구간에 ${cabinText}이 확인되었습니다.`,
    source: `${airline} 마일리지`,
    route,
    dateRange,
    price: null,
    miles: lowestRadarSeatMiles(cabins),
    cashValue: null,
    costPerMile: null,
    urgency: cabins.some((cabin) => cabin.key !== "economy") ?
      "프리미엄 좌석" :
      "좌석 확인",
    deepLink: "",
    updatedAt: new Date(),
    payload: {
      airline,
      routeDoc,
      departureDate: date,
      cabinKeys: cabins.map((cabin) => cabin.key),
      cabins: cabins.map((cabin) => cabin.label),
    },
  };
}

/**
 * 대한항공 snapshot 문서를 레이더 item 목록으로 변환
 * @param {string} routeDoc
 * @param {Record<string, unknown>|undefined} beforeData
 * @param {Record<string, unknown>} afterData
 * @return {Array<Record<string, unknown>>}
 */
function buildDanMileageSeatRadarItems(routeDoc, beforeData, afterData) {
  const seatsByDate = afterData.seatsByDate &&
    typeof afterData.seatsByDate === "object" ?
    afterData.seatsByDate :
    {};
  const beforeSeatsByDate = beforeData &&
    beforeData.seatsByDate &&
    typeof beforeData.seatsByDate === "object" ?
    beforeData.seatsByDate :
    {};

  return Object.keys(seatsByDate)
      .sort()
      .map((date) => {
        const payload = seatsByDate[date] &&
          typeof seatsByDate[date] === "object" ?
          seatsByDate[date] :
          {};
        const beforePayload = beforeSeatsByDate[date] &&
          typeof beforeSeatsByDate[date] === "object" ?
          beforeSeatsByDate[date] :
          null;
        const itemData = {
          departureDate: date,
          departureAirport: afterData.departureAirport,
          arrivalAirport: afterData.arrivalAirport,
          economy: payload.economy,
          business: payload.business,
          first: payload.first,
        };
        const beforeItemData = beforePayload ? {
          economy: beforePayload.economy,
          business: beforePayload.business,
          first: beforePayload.first,
        } : null;
        if (!hasSeatCabinIncrease(beforeItemData, itemData)) {
          return null;
        }
        return buildMileageSeatRadarItem(
            "대한항공",
            routeDoc,
            date,
            itemData,
        );
      })
      .filter(Boolean)
      .slice(0, 8);
}

/**
 * 아시아나 좌석 문서를 레이더 item으로 변환
 * @param {string} routeDoc
 * @param {string} seatDocId
 * @param {Record<string, unknown>|undefined} beforeData
 * @param {Record<string, unknown>} afterData
 * @return {Record<string, unknown>|null}
 */
function buildAsianaMileageSeatRadarItem(
    routeDoc,
    seatDocId,
    beforeData,
    afterData,
) {
  if (!hasSeatCabinIncrease(beforeData || null, afterData)) {
    return null;
  }
  const date = asOptionalString(afterData.departureDate) || seatDocId;
  return buildMileageSeatRadarItem("아시아나", routeDoc, date, afterData);
}

/**
 * 레이더 구독이 활성 상태인지 확인
 * @param {Record<string, unknown>} data
 * @param {Date} now
 * @return {boolean}
 */
function isActiveRadarSubscription(data, now) {
  if (!data || data.pushEnabled === false || data.isActive === false) {
    return false;
  }
  const expiresAt = asOptionalDate(data.expiresAt);
  return !expiresAt || expiresAt > now;
}

/**
 * 레이더 item과 구독 조건 매칭
 * @param {Record<string, unknown>} item
 * @param {Record<string, unknown>} subscription
 * @return {boolean}
 */
function doesRadarItemMatchSubscription(item, subscription) {
  if (!item || !subscription || subscription.type !== item.itemType) {
    return false;
  }

  const conditions = subscription.conditions &&
    typeof subscription.conditions === "object" ?
    subscription.conditions :
    {};

  const route = normalizeRadarText(conditions.route);
  const itemRoute = normalizeRadarText(item.route);
  if (route && route !== itemRoute) {
    return false;
  }

  const source = normalizeRadarText(conditions.source);
  const itemSource = normalizeRadarText(item.source);
  if (item.itemType === "benefitNews" && source && source !== itemSource) {
    return false;
  }

  const dateRange = normalizeRadarText(conditions.dateRange);
  const itemDateRange = normalizeRadarText(item.dateRange);
  if (item.itemType === "mileageSeat" &&
      dateRange &&
      dateRange !== itemDateRange) {
    return false;
  }

  const conditionPayload = conditions.payload &&
    typeof conditions.payload === "object" ?
    conditions.payload :
    {};
  const itemPayload = item.payload && typeof item.payload === "object" ?
    item.payload :
    {};

  if (conditionPayload.giftcardId &&
      conditionPayload.giftcardId !== itemPayload.giftcardId) {
    return false;
  }

  const conditionCabins = Array.isArray(conditionPayload.cabinKeys) ?
    conditionPayload.cabinKeys.map(normalizeRadarText).filter(Boolean) :
    [];
  const itemCabins = Array.isArray(itemPayload.cabinKeys) ?
    itemPayload.cabinKeys.map(normalizeRadarText).filter(Boolean) :
    [];
  if (conditionCabins.length > 0 &&
      itemCabins.length > 0 &&
      !conditionCabins.some((cabin) => itemCabins.includes(cabin))) {
    return false;
  }

  const conditionPrice = asOptionalNumber(conditions.price);
  const itemPrice = asOptionalNumber(item.price);
  if (conditionPrice && itemPrice) {
    if (item.itemType === "giftcard") {
      if (itemPrice < conditionPrice) {
        return false;
      }
    } else if (itemPrice > conditionPrice) {
      return false;
    }
  }

  const conditionMiles = asOptionalNumber(conditions.miles);
  const itemMiles = asOptionalNumber(item.miles);
  if (conditionMiles && itemMiles && itemMiles > conditionMiles) {
    return false;
  }

  return true;
}

/**
 * 매칭 dedupe fingerprint 생성
 * @param {Record<string, unknown>} item
 * @return {string}
 */
function radarMatchFingerprint(item) {
  const updatedAt = item.updatedAt instanceof Date ?
    item.updatedAt.getTime() :
    Date.now();
  const price = asOptionalNumber(item.price) || "";
  const miles = asOptionalNumber(item.miles) || "";
  return sanitizeRadarId(`${item.id}_${price}_${miles}_${updatedAt}`);
}

/**
 * 레이더 알림 본문 생성
 * @param {Record<string, unknown>} item
 * @return {string}
 */
function radarNotificationBody(item) {
  const parts = [
    asOptionalString(item.route),
    asOptionalString(item.dateRange),
    item.price ? formatWon(asOptionalNumber(item.price)) : "",
    item.miles ?
      `${Math.round(asOptionalNumber(item.miles)).toLocaleString("ko-KR")}마일` :
      "",
    asOptionalString(item.reason),
  ].filter(Boolean);

  return parts.length > 0 ?
    parts.join(" · ") :
    `${radarTypeLabel(item.itemType)} 조건에 맞는 항목을 찾았습니다.`;
}

/**
 * 사용자에게 레이더 매칭 알림 저장 및 FCM 전송
 * @param {string} uid
 * @param {FirebaseFirestore.DocumentReference} subscriptionRef
 * @param {Record<string, unknown>} subscription
 * @param {Record<string, unknown>} item
 * @param {string} triggerName
 * @return {Promise<void>}
 */
async function notifyRadarSubscriptionIfMatches(
    uid,
    subscriptionRef,
    subscription,
    item,
    triggerName,
) {
  const now = new Date();
  if (!isActiveRadarSubscription(subscription, now)) {
    return;
  }
  if (!doesRadarItemMatchSubscription(item, subscription)) {
    return;
  }

  const fingerprint = radarMatchFingerprint(item);
  const notificationId =
    sanitizeRadarId(`${subscriptionRef.id}_${fingerprint}`);
  const userRef = admin.firestore().collection("users").doc(uid);
  const notificationRef = userRef
      .collection(RADAR_MATCH_COLLECTION)
      .doc(notificationId);
  const existing = await notificationRef.get();
  if (existing.exists) {
    return;
  }

  const title = `[${radarTypeLabel(item.itemType)}] ${item.title}`;
  const body = radarNotificationBody(item);
  const notificationData = {
    type: item.itemType,
    itemType: item.itemType,
    itemId: item.id,
    subscriptionId: subscriptionRef.id,
    title,
    body,
    source: item.source || "",
    route: item.route || "",
    dateRange: item.dateRange || "",
    price: item.price || null,
    miles: item.miles || null,
    deepLink: item.deepLink || "",
    payload: item.payload || {},
    triggerName,
    matchKey: notificationId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  };

  await notificationRef.set(notificationData);
  await subscriptionRef.set({
    lastMatchedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastMatchedItemId: item.id,
  }, {merge: true});

  const userDoc = await userRef.get();
  const userData = userDoc.exists ? userDoc.data() : {};
  const fcmToken = userData && userData.fcmToken;
  if (!fcmToken || subscription.pushEnabled === false) {
    logger.info(`레이더 알림 저장 완료, FCM 없음: uid=${uid}`);
    return;
  }

  const message = {
    token: fcmToken,
    data: {
      type: "radar_match",
      radarType: asFcmString(item.itemType),
      notificationId,
      subscriptionId: subscriptionRef.id,
      itemId: asFcmString(item.id),
      route: asFcmString(item.route),
      dateRange: asFcmString(item.dateRange),
      deepLink: asFcmString(item.deepLink),
      path: "/radar/notifications",
      notificationTitle: title,
      notificationBody: body,
      channelId: RADAR_CHANNEL_ID,
    },
    android: {
      priority: "high",
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  const response = await admin.messaging().send(message);
  logger.info(`레이더 FCM 발송 성공: uid=${uid}, messageId=${response}`);
}

/**
 * item 하나를 모든 활성 레이더 구독과 매칭
 * @param {Record<string, unknown>} item
 * @param {string} triggerName
 * @return {Promise<void>}
 */
async function notifyRadarMatchesForItem(item, triggerName) {
  if (!item || !RADAR_SUPPORTED_TYPES.has(item.itemType)) {
    return;
  }

  const snapshot = await admin.firestore()
      .collectionGroup(RADAR_SUBSCRIPTION_COLLECTION)
      .where("type", "==", item.itemType)
      .limit(500)
      .get();
  const now = new Date();
  const tasks = [];

  snapshot.docs.forEach((doc) => {
    const data = doc.data();
    const parent = doc.ref.parent.parent;
    if (!parent || !isActiveRadarSubscription(data, now)) {
      return;
    }
    if (data.type !== item.itemType) {
      return;
    }
    tasks.push(
        notifyRadarSubscriptionIfMatches(
            parent.id,
            doc.ref,
            data,
            item,
            triggerName,
        ),
    );
  });

  await Promise.all(tasks);
  logger.info(
      `레이더 매칭 완료: item=${item.id}, type=${item.itemType}, ` +
      `matchedTasks=${tasks.length}`,
  );
}

/**
 * 새 구독 생성 시 현재 radar_items와 즉시 매칭
 * @param {string} uid
 * @param {FirebaseFirestore.DocumentReference} subscriptionRef
 * @param {Record<string, unknown>} subscription
 * @return {Promise<void>}
 */
async function matchNewRadarSubscription(uid, subscriptionRef, subscription) {
  const type = asOptionalString(subscription.type) || "";
  if (!RADAR_SUPPORTED_TYPES.has(type)) {
    return;
  }

  const snapshot = await admin.firestore()
      .collection("radar_items")
      .where("itemType", "==", type)
      .limit(30)
      .get();
  const tasks = snapshot.docs
      .map((doc) => normalizeRadarItem(doc.id, doc.data()))
      .filter(Boolean)
      .map((item) => notifyRadarSubscriptionIfMatches(
          uid,
          subscriptionRef,
          subscription,
          item,
          "radar_subscription_created",
      ));
  await Promise.all(tasks);
}

/**
 * source 문서의 주요 필드 변경 여부 확인
 * @param {Record<string, unknown>|undefined} before
 * @param {Record<string, unknown>|undefined} after
 * @param {string[]} fields
 * @return {boolean}
 */
function hasRadarSourceChange(before, after, fields) {
  if (!before) {
    return true;
  }
  if (!after) {
    return false;
  }
  return fields.some((field) => {
    const beforeValue = before[field];
    const afterValue = after[field];
    return JSON.stringify(beforeValue) !== JSON.stringify(afterValue);
  });
}

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

/**
 * 레이더 알림 조건 생성 시 현재 서버 레이더 아이템과 즉시 매칭
 */
exports.onRadarSubscriptionCreated = onDocumentCreated({
  document: "users/{uid}/radar_subscriptions/{subscriptionId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {uid, subscriptionId} = event.params;
    const data = event.data.data();
    const ref = admin.firestore()
        .collection("users")
        .doc(uid)
        .collection(RADAR_SUBSCRIPTION_COLLECTION)
        .doc(subscriptionId);

    logger.info(
        `레이더 구독 생성 감지: uid=${uid}, subscription=${subscriptionId}`,
    );
    await matchNewRadarSubscription(uid, ref, data);
  } catch (error) {
    logger.error(`레이더 구독 생성 처리 오류: ${error.message}`, error);
  }
});

/**
 * 운영/서버에서 radar_items 문서를 추가/갱신하면 모든 활성 구독과 매칭
 */
exports.onRadarItemWritten = onDocumentWritten({
  document: "radar_items/{itemId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {itemId} = event.params;
    const after = event.data.after;
    if (!after.exists) {
      return;
    }

    const beforeData = event.data.before.exists ?
      event.data.before.data() :
      undefined;
    const afterData = after.data();
    const changed = hasRadarSourceChange(beforeData, afterData, [
      "itemType",
      "title",
      "route",
      "dateRange",
      "price",
      "miles",
      "deepLink",
      "updatedAt",
      "payload",
    ]);
    if (!changed) {
      return;
    }

    const item = normalizeRadarItem(itemId, afterData);
    await notifyRadarMatchesForItem(item, "radar_item_written");
  } catch (error) {
    logger.error(`레이더 아이템 갱신 처리 오류: ${error.message}`, error);
  }
});

/**
 * 대한항공 좌석 snapshot이 갱신되면 mileageSeat 레이더 구독과 매칭
 */
exports.onDanMileageSeatRadarWritten = onDocumentWritten({
  document: "dan/{routeDoc}/{snapshotCollection}/{snapshotId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {routeDoc, snapshotCollection, snapshotId} = event.params;
    if (snapshotCollection === "flightInfo" ||
        snapshotCollection === "latest" ||
        snapshotId !== "snapshot") {
      return;
    }

    const after = event.data.after;
    if (!after.exists) {
      return;
    }
    const beforeData = event.data.before.exists ?
      event.data.before.data() :
      undefined;
    const items = buildDanMileageSeatRadarItems(
        routeDoc,
        beforeData,
        after.data(),
    );
    await Promise.all(items.map((item) => {
      return notifyRadarMatchesForItem(item, "dan_mileage_seat_written");
    }));
  } catch (error) {
    logger.error(`대한항공 좌석 레이더 처리 오류: ${error.message}`, error);
  }
});

/**
 * 아시아나 좌석 문서가 갱신되면 mileageSeat 레이더 구독과 매칭
 */
exports.onAsianaMileageSeatRadarWritten = onDocumentWritten({
  document: "asiana/{routeDoc}/{snapshotCollection}/{seatDocId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {routeDoc, snapshotCollection, seatDocId} = event.params;
    if (snapshotCollection === "flightInfo" ||
        snapshotCollection === "latest") {
      return;
    }

    const after = event.data.after;
    if (!after.exists) {
      return;
    }
    const beforeData = event.data.before.exists ?
      event.data.before.data() :
      undefined;
    const item = buildAsianaMileageSeatRadarItem(
        routeDoc,
        seatDocId,
        beforeData,
        after.data(),
    );
    await notifyRadarMatchesForItem(item, "asiana_mileage_seat_written");
  } catch (error) {
    logger.error(`아시아나 좌석 레이더 처리 오류: ${error.message}`, error);
  }
});

/**
 * 항공권 특가가 생성/갱신되면 flightDeal 레이더 구독과 매칭
 */
exports.onFlightDealRadarSourceWritten = onDocumentWritten({
  document: "deals/{dealId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {dealId} = event.params;
    const after = event.data.after;
    if (!after.exists) {
      return;
    }

    const beforeData = event.data.before.exists ?
      event.data.before.data() :
      undefined;
    const afterData = after.data();
    const changed = hasRadarSourceChange(beforeData, afterData, [
      "price",
      "price_display",
      "origin_airport",
      "dest_airport",
      "available_dates",
      "supply_start_date",
      "supply_end_date",
      "booking_url",
    ]);
    if (!changed) {
      return;
    }

    const item = buildFlightDealRadarItem(dealId, afterData);
    await notifyRadarMatchesForItem(item, "deal_written");
  } catch (error) {
    logger.error(`항공 특가 레이더 처리 오류: ${error.message}`, error);
  }
});

/**
 * 상품권 최고 매입가가 갱신되면 giftcard 레이더 구독과 매칭
 */
exports.onGiftcardRadarSourceWritten = onDocumentWritten({
  document: "giftcards/{giftcardId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {giftcardId} = event.params;
    const after = event.data.after;
    if (!after.exists) {
      return;
    }

    const beforeData = event.data.before.exists ?
      event.data.before.data() :
      undefined;
    const afterData = after.data();
    const changed = hasRadarSourceChange(beforeData, afterData, [
      "name",
      "bestSellPrice",
      "bestSellBranchName",
      "bestSellBranchId",
    ]);
    if (!changed) {
      return;
    }

    const item = buildGiftcardRadarItem(giftcardId, afterData);
    await notifyRadarMatchesForItem(item, "giftcard_written");
  } catch (error) {
    logger.error(`상품권 레이더 처리 오류: ${error.message}`, error);
  }
});

/**
 * 커뮤니티 정보성 게시글이 생성되면 benefitNews 레이더 구독과 매칭
 */
exports.onCommunityRadarPostCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {date, postId} = event.params;
    const item = buildPostRadarItem(date, postId, event.data.data());
    await notifyRadarMatchesForItem(item, "community_post_created");
  } catch (error) {
    logger.error(`커뮤니티 레이더 처리 오류: ${error.message}`, error);
  }
});

/**
 * 인기 취소표 구간이 갱신되면 cancelAlert 레이더 구독과 매칭
 */
exports.onPopularSubscriptionRadarWritten = onDocumentWritten({
  document: "popular_subscriptions/{routeKey}",
  region: RADAR_REGION,
}, async (event) => {
  try {
    const {routeKey} = event.params;
    const after = event.data.after;
    if (!after.exists) {
      return;
    }

    const beforeData = event.data.before.exists ?
      event.data.before.data() :
      undefined;
    const afterData = after.data();
    const changed = hasRadarSourceChange(beforeData, afterData, [
      "count",
      "lastUpdated",
    ]);
    if (!changed) {
      return;
    }

    const item = buildCancelRadarItem(routeKey, afterData);
    await notifyRadarMatchesForItem(item, "popular_subscription_written");
  } catch (error) {
    logger.error(`취소표 레이더 처리 오류: ${error.message}`, error);
  }
});

/**
 * 게시글 좋아요 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/likes/{uid} onCreate
 *
 * 1번 사용자가 게시글을 생성
 * 2번 사용자가 해당 게시글을 좋아요함
 * → 1번 사용자의 디바이스에게 "2번 사용자가 게시글에 좋아요를 하였습니다." 알림 발송
 */
exports.onPostLikeCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/likes/{uid}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, uid} = event.params;

    logger.info(`좋아요 알림 시작: postId=${postId}, likedBy=${uid}`);

    // 1. 게시글 정보 조회
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    if (!postDoc.exists) {
      logger.error(`게시글을 찾을 수 없음: ${postId}`);
      return;
    }

    const postData = postDoc.data();
    const authorUid = postData.author.uid;
    const postTitle = postData.title;
    const boardId = postData.boardId || "free"; // 게시판 ID

    // boardId 기반으로 boardName 가져오기
    const boardName = await getBoardName(boardId);

    // 2. 자기 자신이 좋아요한 경우 알림 발송하지 않음
    if (authorUid === uid) {
      logger.info(`자기 자신이 좋아요한 경우 알림 발송하지 않음: ${uid}`);
      return;
    }

    // 3. 좋아요한 사용자 정보 조회
    const likerDoc = await admin.firestore()
        .collection("users")
        .doc(uid)
        .get();

    if (!likerDoc.exists) {
      logger.error(`좋아요한 사용자를 찾을 수 없음: ${uid}`);
      return;
    }

    const likerData = likerDoc.data();
    const likerName = likerData.displayName || "익명";

    // 4. 게시글 작성자의 FCM 토큰 조회
    const authorDoc = await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .get();

    if (!authorDoc.exists) {
      logger.error(`게시글 작성자를 찾을 수 없음: ${authorUid}`);
      return;
    }

    const authorData = authorDoc.data();
    const fcmToken = authorData.fcmToken;

    if (!fcmToken) {
      logger.info(`게시글 작성자의 FCM 토큰이 없음: ${authorUid}`);
      return;
    }

    // 5. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "post_like",
      postId: postId,
      postTitle: postTitle,
      boardId: boardId,
      boardName: boardName,
      likedBy: uid,
      likedByName: likerName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "좋아요 알림",
      body: `${likerName}님이 게시글에 좋아요를 하였습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(`알림 데이터 저장 완료: authorUid=${authorUid}, type=post_like`);

    // 6. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "post_like",
        postId: postId,
        postTitle: postTitle,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        likedBy: uid,
        likedByName: likerName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "좋아요 알림",
        notificationBody: `${likerName}님이 게시글에 좋아요를 하였습니다.`,
        channelId: "post_like_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`좋아요 알림 발송 성공: messageId=${response}`);

    logger.info(
        `좋아요 알림 완료: postId=${postId}, author=${authorUid}, liker=${uid}`,
    );
  } catch (error) {
    logger.error(`좋아요 알림 오류: ${error.message}`, error);
  }
});

/**
 * 댓글 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/comments/{commentId} onCreate
 *
 * 1번 사용자가 게시글을 생성
 * 2번 사용자가 해당 게시글에 댓글을 추가함
 * → 1번 사용자의 디바이스에게 "2번 사용자가 게시글에 댓글을 달았습니다." 알림 발송
 */
exports.onCommentCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/comments/{commentId}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, commentId} = event.params;
    const commentData = event.data.data();

    logger.info(
        `댓글 알림 시작: postId=${postId}, commentId=${commentId}, ` +
        `commenter=${commentData.uid}`,
    );

    // 1. 게시글 정보 조회
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    if (!postDoc.exists) {
      logger.error(`게시글을 찾을 수 없음: ${postId}`);
      return;
    }

    const postData = postDoc.data();
    const authorUid = postData.author.uid;
    const postTitle = postData.title;
    const boardId = postData.boardId || "free"; // 게시판 ID

    // boardId 기반으로 boardName 가져오기
    const boardName = await getBoardName(boardId);
    const commenterUid = commentData.uid;

    // 2. 대댓글인 경우 게시글 작성자에게 알림 발송하지 않음
    if (commentData.parentCommentId) {
      logger.info(`대댓글이므로 게시글 작성자에게 댓글 알림 발송하지 않음: ${commentId}`);
      return;
    }

    // 3. 자기 자신이 댓글을 단 경우 알림 발송하지 않음
    if (authorUid === commenterUid) {
      logger.info(`자기 자신이 댓글을 단 경우 알림 발송하지 않음: ${commenterUid}`);
      return;
    }

    // 4. 댓글 작성자 정보 조회
    const commenterDoc = await admin.firestore()
        .collection("users")
        .doc(commenterUid)
        .get();

    if (!commenterDoc.exists) {
      logger.error(`댓글 작성자를 찾을 수 없음: ${commenterUid}`);
      return;
    }

    const commenterData = commenterDoc.data();
    const commenterName = commenterData.displayName || "익명";

    // 5. 게시글 작성자의 FCM 토큰 조회
    const authorDoc = await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .get();

    if (!authorDoc.exists) {
      logger.error(`게시글 작성자를 찾을 수 없음: ${authorUid}`);
      return;
    }

    const authorData = authorDoc.data();
    const fcmToken = authorData.fcmToken;

    if (!fcmToken) {
      logger.info(`게시글 작성자의 FCM 토큰이 없음: ${authorUid}`);
      return;
    }

    // 6. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "post_comment",
      postId: postId,
      postTitle: postTitle,
      boardId: boardId,
      boardName: boardName,
      commentId: commentId,
      commentedBy: commenterUid,
      commentedByName: commenterName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "댓글 알림",
      body: `${commenterName}님이 게시글에 댓글을 달았습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(authorUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(`알림 데이터 저장 완료: authorUid=${authorUid}, type=post_comment`);

    // 7. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "post_comment",
        postId: postId,
        postTitle: postTitle,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        commentId: commentId,
        commentedBy: commenterUid,
        commentedByName: commenterName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "댓글 알림",
        notificationBody: `${commenterName}님이 게시글에 댓글을 달았습니다.`,
        channelId: "post_comment_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`댓글 알림 발송 성공: messageId=${response}`);

    logger.info(
        `댓글 알림 완료: postId=${postId}, author=${authorUid}, ` +
        `commenter=${commenterUid}`,
    );
  } catch (error) {
    logger.error(`댓글 알림 오류: ${error.message}`, error);
  }
});

/**
 * 대댓글 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/comments/{commentId} onCreate
 * 조거: parentCommentId가 있는 경우만 (답글인 경우)
 *
 * 1번 사용자가 게시글에 댓글을 달음
 * 2번 사용자가 1번 사용자의 댓글에 대댓글을 달음
 * → 1번 사용자의 디바이스에게 "2번 사용자가 댓글에 댓글을 달았습니다." 알림 발송
 */
exports.onReplyCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/comments/{commentId}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, commentId} = event.params;
    const commentData = event.data.data();

    // parentCommentId가 없는 경우 (원댓글인 경우) 처리하지 않음
    if (!commentData.parentCommentId) {
      logger.info(`원댓글이므로 대댓글 알림 처리하지 않음: ${commentId}`);
      return;
    }

    logger.info(
        `대댓글 알림 시작: postId=${postId}, commentId=${commentId}, ` +
        `replyTo=${commentData.parentCommentId}, replier=${commentData.uid}`,
    );

    const replierUid = commentData.uid;
    const parentCommentId = commentData.parentCommentId;

    // 1. 부모 댓글 정보 조회
    const parentCommentDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}/comments/${parentCommentId}`)
        .get();

    if (!parentCommentDoc.exists) {
      logger.error(`부모 댓글을 찾을 수 없음: ${parentCommentId}`);
      return;
    }

    const parentCommentData = parentCommentDoc.data();
    const parentCommenterUid = parentCommentData.uid;

    // 2. 자기 자신이 대댓글을 단 경우 알림 발송하지 않음
    if (parentCommenterUid === replierUid) {
      logger.info(
          `자기 자신이 대댓글을 단 경우 알림 발송하지 않음: ${replierUid}`,
      );
      return;
    }

    // 3. 대댓글 작성자 정보 조회
    const replierDoc = await admin.firestore()
        .collection("users")
        .doc(replierUid)
        .get();

    if (!replierDoc.exists) {
      logger.error(`대댓글 작성자를 찾을 수 없음: ${replierUid}`);
      return;
    }

    const replierData = replierDoc.data();
    const replierName = replierData.displayName || "익명";

    // 4. 부모 댓글 작성자의 FCM 토큰 조회
    const parentCommenterDoc = await admin.firestore()
        .collection("users")
        .doc(parentCommenterUid)
        .get();

    if (!parentCommenterDoc.exists) {
      logger.error(`부모 댓글 작성자를 찾을 수 없음: ${parentCommenterUid}`);
      return;
    }

    const parentCommenterData = parentCommenterDoc.data();
    const fcmToken = parentCommenterData.fcmToken;

    if (!fcmToken) {
      logger.info(`부모 댓글 작성자의 FCM 토큰이 없음: ${parentCommenterUid}`);
      return;
    }

    // 5. 게시글 정보 조회 (boardId, boardName용)
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    let boardId = "free";
    let boardName = "자유게시판";

    if (postDoc.exists) {
      const postData = postDoc.data();
      boardId = postData.boardId || "free";

      // boardId 기반으로 boardName 매핑
      const boardNameMap = {
        "free": "자유게시판",
        "question": "마일리지",
        "deal": "적립/카드 혜택",
        "seat_share": "좌석 공유",
        "review": "항공 리뷰",
        "error_report": "오류 신고",
        "suggestion": "건의사항",
        "notice": "운영 공지사항",
      };
      boardName = boardNameMap[boardId] || "자유게시판";
    }

    // 6. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "comment_reply",
      postId: postId,
      boardId: boardId,
      boardName: boardName,
      commentId: commentId,
      parentCommentId: parentCommentId,
      repliedBy: replierUid,
      repliedByName: replierName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "대댓글 알림",
      body: `${replierName}님이 댓글에 댓글을 달았습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(parentCommenterUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(
        `알림 데이터 저장 완료: parentCommenterUid=${parentCommenterUid}, ` +
        `type=comment_reply`,
    );

    // 7. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "comment_reply",
        postId: postId,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        commentId: commentId,
        parentCommentId: parentCommentId,
        repliedBy: replierUid,
        repliedByName: replierName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "대댓글 알림",
        notificationBody: `${replierName}님이 댓글에 댓글을 달았습니다.`,
        channelId: "comment_reply_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`대댓글 알림 발송 성공: messageId=${response}`);

    logger.info(
        `대댓글 알림 완료: postId=${postId}, parentCommenter=${parentCommenterUid}, ` +
        `replier=${replierUid}`,
    );
  } catch (error) {
    logger.error(`대댓글 알림 오류: ${error.message}`, error);
  }
});

/**
 * 댓글 좋아요 알림 Cloud Function
 * 트리거: posts/{date}/posts/{postId}/comments/{commentId}/likes/{uid} onCreate
 *
 * 1번 사용자가 게시글을 생성
 * 2번 사용자가 해당 게시글에 댓글을 추가함
 * 3번 사용자가 2번 사용자의 댓글에 좋아요를 함
 * → 2번 사용자의 디바이스에게 "3번 사용자가 댓글에 좋아요를 하였습니다." 알림 발송
 */
exports.onCommentLikeCreated = onDocumentCreated({
  document: "posts/{date}/posts/{postId}/comments/{commentId}/likes/{uid}",
  region: "asia-northeast3", // 서울 리전
}, async (event) => {
  try {
    const {date, postId, commentId, uid} = event.params;

    logger.info(
        `댓글 좋아요 알림 시작: postId=${postId}, commentId=${commentId}, ` +
        `likedBy=${uid}`,
    );

    // 1. 댓글 정보 조회
    const commentDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}/comments/${commentId}`)
        .get();

    if (!commentDoc.exists) {
      logger.error(`댓글을 찾을 수 없음: ${commentId}`);
      return;
    }

    const commentData = commentDoc.data();
    const commenterUid = commentData.uid;
    const commenterName = commentData.displayName || "익명";

    // 2. 자기 자신이 좋아요한 경우 알림 발송하지 않음
    if (commenterUid === uid) {
      logger.info(
          `자기 자신이 댓글에 좋아요한 경우 알림 발송하지 않음: ${uid}`,
      );
      return;
    }

    // 3. 좋아요한 사용자 정보 조회
    const likerDoc = await admin.firestore()
        .collection("users")
        .doc(uid)
        .get();

    if (!likerDoc.exists) {
      logger.error(`좋아요한 사용자를 찾을 수 없음: ${uid}`);
      return;
    }

    const likerData = likerDoc.data();
    const likerName = likerData.displayName || "익명";

    // 4. 댓글 작성자의 FCM 토큰 조회
    const commenterDoc = await admin.firestore()
        .collection("users")
        .doc(commenterUid)
        .get();

    if (!commenterDoc.exists) {
      logger.error(`댓글 작성자를 찾을 수 없음: ${commenterUid}`);
      return;
    }

    const commenterUserData = commenterDoc.data();
    const fcmToken = commenterUserData.fcmToken;

    if (!fcmToken) {
      logger.info(`댓글 작성자의 FCM 토큰이 없음: ${commenterUid}`);
      return;
    }

    // 5. 게시글 정보 조회 (boardId, boardName용)
    const postDoc = await admin.firestore()
        .doc(`posts/${date}/posts/${postId}`)
        .get();

    let boardId = "free";
    let boardName = "자유게시판";

    if (postDoc.exists) {
      const postData = postDoc.data();
      boardId = postData.boardId || "free";

      // boardId 기반으로 boardName 매핑
      const boardNameMap = {
        "free": "자유게시판",
        "question": "마일리지",
        "deal": "적립/카드 혜택",
        "seat_share": "좌석 공유",
        "review": "항공 리뷰",
        "error_report": "오류 신고",
        "suggestion": "건의사항",
        "notice": "운영 공지사항",
      };
      boardName = boardNameMap[boardId] || "자유게시판";
    }

    // 6. 알림 데이터를 사용자의 notifications 서브컬렉션에 저장
    const notificationData = {
      type: "comment_like",
      postId: postId,
      boardId: boardId,
      boardName: boardName,
      commentId: commentId,
      likedBy: uid,
      likedByName: likerName,
      commenterName: commenterName,
      date: date,
      path: `/community/detail/${date}/${postId}`,
      title: "댓글 좋아요 알림",
      body: `${likerName}님이 댓글에 좋아요를 하였습니다.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };

    await admin.firestore()
        .collection("users")
        .doc(commenterUid)
        .collection("notifications")
        .add(notificationData);

    logger.info(
        `알림 데이터 저장 완료: commenterUid=${commenterUid}, ` +
        `type=comment_like`,
    );

    // 7. FCM 메시지 발송
    const message = {
      token: fcmToken,
      data: {
        type: "comment_like",
        postId: postId,
        boardId: boardId, // 게시판 ID 추가
        boardName: boardName, // 게시판 이름 추가
        commentId: commentId,
        likedBy: uid,
        likedByName: likerName,
        commenterName: commenterName,
        date: date,
        path: `/community/detail/${date}/${postId}`, // deeplink용 경로
        // 알림 표시용 데이터
        notificationTitle: "댓글 좋아요 알림",
        notificationBody: `${likerName}님이 댓글에 좋아요를 하였습니다.`,
        channelId: "comment_like_notifications", // ✅ data로 이동
      },
      android: {
        priority: "high", // ✅ 알림 필드 없음
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    const response = await admin.messaging().send(message);
    logger.info(`댓글 좋아요 알림 발송 성공: messageId=${response}`);

    logger.info(
        `댓글 좋아요 알림 완료: postId=${postId}, commenter=${commenterUid}, ` +
        `liker=${uid}`,
    );
  } catch (error) {
    logger.error(`댓글 좋아요 알림 오류: ${error.message}`, error);
  }
});

/**
 * 공용 카드 카탈로그에 사용자가 새 카드를 추가한다.
 */
exports.createCardProduct = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  const input = request.data && request.data.card ?
    request.data.card :
    request.data || {};
  const cardData = normalizeCardPatch(input, true);

  const catalogRef = cardCatalogRef();
  const productsRef = catalogRef.collection("cardProducts");
  const rawRef = productsRef.doc();
  const cardId = `user_${rawRef.id}`;
  const productRef = productsRef.doc(cardId);
  const requestRef = catalogRef.collection("cardChangeRequests").doc();
  const revisionRef = productRef.collection("revisions").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await admin.firestore().runTransaction(async (transaction) => {
    const productPayload = {
      ...cardData,
      version: 1,
      createdAt: now,
      createdByUid: uid,
      updatedAt: now,
      updatedByUid: uid,
    };
    const snapshotAfter = cardRevisionSnapshot({
      ...cardData,
      version: 1,
      createdByUid: uid,
      updatedByUid: uid,
    });
    const changeSet = Object.entries(snapshotAfter).map(([path, newValue]) => ({
      path,
      oldValue: null,
      newValue,
    }));

    transaction.set(productRef, productPayload);
    transaction.set(revisionRef, {
      cardId,
      action: "create",
      status: "applied",
      sourceType: "user",
      actorUid: uid,
      versionFrom: 0,
      versionTo: 1,
      changedFields: changeSet.map((change) => change.path),
      changeSet,
      snapshotBefore: null,
      snapshotAfter,
      createdAt: now,
    });
    transaction.set(requestRef, {
      cardId,
      action: "create",
      status: "applied",
      sourceType: "user",
      actorUid: uid,
      patch: cardData,
      revisionId: revisionRef.id,
      createdAt: now,
      appliedAt: now,
    });
  });

  return {
    cardId,
    version: 1,
    revisionId: revisionRef.id,
    requestId: requestRef.id,
  };
});

/**
 * 카드 수정 내용을 즉시 반영하고 revision 히스토리를 남긴다.
 */
exports.applyCardEdit = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  const data = request.data || {};
  const cardId = asIdString(data.cardId);
  const baseVersion = asOptionalNumber(data.baseVersion);
  const patch = normalizeCardPatch(data.patch || {}, false);

  if (!cardId) {
    throw new HttpsError("invalid-argument", "cardId는 필수입니다.");
  }
  if (Object.keys(patch).length === 0) {
    throw new HttpsError("invalid-argument", "수정할 항목이 없습니다.");
  }

  const productRef = cardCatalogRef().collection("cardProducts").doc(cardId);
  const requestRef = cardCatalogRef().collection("cardChangeRequests").doc();
  const revisionRef = productRef.collection("revisions").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  return admin.firestore().runTransaction(async (transaction) => {
    const productDoc = await transaction.get(productRef);
    if (!productDoc.exists) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }

    const current = productDoc.data() || {};
    const currentVersion = Number(current.version || 0);
    if (baseVersion !== null && baseVersion !== currentVersion) {
      throw new HttpsError(
          "aborted",
          "다른 사용자가 먼저 수정했습니다. 새로고침 후 다시 시도해주세요.",
      );
    }

    const next = applyCardPatchToObject(current, patch);
    const changeSet = [];
    for (const [field, value] of Object.entries(patch)) {
      changeSet.push(...diffCardValues(current[field], value, field));
    }
    const effectiveChangeSet = changeSet.filter((change) => change.path);
    if (effectiveChangeSet.length === 0) {
      return {
        cardId,
        version: currentVersion,
        noChanges: true,
      };
    }

    const nextVersion = currentVersion + 1;
    const updatePayload = {
      ...patch,
      version: nextVersion,
      updatedAt: now,
      updatedByUid: uid,
    };
    const snapshotBefore = cardRevisionSnapshot(current);
    const snapshotAfter = cardRevisionSnapshot({
      ...next,
      version: nextVersion,
      updatedByUid: uid,
    });

    transaction.update(productRef, updatePayload);
    transaction.set(revisionRef, {
      cardId,
      action: "edit",
      status: "applied",
      sourceType: "user",
      actorUid: uid,
      versionFrom: currentVersion,
      versionTo: nextVersion,
      changedFields: effectiveChangeSet.map((change) => change.path),
      changeSet: effectiveChangeSet,
      snapshotBefore,
      snapshotAfter,
      createdAt: now,
    });
    transaction.set(requestRef, {
      cardId,
      action: "edit",
      status: "applied",
      sourceType: "user",
      actorUid: uid,
      baseVersion: currentVersion,
      patch,
      revisionId: revisionRef.id,
      createdAt: now,
      appliedAt: now,
    });

    return {
      cardId,
      version: nextVersion,
      revisionId: revisionRef.id,
      requestId: requestRef.id,
      noChanges: false,
    };
  });
});

/**
 * 관리자가 특정 revision 이전 상태로 카드를 롤백한다.
 */
exports.rollbackCardRevision = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);

  const data = request.data || {};
  const cardId = asIdString(data.cardId);
  const revisionId = asIdString(data.revisionId);
  if (!cardId || !revisionId) {
    throw new HttpsError(
        "invalid-argument",
        "cardId와 revisionId는 필수입니다.",
    );
  }

  const productRef = cardCatalogRef().collection("cardProducts").doc(cardId);
  const targetRevisionRef = productRef.collection("revisions").doc(revisionId);
  const rollbackRevisionRef = productRef.collection("revisions").doc();
  const requestRef = cardCatalogRef().collection("cardChangeRequests").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  return admin.firestore().runTransaction(async (transaction) => {
    const productDoc = await transaction.get(productRef);
    const revisionDoc = await transaction.get(targetRevisionRef);

    if (!productDoc.exists) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }
    if (!revisionDoc.exists) {
      throw new HttpsError("not-found", "수정 이력을 찾을 수 없습니다.");
    }

    const current = productDoc.data() || {};
    const revision = revisionDoc.data() || {};
    const snapshotBefore = revision.snapshotBefore;
    if (!isPlainObject(snapshotBefore)) {
      throw new HttpsError(
          "failed-precondition",
          "이 revision은 롤백할 이전 스냅샷이 없습니다.",
      );
    }

    const currentVersion = Number(current.version || 0);
    const nextVersion = currentVersion + 1;
    const restored = {
      ...snapshotBefore,
      version: nextVersion,
      updatedAt: now,
      updatedByUid: uid,
    };
    if (!restored.createdAt && current.createdAt) {
      restored.createdAt = current.createdAt;
    }
    if (!restored.createdByUid && current.createdByUid) {
      restored.createdByUid = current.createdByUid;
    }

    const changeSet = diffCardValues(
        cardRevisionSnapshot(current),
        cardRevisionSnapshot({
          ...restored,
          updatedAt: current.updatedAt,
        }),
    ).filter((change) =>
      change.path &&
      change.path !== "updatedAt" &&
      change.path !== "updatedByUid" &&
      change.path !== "version",
    );

    transaction.set(productRef, restored);
    transaction.set(rollbackRevisionRef, {
      cardId,
      action: "rollback",
      status: "applied",
      sourceType: "admin",
      actorUid: uid,
      versionFrom: currentVersion,
      versionTo: nextVersion,
      rollbackOfRevisionId: revisionId,
      changedFields: changeSet.map((change) => change.path),
      changeSet,
      snapshotBefore: cardRevisionSnapshot(current),
      snapshotAfter: cardRevisionSnapshot({
        ...snapshotBefore,
        version: nextVersion,
        updatedByUid: uid,
      }),
      createdAt: now,
    });
    transaction.set(requestRef, {
      cardId,
      action: "rollback",
      status: "applied",
      sourceType: "admin",
      actorUid: uid,
      rollbackOfRevisionId: revisionId,
      revisionId: rollbackRevisionRef.id,
      createdAt: now,
      appliedAt: now,
    });

    return {
      cardId,
      version: nextVersion,
      revisionId: rollbackRevisionRef.id,
      requestId: requestRef.id,
    };
  });
});

/**
 * 사용자가 앱 안에서 요청할 수 있는 카드 후보를 검색한다.
 */
exports.searchCardSourceCandidates = onCall({
  region: CARD_REGION,
  timeoutSeconds: 120,
  memory: "512MiB",
}, async (request) => {
  requireAuthUid(request);
  const query = asOptionalString((request.data || {}).query) || "";
  const limit = Math.min(
      30,
      Math.max(1, asOptionalNumber((request.data || {}).limit) || 15),
  );
  if (normalizeCardSearchText(query).length < 2) {
    return {
      query,
      candidates: [],
    };
  }

  const items = await fetchCardSourceSearchItems();
  const candidates = items
      .map((item) => {
        const score = scoreCardSourceCandidate(query, item);
        return {item, score};
      })
      .filter(({score}) => score > 0)
      .sort((left, right) => {
        if (right.score !== left.score) {
          return right.score - left.score;
        }
        const leftIdx = Number(left.item.idx || left.item.no || 0);
        const rightIdx = Number(right.item.idx || right.item.no || 0);
        return rightIdx - leftIdx;
      })
      .slice(0, limit)
      .map(({item, score}) => normalizeCardSourceCandidate(item, score))
      .filter(Boolean);

  return {
    query,
    candidates,
  };
});

/**
 * 사용자가 카드 정보 가져오기 요청을 생성한다.
 */
exports.createCardSourceRequest = onCall({
  region: CARD_REGION,
  timeoutSeconds: 60,
}, async (request) => {
  const uid = requireAuthUid(request);
  const data = request.data || {};
  const sourceCardId = asIdString(data.sourceCardId);
  const query = asOptionalString(data.query) || "";
  if (!sourceCardId) {
    throw new HttpsError("invalid-argument", "카드를 선택해주세요.");
  }

  const response = await globalThis.fetch(
      `${CARD_GORILLA_API_BASE}/cards/${sourceCardId}`,
  );
  if (response.status === 404) {
    throw new HttpsError("not-found", "선택한 카드 정보를 찾을 수 없습니다.");
  }
  if (!response.ok) {
    throw new HttpsError("unavailable", "카드 정보를 확인하지 못했습니다.");
  }

  const source = await response.json();
  if (!source || !source.idx) {
    throw new HttpsError("not-found", "선택한 카드 정보를 찾을 수 없습니다.");
  }

  const candidate = normalizeCardSourceCandidate(source, 0);
  if (!candidate) {
    throw new HttpsError("invalid-argument", "카드 정보가 올바르지 않습니다.");
  }

  const cardId = `cg_${sourceCardId}`;
  const productDoc = await cardCatalogRef()
      .collection("cardProducts")
      .doc(cardId)
      .get();
  const requestRef = cardCatalogRef().collection("cardRequests").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  await requestRef.set({
    status: "pending",
    requesterUid: uid,
    query: query.slice(0, 200),
    candidate,
    existingCardId: productDoc.exists ? cardId : null,
    sourceType: "cardGorilla",
    sourceRefs: {
      cardGorilla: {
        idx: sourceCardId,
        apiUrl: `${CARD_GORILLA_API_BASE}/cards/${sourceCardId}`,
        detailUrl:
          `https://www.card-gorilla.com/card/detail/${sourceCardId}`,
      },
    },
    createdAt: now,
    updatedAt: now,
  });

  return {
    requestId: requestRef.id,
    status: "pending",
    existingCardId: productDoc.exists ? cardId : null,
  };
});

/**
 * 관리자가 카드 요청을 실제 카드 DB로 가져온다.
 */
exports.importRequestedCard = onCall({
  region: CARD_REGION,
  timeoutSeconds: 180,
  memory: "1GiB",
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);

  const requestId = asIdString((request.data || {}).requestId);
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId는 필수입니다.");
  }

  const requestRef = cardCatalogRef().collection("cardRequests").doc(requestId);
  const requestDoc = await requestRef.get();
  if (!requestDoc.exists) {
    throw new HttpsError("not-found", "카드 요청을 찾을 수 없습니다.");
  }
  const requestData = requestDoc.data() || {};
  if (requestData.status === "imported" && requestData.importedCardId) {
    return {
      requestId,
      cardId: requestData.importedCardId,
      alreadyImported: true,
    };
  }

  const sourceRefs = requestData.sourceRefs || {};
  const sourceCardId = asIdString(
      sourceRefs.cardGorilla && sourceRefs.cardGorilla.idx,
  ) || asIdString(requestData.candidate && requestData.candidate.sourceCardId);
  if (!sourceCardId) {
    throw new HttpsError(
        "failed-precondition",
        "요청에 가져올 카드 정보가 없습니다.",
    );
  }

  const runRef = cardCatalogRef().collection("cardImportRuns").doc();
  const runId = runRef.id;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await runRef.set({
    sourceType: "cardGorilla",
    status: "running",
    mode: "request",
    requestId,
    sourceCardId,
    actorUid: uid,
    startedAt: now,
  });

  try {
    const issuerNameByIdx = await syncCardGorillaIssuers();
    const response = await globalThis.fetch(
        `${CARD_GORILLA_API_BASE}/cards/${sourceCardId}`,
    );
    if (response.status === 404) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }
    if (!response.ok) {
      throw new HttpsError("unavailable", "카드 정보를 가져오지 못했습니다.");
    }

    const source = await response.json();
    if (!source || !source.idx) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }

    const cardId = await upsertCardGorillaProduct({
      uid,
      runId,
      source,
      issuerNameByIdx,
    });

    await runRef.update({
      status: "completed",
      importedCardIds: [cardId],
      counts: {
        requested: 1,
        success: 1,
        notFound: 0,
        failed: 0,
      },
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await requestRef.update({
      status: "imported",
      importedCardId: cardId,
      reviewedByUid: uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      importRunId: runId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      requestId,
      cardId,
      runId,
      alreadyImported: false,
    };
  } catch (error) {
    await runRef.update({
      status: "failed",
      error: error.message,
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.error("Requested card import failed", {
      requestId,
      sourceCardId,
      message: error.message,
    });
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "카드 요청 처리에 실패했습니다.");
  }
});

/**
 * 관리자가 카드 요청을 반려한다.
 */
exports.rejectCardSourceRequest = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);

  const requestId = asIdString((request.data || {}).requestId);
  const note = asOptionalString((request.data || {}).note);
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId는 필수입니다.");
  }

  const requestRef = cardCatalogRef().collection("cardRequests").doc(requestId);
  const requestDoc = await requestRef.get();
  if (!requestDoc.exists) {
    throw new HttpsError("not-found", "카드 요청을 찾을 수 없습니다.");
  }

  await requestRef.update({
    status: "rejected",
    reviewedByUid: uid,
    reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    reviewNote: note,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    requestId,
    status: "rejected",
  };
});

/**
 * 카드 상세 댓글/대댓글을 추가한다.
 */
exports.addCardProductComment = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  const data = request.data || {};
  const cardId = asIdString(data.cardId);
  const parentCommentId = asIdString(data.parentCommentId);
  const body = requireCardText(data.body, "댓글");

  if (!cardId) {
    throw new HttpsError("invalid-argument", "cardId는 필수입니다.");
  }

  const productRef = cardCatalogRef().collection("cardProducts").doc(cardId);
  const commentsRef = productRef.collection("comments");
  const commentRef = commentsRef.doc();
  const parentRef = parentCommentId ? commentsRef.doc(parentCommentId) : null;
  const userRef = admin.firestore().collection("users").doc(uid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  await admin.firestore().runTransaction(async (transaction) => {
    const productDoc = await transaction.get(productRef);
    if (!productDoc.exists) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }

    let parentData = null;
    if (parentRef) {
      const parentDoc = await transaction.get(parentRef);
      if (!parentDoc.exists || parentDoc.data().isDeleted === true) {
        throw new HttpsError("not-found", "원댓글을 찾을 수 없습니다.");
      }
      parentData = parentDoc.data() || {};
      if (parentData.parentCommentId) {
        throw new HttpsError(
            "invalid-argument",
            "대댓글에는 답글을 달 수 없습니다.",
        );
      }
    }

    const userDoc = await transaction.get(userRef);
    const userData = userDoc.data() || {};
    const isAdmin = hasAdminRole(userData.roles);
    const displayName =
      asOptionalString(userData.displayName) ||
      asOptionalString(request.auth.token && request.auth.token.name) ||
      "익명";

    transaction.set(commentRef, {
      cardId,
      parentCommentId: parentCommentId || null,
      body: body.slice(0, 2000),
      author: {
        uid,
        displayName,
        photoURL: asOptionalString(userData.photoURL) ||
          asOptionalString(request.auth.token && request.auth.token.picture),
        displayGrade: isAdmin ?
          "★★★" :
          asOptionalString(userData.displayGrade) || "이코노미 Lv.1",
        isAdmin,
      },
      replyCount: 0,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    });

    transaction.update(productRef, {
      commentsCount: admin.firestore.FieldValue.increment(1),
      lastCommentAt: now,
    });

    if (parentRef) {
      transaction.update(parentRef, {
        replyCount: admin.firestore.FieldValue.increment(1),
        updatedAt: now,
      });
    }
  });

  return {
    cardId,
    commentId: commentRef.id,
    parentCommentId: parentCommentId || null,
  };
});

/**
 * 카드 상세 좋아요를 토글한다.
 */
exports.toggleCardProductLike = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  const cardId = asIdString((request.data || {}).cardId);
  if (!cardId) {
    throw new HttpsError("invalid-argument", "cardId는 필수입니다.");
  }

  const productRef = cardCatalogRef().collection("cardProducts").doc(cardId);
  const likeRef = productRef.collection("likes").doc(uid);
  const userRef = admin.firestore().collection("users").doc(uid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  return admin.firestore().runTransaction(async (transaction) => {
    const productDoc = await transaction.get(productRef);
    if (!productDoc.exists) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }

    const likeDoc = await transaction.get(likeRef);
    const currentLikes = Math.max(0, Number(
        (productDoc.data() || {}).likesCount || 0,
    ));

    if (likeDoc.exists) {
      const nextLikes = Math.max(0, currentLikes - 1);
      transaction.delete(likeRef);
      transaction.update(productRef, {
        likesCount: nextLikes,
        updatedLikeAt: now,
      });
      return {
        cardId,
        liked: false,
        likesCount: nextLikes,
      };
    }

    const userDoc = await transaction.get(userRef);
    const userData = userDoc.data() || {};
    const isAdmin = hasAdminRole(userData.roles);
    const nextLikes = currentLikes + 1;
    transaction.set(likeRef, {
      cardId,
      uid,
      author: {
        uid,
        displayName: asOptionalString(userData.displayName) || "익명",
        photoURL: asOptionalString(userData.photoURL),
        displayGrade: isAdmin ?
          "★★★" :
          asOptionalString(userData.displayGrade) || "이코노미 Lv.1",
        isAdmin,
      },
      createdAt: now,
    });
    transaction.update(productRef, {
      likesCount: nextLikes,
      updatedLikeAt: now,
    });

    return {
      cardId,
      liked: true,
      likesCount: nextLikes,
    };
  });
});

/**
 * 카드 상세 조회수를 1 증가시킨다.
 */
exports.incrementCardProductView = onCall({
  region: CARD_REGION,
}, async (request) => {
  const cardId = asIdString((request.data || {}).cardId);
  if (!cardId) {
    throw new HttpsError("invalid-argument", "cardId는 필수입니다.");
  }

  const productRef = cardCatalogRef().collection("cardProducts").doc(cardId);
  const now = admin.firestore.FieldValue.serverTimestamp();
  const uid = request.auth && request.auth.uid ? request.auth.uid : null;

  return admin.firestore().runTransaction(async (transaction) => {
    const productDoc = await transaction.get(productRef);
    if (!productDoc.exists) {
      throw new HttpsError("not-found", "카드 정보를 찾을 수 없습니다.");
    }

    const currentViews = Math.max(0, Number(
        (productDoc.data() || {}).viewsCount || 0,
    ));
    const nextViews = currentViews + 1;
    transaction.update(productRef, {
      viewsCount: nextViews,
      lastViewedAt: now,
    });

    if (uid) {
      transaction.set(
          productRef.collection("views").doc(uid),
          {
            uid,
            viewedAt: now,
            viewCount: admin.firestore.FieldValue.increment(1),
          },
          {merge: true},
      );
    }

    return {
      cardId,
      viewsCount: nextViews,
    };
  });
});

/**
 * 관리자가 카드고릴라 카드 데이터를 배치로 수집한다.
 */
exports.importCardGorillaCards = onCall({
  region: CARD_REGION,
  timeoutSeconds: 540,
  memory: "1GiB",
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);

  const data = request.data || {};
  const startId = Math.max(1, asOptionalNumber(data.startId) || 1);
  const endId = Math.max(1, asOptionalNumber(data.endId) || startId + 24);
  if (endId < startId) {
    throw new HttpsError(
        "invalid-argument",
        "endId는 startId보다 크거나 같아야 합니다.",
    );
  }
  if (endId > CARD_GORILLA_MAX_IMPORT_ID) {
    throw new HttpsError(
        "invalid-argument",
        `endId는 ${CARD_GORILLA_MAX_IMPORT_ID} 이하로 입력해주세요.`,
    );
  }
  if (endId - startId + 1 > 50) {
    throw new HttpsError(
        "invalid-argument",
        "한 번에 최대 50개까지 수집할 수 있습니다.",
    );
  }

  const runRef = cardCatalogRef().collection("cardImportRuns").doc();
  const runId = runRef.id;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const counts = {
    requested: endId - startId + 1,
    success: 0,
    notFound: 0,
    failed: 0,
  };
  const importedCardIds = [];
  const errors = [];

  await runRef.set({
    sourceType: "cardGorilla",
    status: "running",
    startId,
    endId,
    actorUid: uid,
    counts,
    startedAt: now,
  });

  try {
    const issuerNameByIdx = await syncCardGorillaIssuers();

    for (let id = startId; id <= endId; id++) {
      const apiUrl = `${CARD_GORILLA_API_BASE}/cards/${id}`;
      try {
        const response = await globalThis.fetch(apiUrl);
        if (response.status === 404) {
          counts.notFound += 1;
          continue;
        }
        if (!response.ok) {
          counts.failed += 1;
          errors.push({id, status: response.status});
          continue;
        }

        const source = await response.json();
        if (!source || !source.idx) {
          counts.notFound += 1;
          continue;
        }

        const cardId = await upsertCardGorillaProduct({
          uid,
          runId,
          source,
          issuerNameByIdx,
        });
        importedCardIds.push(cardId);
        counts.success += 1;
      } catch (error) {
        counts.failed += 1;
        errors.push({id, message: error.message});
        logger.warn("CardGorilla card import failed", {
          id,
          message: error.message,
        });
      }
    }

    await runRef.update({
      status: "completed",
      counts,
      importedCardIds,
      errors: errors.slice(0, 50),
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      runId,
      startId,
      endId,
      counts,
      importedCardIds,
      errors: errors.slice(0, 10),
    };
  } catch (error) {
    await runRef.update({
      status: "failed",
      counts,
      error: error.message,
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.error("CardGorilla import failed", error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError("internal", "카드 정보 수집에 실패했습니다.");
  }
});

/**
 * 네이버 OAuth 콜백을 앱 딥링크로 전달하는 브리지
 * Naver Console Callback URL에 이 함수 URL을 등록한다.
 */
exports.naverOauthBridge = onRequest(
    {region: OAUTH_REGION},
    (request, response) => {
      const query = request.query || {};
      const hasCode = Boolean(asOptionalString(query.code));
      const hasState = Boolean(asOptionalString(query.state));
      const error = asOptionalString(query.error);
      logger.info("naverOauthBridge callback received", {
        hasCode,
        hasState,
        error: error || null,
      });

      const redirectUrl = buildNaverAppCallback(query);
      response.set("Cache-Control", "no-store");
      response.redirect(302, redirectUrl);
    },
);

/**
 * 카카오 OAuth 콜백을 앱 딥링크로 전달하는 브리지
 * Kakao Console Redirect URI에 이 함수 URL을 등록한다.
 */
exports.kakaoOauthBridge = onRequest(
    {region: OAUTH_REGION},
    (request, response) => {
      const query = request.query || {};
      const hasCode = Boolean(asOptionalString(query.code));
      const hasState = Boolean(asOptionalString(query.state));
      const error = asOptionalString(query.error);
      logger.info("kakaoOauthBridge callback received", {
        hasCode,
        hasState,
        error: error || null,
      });

      const redirectUrl = buildOauthAppCallback("kakao", query);
      response.set("Cache-Control", "no-store");
      response.redirect(302, redirectUrl);
    },
);

/**
 * 네이버 OAuth code를 Firebase Custom Token으로 교환
 */
exports.createNaverCustomToken = onCall({
  region: OAUTH_REGION,
  secrets: [NAVER_CLIENT_ID, NAVER_CLIENT_SECRET],
}, async (request) => {
  const data = request.data || {};
  const code = asOptionalString(data.code) || "";
  const state = asOptionalString(data.state) || "";
  const redirectUri = asOptionalString(data.redirectUri) || "";

  if (!code || !state || !redirectUri) {
    throw new HttpsError(
        "invalid-argument",
        "code/state/redirectUri는 필수입니다.",
    );
  }

  try {
    const tokenUrl = new URL("https://nid.naver.com/oauth2.0/token");
    tokenUrl.searchParams.set("grant_type", "authorization_code");
    tokenUrl.searchParams.set("client_id", NAVER_CLIENT_ID.value());
    tokenUrl.searchParams.set("client_secret", NAVER_CLIENT_SECRET.value());
    tokenUrl.searchParams.set("code", code);
    tokenUrl.searchParams.set("state", state);
    tokenUrl.searchParams.set("redirect_uri", redirectUri);

    const tokenResponse = await globalThis.fetch(tokenUrl, {
      method: "GET",
      headers: {
        "Accept": "application/json",
      },
    });

    const tokenPayload = await tokenResponse.json();
    const accessToken = asOptionalString(tokenPayload.access_token) || "";

    if (!tokenResponse.ok || !accessToken) {
      logger.error("Naver token exchange failed", {
        status: tokenResponse.status,
        tokenPayload,
      });
      throw new HttpsError("internal", "네이버 토큰 발급에 실패했습니다.");
    }

    const profileResponse = await globalThis.fetch(
        "https://openapi.naver.com/v1/nid/me",
        {
          method: "GET",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Accept": "application/json",
          },
        },
    );

    const profilePayload = await profileResponse.json();
    const profileResponseBody =
      profilePayload && typeof profilePayload === "object" ?
        profilePayload.response || {} :
        {};
    const normalizedProfile = normalizeNaverProfile(profileResponseBody);
    const providerUid = normalizedProfile.id;

    if (!profileResponse.ok || !providerUid) {
      logger.error("Naver profile lookup failed", {
        status: profileResponse.status,
        profilePayload,
      });
      throw new HttpsError("internal", "네이버 프로필 조회에 실패했습니다.");
    }

    const firebaseUid = `naver:${providerUid}`;
    const firebaseToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: "naver",
      providerUid,
    });

    return {
      firebaseToken,
      provider: "naver",
      providerUid,
      providerProfile: normalizedProfile,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("createNaverCustomToken unexpected error", error);
    throw new HttpsError("internal", "네이버 로그인 처리 중 오류가 발생했습니다.");
  }
});

/**
 * 카카오 OAuth code를 Firebase Custom Token으로 교환
 */
exports.createKakaoCustomToken = onCall({
  region: OAUTH_REGION,
  secrets: [KAKAO_REST_API_KEY, KAKAO_CLIENT_SECRET],
}, async (request) => {
  const data = request.data || {};
  const code = asOptionalString(data.code) || "";
  const state = asOptionalString(data.state) || "";
  const redirectUri = asOptionalString(data.redirectUri) || "";

  if (!code || !state || !redirectUri) {
    throw new HttpsError(
        "invalid-argument",
        "code/state/redirectUri는 필수입니다.",
    );
  }

  try {
    const tokenBody = new URLSearchParams();
    tokenBody.set("grant_type", "authorization_code");
    tokenBody.set("client_id", KAKAO_REST_API_KEY.value());
    tokenBody.set("client_secret", KAKAO_CLIENT_SECRET.value());
    tokenBody.set("redirect_uri", redirectUri);
    tokenBody.set("code", code);

    const tokenResponse = await globalThis.fetch(
        "https://kauth.kakao.com/oauth/token",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
            "Accept": "application/json",
          },
          body: tokenBody.toString(),
        },
    );

    const tokenPayload = await tokenResponse.json();
    const accessToken = asOptionalString(tokenPayload.access_token) || "";

    if (!tokenResponse.ok || !accessToken) {
      logger.error("Kakao token exchange failed", {
        status: tokenResponse.status,
        tokenPayload,
      });
      throw new HttpsError("internal", "카카오 토큰 발급에 실패했습니다.");
    }

    const profileResponse = await globalThis.fetch(
        "https://kapi.kakao.com/v2/user/me",
        {
          method: "GET",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Accept": "application/json",
          },
        },
    );

    const profilePayload = await profileResponse.json();
    const normalizedProfile = normalizeKakaoProfile(profilePayload || {});
    const providerUid = normalizedProfile.id;

    if (!profileResponse.ok || !providerUid) {
      logger.error("Kakao profile lookup failed", {
        status: profileResponse.status,
        profilePayload,
      });
      throw new HttpsError("internal", "카카오 프로필 조회에 실패했습니다.");
    }

    const firebaseUid = `kakao:${providerUid}`;
    const firebaseToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: "kakao",
      providerUid,
    });

    return {
      firebaseToken,
      provider: "kakao",
      providerUid,
      providerProfile: normalizedProfile,
    };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }

    logger.error("createKakaoCustomToken unexpected error", error);
    throw new HttpsError("internal", "카카오 로그인 처리 중 오류가 발생했습니다.");
  }
});

/**
 * 테스트용 함수 (배포 후 확인용)
 */
exports.helloWorld = onRequest((request, response) => {
  logger.info("Hello logs!", {structuredData: true});
  response.send("Hello from Firebase Functions!");
});
