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
const cheerio = require("cheerio");

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
const NOTIFICATION_PREF_KEYS = {
  communityPostLike: "community_post_like",
  communityPostComment: "community_post_comment",
  communityCommentReply: "community_comment_reply",
  communityCommentLike: "community_comment_like",
  radarAll: "radar_all",
  radarMileageSeat: "radar_mileage_seat",
  radarCancelAlert: "radar_cancel_alert",
  radarFlightDeal: "radar_flight_deal",
  radarGiftcard: "radar_giftcard",
  radarBenefitNews: "radar_benefit_news",
};
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
  "benefitCategoryIds",
  "mileagePrograms",
  "travelFlags",
  "loungeSummary",
  "eventSummary",
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

const SCRAP_ALLOWED_TAGS = new Set([
  "p",
  "br",
  "img",
  "video",
  "a",
  "strong",
  "em",
  "b",
  "i",
  "ul",
  "ol",
  "li",
  "blockquote",
  "h2",
  "h3",
  "h4",
]);
const SCRAP_NAVER = "naver_blog";
const SCRAP_AAGAG = "aagag_issue";

/**
 * 스크랩 sourceType을 서버 표준 값으로 정규화한다.
 * @param {unknown} value
 * @return {string|null}
 */
function normalizeScrapSourceValue(value) {
  const raw = asOptionalString(value);
  if (!raw) return null;
  const normalized = raw.toLowerCase().replace(/-/g, "_");
  if (normalized === "naver" || normalized === SCRAP_NAVER) {
    return SCRAP_NAVER;
  }
  if (
    normalized === "aagag" ||
    normalized === "aggag" ||
    normalized === SCRAP_AAGAG
  ) {
    return SCRAP_AAGAG;
  }
  return null;
}

/**
 * URL을 지원 소스에 맞게 검증하고 정규화한다.
 * @param {unknown} rawUrl
 * @param {unknown} rawSourceType
 * @return {{normalizedUrl: string, sourceType: string}}
 */
function normalizeScrapUrl(rawUrl, rawSourceType) {
  let value = asOptionalString(rawUrl);
  if (!value) {
    throw new HttpsError("invalid-argument", "URL을 입력해주세요.");
  }
  if (!/^https?:\/\//i.test(value)) {
    value = `https://${value}`;
  }

  let parsed;
  try {
    parsed = new URL(value);
  } catch (error) {
    throw new HttpsError("invalid-argument", "URL 형식이 올바르지 않습니다.");
  }

  parsed.protocol = "https:";
  parsed.hash = "";
  const host = parsed.hostname.toLowerCase().replace(/^www\./, "");
  let sourceType = normalizeScrapSourceValue(rawSourceType);

  if (host === "m.blog.naver.com" || host === "blog.naver.com") {
    if (sourceType && sourceType !== SCRAP_NAVER) {
      throw new HttpsError(
          "invalid-argument",
          "선택한 소스와 URL 도메인이 일치하지 않습니다.",
      );
    }
    sourceType = SCRAP_NAVER;
    const pathParts = parsed.pathname.split("/").filter((part) => part);
    let blogId = parsed.searchParams.get("blogId");
    let logNo = parsed.searchParams.get("logNo");
    if (!blogId && !logNo && pathParts.length >= 2) {
      blogId = decodeURIComponent(pathParts[0]);
      logNo = pathParts[1];
    }
    if (blogId && logNo) {
      parsed.hostname = "m.blog.naver.com";
      parsed.pathname = `/${encodeURIComponent(blogId)}/${logNo}`;
      parsed.search = "";
    }
  } else if (host === "aagag.com") {
    if (sourceType && sourceType !== SCRAP_AAGAG) {
      throw new HttpsError(
          "invalid-argument",
          "선택한 소스와 URL 도메인이 일치하지 않습니다.",
      );
    }
    sourceType = SCRAP_AAGAG;
    if (!parsed.pathname.startsWith("/issue")) {
      throw new HttpsError(
          "invalid-argument",
          "AAGAG 이슈 URL만 지원합니다.",
      );
    }
  } else {
    throw new HttpsError(
        "invalid-argument",
        "네이버 블로그 또는 AAGAG URL만 지원합니다.",
    );
  }

  if (!sourceType) {
    throw new HttpsError("invalid-argument", "지원하지 않는 스크랩 소스입니다.");
  }

  return {
    normalizedUrl: parsed.toString(),
    sourceType,
  };
}

/**
 * 스크랩 fetch 요청 헤더를 만든다.
 * @param {string} sourceType
 * @return {Record<string, string>}
 */
function scrapRequestHeaders(sourceType) {
  const headers = {
    "User-Agent": [
      "Mozilla/5.0 (Linux; Android 10; Mobile)",
      "AppleWebKit/537.36 (KHTML, like Gecko)",
      "Chrome/126.0.0.0 Mobile Safari/537.36",
    ].join(" "),
    "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
  };
  if (sourceType === SCRAP_NAVER) {
    headers.Referer = "https://m.blog.naver.com/";
  }
  if (sourceType === SCRAP_AAGAG) {
    headers.Referer = "https://aagag.com/";
  }
  return headers;
}

/**
 * 원격 HTML을 가져온다.
 * @param {string} url
 * @param {string} sourceType
 * @return {Promise<string>}
 */
async function fetchScrapHtml(url, sourceType) {
  const response = await globalThis.fetch(url, {
    headers: scrapRequestHeaders(sourceType),
  });
  if (!response.ok) {
    throw new HttpsError(
        "unavailable",
        `원문을 가져오지 못했습니다. (${response.status})`,
    );
  }
  return response.text();
}

/**
 * 네이버 데스크톱 프레임 URL이면 실제 본문 HTML을 추가로 가져온다.
 * @param {string} html
 * @param {string} url
 * @param {string} sourceType
 * @return {Promise<string>}
 */
async function resolveScrapHtmlForParsing(html, url, sourceType) {
  if (sourceType !== SCRAP_NAVER || html.includes("se-main-container")) {
    return html;
  }
  const redirectMatch = html.match(
      /top\.location\.replace\(['"]([^'"]+)['"]\)/,
  );
  if (redirectMatch) {
    const redirectUrl = redirectMatch[1].replace(/\\\//g, "/");
    return fetchScrapHtml(new URL(redirectUrl, url).toString(), sourceType);
  }
  const $ = cheerio.load(html);
  const frameSrc = $("iframe#mainFrame").attr("src");
  if (!frameSrc) return html;
  const frameUrl = new URL(frameSrc, url).toString();
  return fetchScrapHtml(frameUrl, sourceType);
}

/**
 * 텍스트를 공백 정리해서 가져온다.
 * @param {unknown} value
 * @return {string}
 */
function cleanScrapText(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

/**
 * HTML attribute/text 출력용 escape.
 * @param {string} value
 * @return {string}
 */
function escapeScrapHtml(value) {
  return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
}

/**
 * 안전한 http(s) URL만 반환한다.
 * @param {unknown} value
 * @param {string|null} baseUrl
 * @return {string}
 */
function safeScrapUrl(value, baseUrl = null) {
  const raw = asOptionalString(value);
  if (!raw) return "";
  try {
    const parsed = baseUrl ? new URL(raw, baseUrl) : new URL(raw);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return "";
    }
    parsed.hash = "";
    return parsed.toString();
  } catch (error) {
    return "";
  }
}

/**
 * 스크랩 본문 HTML을 Flutter 렌더링에 맞는 최소 태그로 정리한다.
 * @param {string} html
 * @param {string} baseUrl
 * @return {string}
 */
function sanitizeScrapHtml(html, baseUrl) {
  if (!html) return "";
  const $ = cheerio.load(`<div id="scrap-root">${html}</div>`, {
    decodeEntities: false,
  });
  const $root = $("#scrap-root");

  $root.find("script, style").remove();
  $root.contents().filter((index, node) => node.type === "comment").remove();
  $root.find("*").contents()
      .filter((index, node) => node.type === "comment")
      .remove();

  for (const node of $root.find("*").toArray()) {
    const tagName = String(node.tagName || "").toLowerCase();
    if (!SCRAP_ALLOWED_TAGS.has(tagName)) {
      $(node).replaceWith($(node).contents());
    }
  }

  for (const node of $root.find("*").toArray()) {
    const tagName = String(node.tagName || "").toLowerCase();
    const $node = $(node);

    if (tagName === "a") {
      const href = safeScrapUrl($node.attr("href"), baseUrl);
      if (!href) {
        $node.replaceWith($node.contents());
        continue;
      }
      const title = cleanScrapText($node.attr("title"));
      $node.attr({});
      $node.attr("href", href);
      if (title) $node.attr("title", title.slice(0, 200));
      continue;
    }

    if (tagName === "img") {
      const src = safeScrapUrl($node.attr("src"), baseUrl);
      if (!src) {
        $node.remove();
        continue;
      }
      const alt = cleanScrapText($node.attr("alt"));
      $node.attr({});
      $node.attr("src", src);
      if (alt) $node.attr("alt", alt.slice(0, 200));
      continue;
    }

    if (tagName === "video") {
      const src = safeScrapUrl(
          $node.attr("src") || $node.find("source").first().attr("src"),
          baseUrl,
      );
      if (!src) {
        $node.remove();
        continue;
      }
      const poster = safeScrapUrl($node.attr("poster"), baseUrl);
      $node.attr({});
      $node.attr("src", src);
      if (poster) $node.attr("poster", poster);
      continue;
    }

    $node.attr({});
  }

  $root.find("p").each((index, node) => {
    const $node = $(node);
    if (
      !cleanScrapText($node.text()) &&
      $node.find("img, video").length === 0
    ) {
      $node.remove();
    }
  });

  return ($root.html() || "").trim();
}

/**
 * 네이버 블로그 HTML을 게시글 데이터로 파싱한다.
 * @param {string} html
 * @param {string} sourceUrl
 * @return {Object}
 */
function parseNaverBlogScrap(html, sourceUrl) {
  const $ = cheerio.load(html, {decodeEntities: false});
  let title = cleanScrapText($(".se-title-text .se-text-paragraph span")
      .first()
      .text());
  if (!title) {
    title = cleanScrapText($("meta[property='og:title']").attr("content"));
  }
  const scrapedAuthor = cleanScrapText($(".blog_author .ell").first().text());
  const scrapedAuthorFallback = cleanScrapText($(".writer .nick a")
      .first()
      .text());
  const scrapedDateText = cleanScrapText(
      $(".blog_date, .se_publishDate").first().text(),
  );
  let contentHtml = $(".se-main-container").first().html() || "";
  if (!contentHtml) {
    contentHtml = $("article, #postViewArea, .se_component_wrap")
        .first()
        .html() || "";
  }

  const content$ = cheerio.load(contentHtml, {decodeEntities: false}, false);
  content$("img").each((index, img) => {
    const $img = content$(img);
    let src = $img.attr("data-lazy-src") ||
      $img.attr("data-src") ||
      $img.attr("src") ||
      "";
    const $parent = $img.parent("[data-linkdata]");
    if (!src && $parent.length > 0) {
      try {
        const raw = String($parent.attr("data-linkdata") || "")
            .replace(/&quot;/g, "\"");
        const data = JSON.parse(raw);
        src = data.src || "";
      } catch (error) {
        src = "";
      }
    }
    src = safeScrapUrl(src, sourceUrl);
    if (src) $img.attr("src", src);
    if (($img.attr("alt") || "") === "") $img.removeAttr("alt");
  });
  content$("video").each((index, video) => {
    const $video = content$(video);
    const src = safeScrapUrl(
        $video.attr("src") ||
          $video.find("source").first().attr("src") ||
          $video.attr("data-gif-url"),
        sourceUrl,
    );
    const poster = safeScrapUrl($video.attr("poster"), sourceUrl);
    if (src) $video.attr("src", src);
    if (poster) $video.attr("poster", poster);
  });

  const sanitized = sanitizeScrapHtml(content$.root().html() || "", sourceUrl);
  return {
    sourceType: SCRAP_NAVER,
    title,
    scrapedAuthor: scrapedAuthor || scrapedAuthorFallback,
    scrapedDateText,
    contentHtml: sanitized,
  };
}

/**
 * AAGAG media id를 HTML에 넣어도 되는 짧은 토큰으로 제한한다.
 * @param {unknown} value
 * @return {string}
 */
function safeAagagMediaId(value) {
  const raw = asOptionalString(value);
  return raw && /^[A-Za-z0-9_-]+$/.test(raw) ? raw : "";
}

/**
 * AAGAG [sTag] payload가 mp4 렌더링 대상인지 확인한다.
 * @param {Object} data
 * @return {boolean}
 */
function isAagagVideoPayload(data) {
  return Boolean(
      data.mp4_byte ||
      data.mp4_seq ||
      data.mp4_width ||
      data.mp4_height ||
      data.codec ||
      data.audio,
  );
}

/**
 * AAGAG [sTag] 미디어 payload를 Flutter HTML 태그로 바꾼다.
 * @param {string} text
 * @return {string}
 */
function replaceAagagSTags(text) {
  return String(text || "").replace(
      /\[sTag\]\s*(\{[\s\S]*?\})\s*\[\/sTag\]/g,
      (match, payload) => {
        try {
          const data = JSON.parse(payload);
          const mediaId = safeAagagMediaId(data.q);
          if (data.m !== "img" || !mediaId) {
            return "";
          }
          if (isAagagVideoPayload(data)) {
            return [
              `<video src="https://i.aagag.com/${mediaId}.mp4" `,
              `poster="https://i.aagag.com/o/${mediaId}.jpg"></video>`,
            ].join("");
          }
          return `<img src="https://i.aagag.com/o/${mediaId}.webp">`;
        } catch (error) {
          return "";
        }
      },
  );
}

/**
 * AAGAG 이슈 HTML을 게시글 데이터로 파싱한다.
 * @param {string} html
 * @param {string} sourceUrl
 * @return {Object}
 */
function parseAagagScrap(html, sourceUrl) {
  const $ = cheerio.load(html, {decodeEntities: false});
  let title = cleanScrapText($("h1.title").first().text());
  if (!title) {
    title = cleanScrapText($("meta[property='og:title']").attr("content"));
  }
  const scrapedAuthor = cleanScrapText($("#top_menu .member").first().text());
  let scrapedDateText = cleanScrapText($(".taa_other_info .odate")
      .first()
      .text());
  if (!scrapedDateText) {
    scrapedDateText = cleanScrapText(
        $("meta[property='og:article:published_time']").attr("content"),
    );
  }
  let contentHtml = $("#vContent").first().html() || "";

  if (!contentHtml || !contentHtml.includes("<img")) {
    for (const script of $("script").toArray()) {
      const text = $(script).text() || "";
      const match = text.match(/AAGAG_AA\.content\s*=\s*"([\s\S]*?)";/);
      if (!match) continue;
      try {
        contentHtml = JSON.parse(`"${match[1]}"`);
      } catch (error) {
        contentHtml = match[1].replace(/\\"/g, "\"");
      }
      contentHtml = replaceAagagSTags(contentHtml);
      break;
    }
  }

  const sanitized = sanitizeScrapHtml(contentHtml, sourceUrl);
  return {
    sourceType: SCRAP_AAGAG,
    title,
    scrapedAuthor,
    scrapedDateText,
    contentHtml: sanitized,
  };
}

/**
 * 스크랩 본문 미디어 개수를 센다.
 * @param {string} html
 * @return {{images: number, videos: number, links: number}}
 */
function countScrapMedia(html) {
  const $ = cheerio.load(html || "", {decodeEntities: false}, false);
  return {
    images: $("img").length,
    videos: $("video").length,
    links: $("a").length,
  };
}

/**
 * 미리보기 HTML을 만든다.
 * @param {Object} parsed
 * @param {string} sourceUrl
 * @return {string}
 */
function buildScrapPreviewHtml(parsed, sourceUrl) {
  const meta = [parsed.scrapedAuthor, parsed.scrapedDateText]
      .filter((item) => item)
      .join(" · ");
  const escapedMeta = escapeScrapHtml(meta);
  const escapedSourceUrl = escapeScrapHtml(sourceUrl);
  const metaHtml = meta ?
    `<p style="margin:4px 0;color:#666;font-size:14px;">` +
      `${escapedMeta}</p>` :
    "";
  const sourceHtml = parsed.sourceType === SCRAP_NAVER ?
    `<p>출처: <a href="${escapedSourceUrl}">` +
      `${escapedSourceUrl}</a></p>` :
    "";
  return [
    "<article>",
    `<h1>${escapeScrapHtml(parsed.title)}</h1>`,
    metaHtml,
    `<section>${parsed.contentHtml}</section>`,
    sourceHtml,
    "</article>",
  ].join("");
}

/**
 * 게시글 발행용 HTML을 만든다.
 * @param {Object} parsed
 * @param {string} sourceUrl
 * @return {string}
 */
function buildScrapPublishHtml(parsed, sourceUrl) {
  if (parsed.sourceType !== SCRAP_NAVER) {
    return parsed.contentHtml;
  }
  return [
    "<p>네이버 블로그 스크랩한 게시글입니다.</p>",
    "<p>&nbsp;</p>",
    parsed.contentHtml,
    `<p>출처: <a href="${escapeScrapHtml(sourceUrl)}">`,
    `${escapeScrapHtml(sourceUrl)}</a></p>`,
  ].join("");
}

/**
 * collectionGroup 결과에서 게시글 경로 정보를 만든다.
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc
 * @return {Object}
 */
function scrapDuplicatePostFromDoc(doc) {
  const data = doc.data() || {};
  const dateString = doc.ref.parent.parent ? doc.ref.parent.parent.id : "";
  return {
    postId: data.postId || doc.id,
    postNumber: data.postNumber || "",
    dateString,
    boardId: data.boardId || "",
    title: data.title || "",
    postPath: `posts/${dateString}/posts/${data.postId || doc.id}`,
  };
}

/**
 * 스크랩 URL 중복 확인용 단일 문서 ref를 만든다.
 * @param {string} normalizedUrl
 * @return {FirebaseFirestore.DocumentReference}
 */
function scrapSourceRef(normalizedUrl) {
  const id = crypto.createHash("sha256").update(normalizedUrl).digest("hex");
  return admin.firestore().collection("scrap_source_urls").doc(id);
}

/**
 * 스크랩 URL ledger 문서를 duplicatePost 응답으로 바꾼다.
 * @param {Object} data
 * @return {Object}
 */
function scrapDuplicatePostFromLedger(data) {
  return {
    postId: data.postId || "",
    postNumber: data.postNumber || "",
    dateString: data.dateString || "",
    boardId: data.boardId || "",
    title: data.title || "",
    postPath: data.postPath || "",
  };
}

/**
 * Firestore collectionGroup 인덱스 누락 오류 여부.
 * @param {unknown} error
 * @return {boolean}
 */
function isScrapIndexPreconditionError(error) {
  const message = error && error.message ? String(error.message) : "";
  return error && (
    error.code === 9 ||
    message.includes("FAILED_PRECONDITION")
  );
}

/**
 * 스크랩 URL ledger가 실제 게시글을 가리키는지 확인한다.
 * @param {Object} duplicatePost
 * @return {Promise<boolean>}
 */
async function scrapDuplicatePostStillExists(duplicatePost) {
  if (!duplicatePost.postPath) {
    return true;
  }
  const postDoc = await admin.firestore().doc(duplicatePost.postPath).get();
  return postDoc.exists;
}

/**
 * 동일 sourceUrl로 이미 발행된 게시글을 찾는다.
 * @param {string} normalizedUrl
 * @return {Promise<Object|null>}
 */
async function findDuplicateScrapPost(normalizedUrl) {
  const db = admin.firestore();
  const ledgerDoc = await scrapSourceRef(normalizedUrl).get();
  if (ledgerDoc.exists) {
    const duplicatePost = scrapDuplicatePostFromLedger(ledgerDoc.data() || {});
    if (await scrapDuplicatePostStillExists(duplicatePost)) {
      return duplicatePost;
    }
    await ledgerDoc.ref.delete();
    logger.warn("실제 게시글이 없는 스크랩 URL ledger를 정리했습니다.", {
      sourceUrl: normalizedUrl,
      postPath: duplicatePost.postPath,
    });
  }

  try {
    const queries = [
      db.collectionGroup("posts")
          .where("sourceUrlNormalized", "==", normalizedUrl)
          .limit(3)
          .get(),
      db.collectionGroup("posts")
          .where("sourceUrl", "==", normalizedUrl)
          .limit(3)
          .get(),
    ];
    const snapshots = await Promise.all(queries);
    for (const snapshot of snapshots) {
      for (const doc of snapshot.docs) {
        const data = doc.data() || {};
        if (data.postId || data.sourceUrl || data.sourceUrlNormalized) {
          return scrapDuplicatePostFromDoc(doc);
        }
      }
    }
  } catch (error) {
    if (!isScrapIndexPreconditionError(error)) {
      throw error;
    }
    logger.warn("스크랩 기존 게시글 중복 조회 인덱스가 없어 건너뜁니다.", {
      code: error.code,
      message: error.message,
    });
  }
  return null;
}

/**
 * 원격 글을 fetch/parse/sanitize/중복검사까지 수행한다.
 * @param {unknown} rawUrl
 * @param {unknown} rawSourceType
 * @return {Promise<Object>}
 */
async function validateScrapPayload(rawUrl, rawSourceType) {
  const normalized = normalizeScrapUrl(rawUrl, rawSourceType);
  const fetchedHtml = await fetchScrapHtml(
      normalized.normalizedUrl,
      normalized.sourceType,
  );
  const html = await resolveScrapHtmlForParsing(
      fetchedHtml,
      normalized.normalizedUrl,
      normalized.sourceType,
  );
  const parsed = normalized.sourceType === SCRAP_AAGAG ?
    parseAagagScrap(html, normalized.normalizedUrl) :
    parseNaverBlogScrap(html, normalized.normalizedUrl);
  const warnings = [];
  if (!parsed.title) warnings.push("제목을 찾지 못했습니다.");
  if (!parsed.contentHtml) warnings.push("본문을 찾지 못했습니다.");
  const duplicatePost = await findDuplicateScrapPost(normalized.normalizedUrl);
  if (duplicatePost) warnings.push("이미 같은 URL로 발행된 게시글이 있습니다.");
  const mediaCounts = countScrapMedia(parsed.contentHtml);

  return {
    ok: true,
    canPublish: !duplicatePost && Boolean(parsed.title && parsed.contentHtml),
    sourceType: normalized.sourceType,
    normalizedUrl: normalized.normalizedUrl,
    title: parsed.title,
    scrapedAuthor: parsed.scrapedAuthor,
    scrapedDateText: parsed.scrapedDateText,
    contentHtml: parsed.contentHtml,
    previewHtml: buildScrapPreviewHtml(parsed, normalized.normalizedUrl),
    mediaCounts,
    warnings,
    duplicatePost,
  };
}

/**
 * Realtime Database 카테고리 목록을 읽는다.
 * @return {Promise<Array<unknown>>}
 */
async function loadScrapBoards() {
  const snapshot = await admin.database().ref("CATEGORIES").get();
  const raw = snapshot.val();
  return Array.isArray(raw) ? raw : Object.values(raw || {});
}

/**
 * Realtime Database 카테고리를 찾아 발행 가능 여부를 확인한다.
 * @param {string} boardId
 * @return {Promise<Object>}
 */
async function requireScrapBoard(boardId) {
  const entries = await loadScrapBoards();
  for (const entry of entries) {
    if (!entry || String(entry.id || "") !== boardId) continue;
    if (boardId === "seats") {
      throw new HttpsError(
          "invalid-argument",
          "오늘의 좌석 카테고리에는 스크랩 업로드를 할 수 없습니다.",
      );
    }
    return entry;
  }
  throw new HttpsError("invalid-argument", "카테고리를 찾을 수 없습니다.");
}

/**
 * 일반 사용자 스크랩 업로드에서 허용되는 카테고리인지 확인한다.
 * @param {string} boardId
 * @return {Promise<Object>}
 */
async function requireUserScrapBoard(boardId) {
  const entry = await requireScrapBoard(boardId);
  if (
    boardId === "notice" ||
    boardId === "milecatch_guide" ||
    entry.fabEnabled !== true
  ) {
    throw new HttpsError(
        "permission-denied",
        "이 카테고리에는 스크랩 업로드를 할 수 없습니다.",
    );
  }
  return entry;
}

/**
 * 한국 시간 기준 yyyyMMdd 파티션을 만든다.
 * @return {string}
 */
function koreaDateKey() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date()).replace(/-/g, "");
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
 * 카드 상세 댓글 본문 검증
 * @param {unknown} value
 * @return {string}
 */
function requireCardCommentBody(value) {
  const text = typeof value === "string" ? value.trim() : "";
  if (!text) {
    throw new HttpsError("invalid-argument", "댓글은 필수입니다.");
  }
  return text.slice(0, 2000);
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
  const benefitCategoryIds = inferCardBenefitCategoryIds(source, topBenefits);
  const mileagePrograms = inferMileagePrograms(source, topBenefits);
  const travelFlags = inferTravelFlags(source, topBenefits);
  const loungeSummary = inferLoungeSummary(source, topBenefits);
  const eventSummary = normalizeCardGorillaEventSummary(source.event);

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
    benefitCategoryIds,
    mileagePrograms,
    travelFlags,
    loungeSummary,
    eventSummary,
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
 * 카드 원문/혜택 텍스트를 하나의 검색 문자열로 합친다.
 * @param {Object} source
 * @param {Array<Object>} topBenefits
 * @return {string}
 */
function cardBenefitHaystack(source, topBenefits) {
  return [
    source.name,
    source.c_type,
    source.cate_txt,
    source.brand_txt,
    source.annual_fee_basic,
    source.annual_fee_detail,
    source.censorship_info,
    ...topBenefits.map((item) => `${item.title || ""} ${item.value || ""}`),
  ].join(" ").toLowerCase();
}

/**
 * 추천/차트용 혜택 카테고리 추론
 * @param {Object} source
 * @param {Array<Object>} topBenefits
 * @return {Array<string>}
 */
function inferCardBenefitCategoryIds(source, topBenefits) {
  const text = cardBenefitHaystack(source, topBenefits);
  const categories = new Set();
  const addIf = (id, words) => {
    if (words.some((word) => text.includes(word))) {
      categories.add(id);
    }
  };
  addIf("mileage", ["마일", "mileage", "skypass", "스카이패스", "아시아나"]);
  addIf("travel", ["여행", "트래블", "해외", "항공", "호텔", "면세"]);
  addIf("lounge", ["라운지", "lounge", "pp카드", "priority pass"]);
  addIf("pay", ["간편결제", "pay", "페이"]);
  addIf("shopping", ["쇼핑", "백화점", "마트", "쿠팡"]);
  addIf("food", ["음식", "푸드", "배달", "카페", "커피"]);
  addIf("telecom", ["통신", "휴대폰", "인터넷"]);
  addIf("transport", ["교통", "주유", "택시", "대중교통"]);
  addIf("subscription", ["구독", "스트리밍", "ott"]);
  addIf("giftcard", ["상품권", "상테크", "무실적", "실적"]);
  return Array.from(categories);
}

/**
 * 마일리지 프로그램명 추론
 * @param {Object} source
 * @param {Array<Object>} topBenefits
 * @return {Array<string>}
 */
function inferMileagePrograms(source, topBenefits) {
  const text = cardBenefitHaystack(source, topBenefits);
  const programs = new Set();
  if (text.includes("대한") || text.includes("skypass") ||
      text.includes("스카이패스")) {
    programs.add("대한항공");
  }
  if (text.includes("아시아나") || text.includes("asiana")) {
    programs.add("아시아나");
  }
  if (text.includes("마일") || text.includes("mileage")) {
    programs.add("항공마일리지");
  }
  return Array.from(programs);
}

/**
 * 여행 관련 플래그 추론
 * @param {Object} source
 * @param {Array<Object>} topBenefits
 * @return {Object}
 */
function inferTravelFlags(source, topBenefits) {
  const text = cardBenefitHaystack(source, topBenefits);
  return {
    overseas: /해외|foreign|global/.test(text),
    travel: /여행|트래블|travel|항공|호텔|면세/.test(text),
    lounge: /라운지|lounge|priority pass|pp카드/.test(text),
    noFxFee: /수수료\s*면제|해외.*수수료/.test(text),
    summary: [
      /해외|foreign|global/.test(text) ? "해외 이용" : "",
      /라운지|lounge|priority pass|pp카드/.test(text) ? "라운지" : "",
      /항공|마일|mileage/.test(text) ? "항공/마일" : "",
    ].filter(Boolean).join(" · "),
  };
}

/**
 * 라운지 요약 추론
 * @param {Object} source
 * @param {Array<Object>} topBenefits
 * @return {Object}
 */
function inferLoungeSummary(source, topBenefits) {
  const text = cardBenefitHaystack(source, topBenefits);
  if (!/라운지|lounge|priority pass|pp카드/.test(text)) {
    return {};
  }
  const visitMatch = text.match(/연\s*([0-9]+)\s*회/);
  return {
    summary: visitMatch ? `공항라운지 연 ${visitMatch[1]}회` : "공항라운지 혜택",
    annualVisits: visitMatch ? Number(visitMatch[1]) : null,
  };
}

/**
 * "최대 4.2만원" 같은 한국어 금액 문자열을 원 단위로 추정한다.
 * @param {string|null} value
 * @return {number}
 */
function extractKrwAmount(value) {
  const text = String(value || "").replace(/,/g, "");
  const man = text.match(/([0-9]+(?:\.[0-9]+)?)\s*만\s*원/);
  if (man) {
    return Math.round(Number(man[1]) * 10000);
  }
  const won = text.match(/([0-9]+)\s*원/);
  return won ? Number(won[1]) : 0;
}

/**
 * 카드고릴라 이벤트 요약
 * @param {Object|null|undefined} event
 * @return {Object}
 */
function normalizeCardGorillaEventSummary(event) {
  if (!event || typeof event !== "object") {
    return {};
  }
  const text = asOptionalString(event.card_detail_text) ||
    asOptionalString(event.subject) ||
    asOptionalString(event.title);
  const amount = extractKrwAmount(text);
  return {
    type: asOptionalString(event.type),
    title: asOptionalString(event.title),
    summary: text,
    cashbackKRW: amount,
    sourceEventId: asIdString(event.idx || event.eid),
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
 * 사용자 알림 설정 값 확인. 누락된 값은 기본 ON으로 처리한다.
 * @param {Record<string, unknown>} userData
 * @param {string} key
 * @return {boolean}
 */
function isNotificationPreferenceEnabled(userData, key) {
  const preferences = userData &&
    typeof userData.notificationPreferences === "object" &&
    userData.notificationPreferences !== null ?
      userData.notificationPreferences :
      {};
  return preferences[key] !== false;
}

/**
 * 커뮤니티 알림 type을 사용자 설정 key로 변환
 * @param {string} type
 * @return {string|null}
 */
function communityNotificationPreferenceKey(type) {
  switch (type) {
    case "post_like":
      return NOTIFICATION_PREF_KEYS.communityPostLike;
    case "post_comment":
      return NOTIFICATION_PREF_KEYS.communityPostComment;
    case "comment_reply":
      return NOTIFICATION_PREF_KEYS.communityCommentReply;
    case "comment_like":
      return NOTIFICATION_PREF_KEYS.communityCommentLike;
    default:
      return null;
  }
}

/**
 * 레이더 item type을 사용자 설정 key로 변환
 * @param {string} itemType
 * @return {string|null}
 */
function radarNotificationPreferenceKey(itemType) {
  switch (itemType) {
    case "mileageSeat":
      return NOTIFICATION_PREF_KEYS.radarMileageSeat;
    case "cancelAlert":
      return NOTIFICATION_PREF_KEYS.radarCancelAlert;
    case "flightDeal":
      return NOTIFICATION_PREF_KEYS.radarFlightDeal;
    case "giftcard":
      return NOTIFICATION_PREF_KEYS.radarGiftcard;
    case "benefitNews":
      return NOTIFICATION_PREF_KEYS.radarBenefitNews;
    default:
      return null;
  }
}

/**
 * 커뮤니티 FCM 발송 여부
 * @param {Record<string, unknown>} userData
 * @param {string} type
 * @return {boolean}
 */
function shouldSendCommunityPush(userData, type) {
  const key = communityNotificationPreferenceKey(type);
  return !key || isNotificationPreferenceEnabled(userData, key);
}

/**
 * 레이더 FCM 발송 여부
 * @param {Record<string, unknown>} userData
 * @param {string} itemType
 * @return {boolean}
 */
function shouldSendRadarPush(userData, itemType) {
  const key = radarNotificationPreferenceKey(itemType);
  return isNotificationPreferenceEnabled(
      userData,
      NOTIFICATION_PREF_KEYS.radarAll,
  ) && (!key || isNotificationPreferenceEnabled(userData, key));
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
  if (!fcmToken ||
      subscription.pushEnabled === false ||
      !shouldSendRadarPush(userData, item.itemType)) {
    logger.info(`레이더 알림 저장 완료, FCM 발송 생략: uid=${uid}`);
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
 * 스크랩 글을 커뮤니티 게시글로 발행한다.
 * @param {Object} params
 * @param {string} params.boardId
 * @param {string} params.authorUid
 * @param {string} params.publisherUid
 * @param {unknown} params.rawUrl
 * @param {unknown} params.rawSourceType
 * @param {string} params.titleOverride
 * @param {boolean} params.adminPublish
 * @return {Promise<Object>}
 */
async function publishScrapPayload(params) {
  const boardId = params.boardId;
  const authorUid = params.authorUid;
  const publisherUid = params.publisherUid;
  const rawUrl = params.rawUrl;
  const rawSourceType = params.rawSourceType;
  const titleOverride = params.titleOverride;
  const adminPublish = params.adminPublish === true;

  const db = admin.firestore();
  const authorRef = db.collection("users").doc(authorUid);
  const authorDoc = await authorRef.get();
  if (!authorDoc.exists) {
    throw new HttpsError("not-found", "작성자 사용자를 찾을 수 없습니다.");
  }

  const validated = await validateScrapPayload(rawUrl, rawSourceType);
  if (!validated.canPublish) {
    throw new HttpsError(
        "failed-precondition",
        "검증을 통과한 URL만 업로드할 수 있습니다.",
        {
          warnings: validated.warnings,
          duplicatePost: validated.duplicatePost,
        },
    );
  }

  const finalTitle = (titleOverride || validated.title || "").trim();
  if (!finalTitle) {
    throw new HttpsError("invalid-argument", "제목을 입력해주세요.");
  }

  const postId = crypto.randomUUID();
  const dateString = koreaDateKey();
  const author = authorDoc.data() || {};
  const postPath = `posts/${dateString}/posts/${postId}`;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const sourceUrl = validated.normalizedUrl;
  const postTitle = finalTitle.slice(0, 180);
  const parsedForHtml = {
    sourceType: validated.sourceType,
    contentHtml: validated.contentHtml,
  };
  const contentHtml = buildScrapPublishHtml(parsedForHtml, sourceUrl);
  const publisherFields = adminPublish ?
    {scrapedByAdminUid: publisherUid} :
    {scrapedByUid: publisherUid};
  let postNumber = "";
  const postRef = db.collection("posts")
      .doc(dateString)
      .collection("posts")
      .doc(postId);
  await db.runTransaction(async (transaction) => {
    const metaRef = db.collection("meta").doc("postNumber");
    const sourceRef = scrapSourceRef(sourceUrl);
    const [snap, sourceSnap] = await Promise.all([
      transaction.get(metaRef),
      transaction.get(sourceRef),
    ]);
    if (sourceSnap.exists) {
      const duplicatePost = scrapDuplicatePostFromLedger(
          sourceSnap.data() || {},
      );
      if (!duplicatePost.postPath) {
        throw new HttpsError(
            "failed-precondition",
            "이미 같은 URL로 발행된 게시글이 있습니다.",
            {duplicatePost},
        );
      }
      const duplicateSnap = await transaction.get(
          db.doc(duplicatePost.postPath),
      );
      if (duplicateSnap.exists) {
        throw new HttpsError(
            "failed-precondition",
            "이미 같은 URL로 발행된 게시글이 있습니다.",
            {duplicatePost},
        );
      }
    }

    const current = Number((snap.data() || {}).number || 0);
    const next = current + 1;
    postNumber = String(next);
    const postData = {
      postId,
      postNumber,
      boardId,
      title: postTitle,
      contentHtml,
      author: {
        uid: authorUid,
        displayName: author.displayName || "익명",
        photoURL: author.photoURL || "",
        displayGrade: author.displayGrade || "이코노미 Lv.1",
        currentSkyEffect: author.currentSkyEffect || "",
      },
      viewsCount: 0,
      likesCount: 0,
      commentCount: 0,
      reportsCount: 0,
      isDeleted: false,
      isHidden: false,
      hiddenByReport: false,
      readRestriction: {
        enabled: false,
        minRank: 0,
        label: "전체 공개",
      },
      sourceUrl,
      sourceUrlNormalized: sourceUrl,
      sourceType: validated.sourceType,
      scrapedAuthor: validated.scrapedAuthor,
      scrapedDateText: validated.scrapedDateText,
      ...publisherFields,
      createdAt: now,
      updatedAt: now,
    };

    transaction.set(metaRef, {number: next}, {merge: true});
    transaction.set(postRef, postData);
    transaction.set(db.collection("post_numbers").doc(postNumber), {
      postNumber,
      postPath,
      dateString,
      postId,
      boardId,
      title: postTitle,
      authorUid,
      isDeleted: false,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
    });
    transaction.set(authorRef.collection("my_posts").doc(postId), {
      postPath,
      postId,
      postNumber,
      dateString,
      title: postTitle,
      boardId,
      createdAt: now,
    });
    transaction.set(sourceRef, {
      sourceUrl,
      sourceUrlNormalized: sourceUrl,
      sourceType: validated.sourceType,
      postId,
      postNumber,
      dateString,
      postPath,
      boardId,
      title: postTitle,
      authorUid,
      createdAt: now,
      updatedAt: now,
    });
    transaction.update(authorRef, {
      postsCount: admin.firestore.FieldValue.increment(1),
    });
  });

  return {
    ok: true,
    postId,
    postNumber,
    dateString,
    postPath,
  };
}

/**
 * 관리자 스크랩 URL을 검증하고 미리보기 데이터를 반환한다.
 */
exports.validateScrapPost = onCall({
  region: CARD_REGION,
  timeoutSeconds: 60,
  memory: "512MiB",
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);
  const data = request.data || {};
  return validateScrapPayload(data.url, data.sourceType);
});

/**
 * 일반 사용자용 네이버 블로그 스크랩 URL을 검증한다.
 */
exports.validateUserScrapPost = onCall({
  region: CARD_REGION,
  timeoutSeconds: 60,
  memory: "512MiB",
}, async (request) => {
  requireAuthUid(request);
  const data = request.data || {};
  return validateScrapPayload(data.url, SCRAP_NAVER);
});

/**
 * 관리자 스크랩 글을 선택 사용자 명의의 커뮤니티 게시글로 발행한다.
 */
exports.publishScrapPost = onCall({
  region: CARD_REGION,
  timeoutSeconds: 90,
  memory: "512MiB",
}, async (request) => {
  const adminUid = requireAuthUid(request);
  await requireCardAdmin(adminUid);
  const data = request.data || {};
  const boardId = asIdString(data.boardId);
  const authorUid = asIdString(data.authorUid);
  const titleOverride = asOptionalString(data.titleOverride);
  if (!boardId) {
    throw new HttpsError("invalid-argument", "카테고리를 선택해주세요.");
  }
  if (!authorUid) {
    throw new HttpsError("invalid-argument", "작성자를 선택해주세요.");
  }

  await requireScrapBoard(boardId);
  return publishScrapPayload({
    boardId,
    authorUid,
    publisherUid: adminUid,
    rawUrl: data.url,
    rawSourceType: data.sourceType,
    titleOverride,
    adminPublish: true,
  });
});

/**
 * 일반 사용자용 네이버 블로그 스크랩 글을 본인 명의로 발행한다.
 */
exports.publishUserScrapPost = onCall({
  region: CARD_REGION,
  timeoutSeconds: 90,
  memory: "512MiB",
}, async (request) => {
  const uid = requireAuthUid(request);
  const data = request.data || {};
  const boardId = asIdString(data.boardId);
  const titleOverride = asOptionalString(data.titleOverride);
  if (!boardId) {
    throw new HttpsError("invalid-argument", "카테고리를 선택해주세요.");
  }

  await requireUserScrapBoard(boardId);
  return publishScrapPayload({
    boardId,
    authorUid: uid,
    publisherUid: uid,
    rawUrl: data.url,
    rawSourceType: SCRAP_NAVER,
    titleOverride,
    adminPublish: false,
  });
});

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

    if (!fcmToken || !shouldSendCommunityPush(authorData, "post_like")) {
      logger.info(`좋아요 알림 FCM 발송 생략: authorUid=${authorUid}`);
      return;
    }

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

    if (!fcmToken || !shouldSendCommunityPush(authorData, "post_comment")) {
      logger.info(`댓글 알림 FCM 발송 생략: authorUid=${authorUid}`);
      return;
    }

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

    if (!fcmToken ||
        !shouldSendCommunityPush(parentCommenterData, "comment_reply")) {
      logger.info(`대댓글 알림 FCM 발송 생략: uid=${parentCommenterUid}`);
      return;
    }

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

    if (!fcmToken ||
        !shouldSendCommunityPush(commenterUserData, "comment_like")) {
      logger.info(`댓글 좋아요 알림 FCM 발송 생략: uid=${commenterUid}`);
      return;
    }

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
  const body = requireCardCommentBody(data.body);

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
 * 카드 매칭 테스트 입력 정규화
 * @param {Object} input
 * @return {Object}
 */
function normalizeCardPreferenceProfile(input) {
  const data = isPlainObject(input) ? input : {};
  const categories = Array.isArray(data.benefitCategoryIds) ?
    data.benefitCategoryIds.map(String).slice(0, 20) :
    [];
  const monthlySpendKRW = Math.max(
      0,
      asOptionalNumber(data.monthlySpendKRW) || 1000000,
  );
  const spendCategories = normalizeCardSpendCategories(
      data.spendCategories,
      monthlySpendKRW,
  );
  const detailedSpend = sumSpendCategories(spendCategories);
  return {
    preferredAirline: asOptionalString(data.preferredAirline) || "대한항공",
    monthlySpendKRW: detailedSpend > 0 ? detailedSpend : monthlySpendKRW,
    spendCategories,
    usesOverseas: data.usesOverseas !== false,
    wantsLounge: data.wantsLounge !== false,
    usesGiftcard: data.usesGiftcard !== false,
    benefitCategoryIds: categories,
    maxAnnualFeeKRW: Math.max(
        0,
        asOptionalNumber(data.maxAnnualFeeKRW) || 150000,
    ),
    maxPreviousMonthSpendKRW: Math.max(
        0,
        asOptionalNumber(data.maxPreviousMonthSpendKRW) || 500000,
    ),
    mileValueKRW: Math.max(1, asOptionalNumber(data.mileValueKRW) || 15),
  };
}

/**
 * 카드 추천용 상세 소비 항목 정규화
 * @param {unknown} input
 * @param {number} monthlySpendKRW
 * @return {Object<string, number>}
 */
function normalizeCardSpendCategories(input, monthlySpendKRW) {
  const defaults = defaultCardSpendCategories(monthlySpendKRW);
  if (!isPlainObject(input)) {
    return defaults;
  }
  const output = {...defaults};
  Object.keys(defaults).forEach((key) => {
    const value = asOptionalNumber(input[key]);
    if (value !== null && value !== undefined && Number.isFinite(value)) {
      output[key] = Math.max(0, Math.round(value));
    }
  });
  return output;
}

/**
 * 월 사용액을 상세 소비 항목으로 나눈 기본값
 * @param {number} monthlySpendKRW
 * @return {Object<string, number>}
 */
function defaultCardSpendCategories(monthlySpendKRW) {
  const safeMonthlySpend = monthlySpendKRW > 0 ? monthlySpendKRW : 1000000;
  const portion = (ratio) => Math.round(safeMonthlySpend * ratio);
  return {
    general: portion(0.50),
    overseas: portion(0.10),
    onlineShopping: portion(0.15),
    mart: portion(0.10),
    telecomSubscription: portion(0.10),
    travel: portion(0.05),
    giftcard: 0,
  };
}

/**
 * 상세 소비 항목 합계
 * @param {Object<string, number>} spendCategories
 * @return {number}
 */
function sumSpendCategories(spendCategories) {
  return Object.values(spendCategories || {}).reduce(
      (sum, value) => sum + Math.max(0, Number(value || 0)),
      0,
  );
}

/**
 * 카드 문서의 추천 검색 문자열
 * @param {Object} card
 * @return {string}
 */
function catalogCardHaystack(card) {
  const benefits = Array.isArray(card.primaryBenefits) ?
    card.primaryBenefits.map((item) => {
      if (!item || typeof item !== "object") {
        return String(item || "");
      }
      return `${item.title || ""} ${item.value || ""} ${item.summary || ""}`;
    }) :
    [];
  return [
    card.name,
    card.issuerName,
    card.rewardProgram,
    card.detailSummary,
    ...(Array.isArray(card.benefitCategoryIds) ? card.benefitCategoryIds : []),
    ...(Array.isArray(card.mileagePrograms) ? card.mileagePrograms : []),
    ...benefits,
  ].join(" ").toLowerCase();
}

/**
 * 카드 문서가 마일리지형인지 확인
 * @param {Object} card
 * @return {boolean}
 */
function isMileageCatalogCard(card) {
  return /마일|mileage|skypass|스카이패스|아시아나/.test(
      catalogCardHaystack(card),
  );
}

/**
 * 카드 문서가 여행형인지 확인
 * @param {Object} card
 * @return {boolean}
 */
function isTravelCatalogCard(card) {
  const flags = card.travelFlags || {};
  return Object.values(flags).some((value) => value === true) ||
    /여행|트래블|travel|해외|라운지|lounge|항공/.test(
        catalogCardHaystack(card),
    );
}

/**
 * 카드 문서에서 대략적인 마일 적립 기준을 추정
 * @param {Object} card
 * @return {number}
 */
function estimatePerMileKRW(card) {
  for (const key of [
    "mileRuleUsedPerMileKRW",
    "creditPerMileKRW",
    "checkPerMileKRW",
    "perMileKRW",
    "milePerKRW",
  ]) {
    const value = asOptionalNumber(card[key]);
    if (value && value > 0) {
      return value;
    }
  }
  const text = catalogCardHaystack(card);
  const match = text.match(/([0-9,]+)\s*원당\s*([0-9,]+)\s*마일/);
  if (match) {
    const krw = Number(match[1].replace(/,/g, ""));
    const miles = Number(match[2].replace(/,/g, ""));
    if (krw > 0 && miles > 0) {
      return Math.round(krw / miles);
    }
  }
  return isMileageCatalogCard(card) ? 1000 : 0;
}

/**
 * 텍스트나 숫자에서 첫 원화 금액을 추출한다.
 * @param {unknown} value
 * @return {?number}
 */
function extractFirstKrwNumber(value) {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.round(value);
  }
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.replace(/만원/g, "0000");
  const match = normalized.match(/([0-9][0-9,]*)/);
  if (!match) {
    return null;
  }
  const parsed = Number(match[1].replace(/,/g, ""));
  return Number.isFinite(parsed) && parsed > 0 ? Math.round(parsed) : null;
}

/**
 * 카드 문서에서 연회비를 추정한다.
 * @param {Object} card
 * @return {?number}
 */
function estimateAnnualFeeKRW(card) {
  const annualFee = isPlainObject(card.annualFee) ? card.annualFee : {};
  for (const key of [
    "amountKRW",
    "domesticKRW",
    "overseasKRW",
    "localKRW",
    "summary",
    "domestic",
    "overseas",
  ]) {
    const value = extractFirstKrwNumber(annualFee[key]);
    if (value) {
      return value;
    }
  }
  const rawValue = extractFirstKrwNumber(card.annualFeeKRW);
  if (rawValue) {
    return rawValue;
  }
  const summary = Object.values(annualFee).map(String).join(" ");
  return extractFirstKrwNumber(summary);
}

/**
 * 카드 매칭 점수 계산
 * @param {string} cardId
 * @param {Object} card
 * @param {Object} profile
 * @return {Object}
 */
function calculateCardMatch(cardId, card, profile) {
  const text = catalogCardHaystack(card);
  const reasons = [];
  const communityScore = Math.max(0, Math.min(100,
      Number(card.commentsCount || 0) * 12 +
      Number(card.likesCount || 0) * 5 +
      Math.floor(Number(card.viewsCount || 0) / 10),
  ));
  const perMile = estimatePerMileKRW(card);
  const annualFeeKRW = estimateAnnualFeeKRW(card);
  const mileValueKRW = Math.max(1, Number(profile.mileValueKRW || 15));
  const giftcardSpend = Math.max(
      0,
      Number((profile.spendCategories || {}).giftcard || 0),
  );
  const overseasSpend = Math.max(
      0,
      Number((profile.spendCategories || {}).overseas || 0),
  );
  const travelSpend = Math.max(
      0,
      Number((profile.spendCategories || {}).travel || 0),
  );
  let mileageScore = isMileageCatalogCard(card) ? 42 : 0;
  let sangtechScore = 10;
  let travelScore = isTravelCatalogCard(card) ? 38 : 0;
  let score = 25;

  if (isMileageCatalogCard(card)) {
    score += 18;
    reasons.push("마일리지 적립 성향");
  }
  if (
    profile.preferredAirline.includes("대한") &&
    (text.includes("대한") || text.includes("skypass") ||
      text.includes("스카이패스"))
  ) {
    score += 16;
    mileageScore += 24;
    reasons.push("대한항공 선호와 맞음");
  }
  if (profile.preferredAirline.includes("아시아나") &&
      text.includes("아시아나")) {
    score += 16;
    mileageScore += 24;
    reasons.push("아시아나 선호와 맞음");
  }
  if (profile.usesOverseas && isTravelCatalogCard(card)) {
    score += 12;
    travelScore += overseasSpend > 0 ? 18 : 10;
    reasons.push("해외/여행 혜택");
  }
  if (profile.wantsLounge && /라운지|lounge|priority pass/.test(text)) {
    score += 12;
    travelScore += 22;
    reasons.push("라운지 활용 가능");
  }
  if (profile.usesGiftcard && /실적|무실적|상품권|상테크/.test(text)) {
    score += 7;
    sangtechScore += 28;
    reasons.push("상테크 검토 대상");
  }
  if (giftcardSpend > 0 && /실적|무실적|상품권|상테크/.test(text)) {
    sangtechScore += 18;
  }
  if (card.eventSummary && Object.keys(card.eventSummary).length > 0) {
    sangtechScore += 10;
  }
  if (travelSpend > 0 && isTravelCatalogCard(card)) {
    travelScore += 12;
  }

  score += Math.min(10, Number(card.likesCount || 0));
  score += Math.min(8, Number(card.commentsCount || 0) * 2);
  score += Math.min(8, Math.floor(Number(card.viewsCount || 0) / 20));
  const estimatedMonthlyMiles = perMile > 0 ?
    Math.round(profile.monthlySpendKRW / perMile) :
    0;
  const estimatedAnnualValueKRW = estimatedMonthlyMiles * 12 * mileValueKRW;
  const estimatedAnnualNetValueKRW = annualFeeKRW ?
    estimatedAnnualValueKRW - annualFeeKRW :
    null;
  const breakEvenMonthlySpendKRW = annualFeeKRW && perMile > 0 ?
    Math.round((annualFeeKRW * perMile) / (12 * mileValueKRW)) :
    null;
  mileageScore += Math.min(20, Math.floor(estimatedMonthlyMiles / 50));
  sangtechScore += Math.min(18, Math.floor(estimatedAnnualValueKRW / 60000));
  travelScore += Math.min(
      10,
      Math.floor((overseasSpend + travelSpend) / 100000),
  );
  mileageScore = Math.max(0, Math.min(100, mileageScore));
  sangtechScore = Math.max(0, Math.min(100, sangtechScore));
  travelScore = Math.max(0, Math.min(100, travelScore));
  const overallScore = Math.round(
      Math.max(0, Math.min(100, score)) * 0.38 +
      sangtechScore * 0.27 +
      mileageScore * 0.20 +
      travelScore * 0.10 +
      communityScore * 0.05,
  );

  return {
    cardId,
    score: overallScore,
    overallScore,
    sangtechScore,
    mileageScore,
    travelScore,
    communityScore,
    estimatedMonthlyMiles,
    estimatedAnnualValueKRW,
    annualFeeKRW,
    estimatedAnnualNetValueKRW,
    breakEvenMonthlySpendKRW,
    reasons: reasons.length ? reasons : ["마일캐치 인기 카드"],
    product: {
      name: card.name,
      issuerName: card.issuerName,
      issuerId: card.issuerId || null,
      cardType: card.cardType || "unknown",
      status: card.status || "active",
      sourceType: card.sourceType || "unknown",
      rewardProgram: card.rewardProgram || null,
      annualFee: card.annualFee || {},
      previousMonthSpend: card.previousMonthSpend || {},
      primaryBenefits: card.primaryBenefits || [],
      exclusions: card.exclusions || [],
      benefitCategoryIds: card.benefitCategoryIds || [],
      mileagePrograms: card.mileagePrograms || [],
      travelFlags: card.travelFlags || {},
      loungeSummary: card.loungeSummary || {},
      eventSummary: card.eventSummary || {},
      sourceRefs: card.sourceRefs || {},
      detailSummary: card.detailSummary || "",
      images: card.images || {},
      quality: card.quality || {},
      likesCount: Number(card.likesCount || 0),
      commentsCount: Number(card.commentsCount || 0),
      viewsCount: Number(card.viewsCount || 0),
    },
  };
}

/**
 * 카드 추천 섹션 묶음을 만든다.
 * @param {Array<Object>} matches
 * @return {Array<Object>}
 */
function buildCardRecommendationSections(matches) {
  const by = (field) => [...matches].sort((left, right) =>
    Number(right[field] || 0) - Number(left[field] || 0),
  );
  const eventMatches = [...matches]
      .filter((match) => {
        const summary = match.product && match.product.eventSummary;
        return summary && Object.keys(summary).length > 0;
      })
      .sort((left, right) => right.sangtechScore - left.sangtechScore);
  return [
    {
      key: "overall",
      title: "내 소비 기준 TOP",
      subtitle: "입력한 소비 패턴과 카드 기본 효율을 함께 본 추천입니다.",
      matches: by("overallScore").slice(0, 10),
    },
    {
      key: "sangtech",
      title: "상테크 효율 TOP",
      subtitle: "상품권/실적 루틴과 예상 마일 가치를 우선했습니다.",
      matches: by("sangtechScore").slice(0, 10),
    },
    {
      key: "mileage",
      title: "항공 마일리지 TOP",
      subtitle: "항공사 선호와 월 예상 마일을 기준으로 정렬했습니다.",
      matches: by("mileageScore").slice(0, 10),
    },
    {
      key: "travel",
      title: "라운지/트래블 TOP",
      subtitle: "해외결제, 여행, 라운지 활용도를 반영했습니다.",
      matches: by("travelScore").slice(0, 10),
    },
    {
      key: "event",
      title: "이벤트 캐시백 추천",
      subtitle: "진행 이벤트 요약이 있는 카드를 먼저 보여줍니다.",
      matches: eventMatches.slice(0, 10),
    },
    {
      key: "community",
      title: "커뮤니티 검증 카드",
      subtitle: "댓글, 좋아요, 조회 기반으로 실제 검증 신호를 봅니다.",
      matches: by("communityScore").slice(0, 10),
    },
  ].filter((section) => section.matches.length > 0);
}

/**
 * 추천 비교표에 넣을 대표 카드들을 고른다.
 * @param {Array<Object>} sections
 * @return {Array<Object>}
 */
function buildCardComparisonRows(sections) {
  const seen = new Set();
  const rows = [];
  sections.forEach((section) => {
    section.matches.slice(0, 4).forEach((match) => {
      if (seen.has(match.cardId)) {
        return;
      }
      seen.add(match.cardId);
      rows.push(match);
    });
  });
  return rows.slice(0, 14);
}

/**
 * 1분 테스트 기반 카드 매칭 결과를 계산한다.
 */
exports.calculateCardMatches = onCall({
  region: CARD_REGION,
  timeoutSeconds: 60,
  memory: "512MiB",
}, async (request) => {
  const data = request.data || {};
  const profile = normalizeCardPreferenceProfile(data.profile || {});
  const limit = Math.min(50, Math.max(1, asOptionalNumber(data.limit) || 20));

  const snapshot = await cardCatalogRef()
      .collection("cardProducts")
      .where("status", "in", ["active", "pending"])
      .limit(500)
      .get();
  const matches = snapshot.docs
      .map((doc) => calculateCardMatch(doc.id, doc.data() || {}, profile))
      .sort((left, right) => right.overallScore - left.overallScore);
  const sections = buildCardRecommendationSections(matches)
      .map((section) => ({
        ...section,
        matches: section.matches.slice(0, limit),
      }));
  const comparisonRows = buildCardComparisonRows(sections);
  return {
    profile,
    matches: matches.slice(0, limit),
    sections,
    comparisonRows,
  };
});

/**
 * 랭킹 문서를 갱신한다.
 */
exports.refreshCardRankings = onCall({
  region: CARD_REGION,
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);
  const snapshot = await cardCatalogRef()
      .collection("cardProducts")
      .where("status", "in", ["active", "pending"])
      .limit(800)
      .get();
  const cards = snapshot.docs.map((doc) => ({
    id: doc.id,
    data: doc.data() || {},
  }));
  const popularityScore = (card) =>
    Number(card.commentsCount || 0) * 12 +
    Number(card.likesCount || 0) * 6 +
    Number(card.viewsCount || 0);
  const keywordScore = (card, keywords) => {
    const text = catalogCardHaystack(card).toLowerCase();
    return keywords.reduce(
        (score, keyword) => score + (text.includes(keyword) ? 1 : 0),
        0,
    );
  };
  const updatedMillis = (card) => {
    const value = card.updatedAt || card.createdAt;
    return value && typeof value.toMillis === "function" ? value.toMillis() : 0;
  };
  const compareByScore = (left, right, score) => {
    const scoreDiff = score(right.data) - score(left.data);
    if (scoreDiff !== 0) return scoreDiff;
    const updatedDiff = updatedMillis(right.data) - updatedMillis(left.data);
    if (updatedDiff !== 0) return updatedDiff;
    return String(left.data.name || left.id).localeCompare(
        String(right.data.name || right.id),
        "ko",
    );
  };
  const mileageKeywords = [
    "마일",
    "mileage",
    "skypass",
    "스카이패스",
    "대한항공",
    "아시아나",
  ];
  const travelKeywords = [
    "여행",
    "트래블",
    "travel",
    "해외",
    "라운지",
    "lounge",
    "항공",
    "호텔",
  ];
  const byPopularity = [...cards].sort((left, right) =>
    compareByScore(left, right, popularityScore),
  );
  const mileage = cards
      .filter((item) => isMileageCatalogCard(item.data))
      .sort((left, right) =>
        compareByScore(
            left,
            right,
            (card) => keywordScore(card, mileageKeywords) * 1000 +
              popularityScore(card),
        ),
      );
  const travel = cards
      .filter((item) => isTravelCatalogCard(item.data))
      .sort((left, right) =>
        compareByScore(
            left,
            right,
            (card) => keywordScore(card, travelKeywords) * 1000 +
              popularityScore(card),
        ),
      );

  const rankings = {
    popular: {
      title: "마일캐치 인기순",
      basis: "댓글 12점 + 좋아요 6점 + 조회 1점",
      periodLabel: "실시간",
      cardIds: byPopularity.map((item) => item.id).slice(0, 100),
    },
    mileage: {
      title: "항공마일리지 TOP",
      basis: "마일리지 적합도 + 실시간 반응",
      periodLabel: "실시간",
      cardIds: mileage.map((item) => item.id).slice(0, 100),
    },
    travel: {
      title: "라운지/트래블 TOP",
      basis: "여행/라운지 적합도 + 실시간 반응",
      periodLabel: "실시간",
      cardIds: travel.map((item) => item.id).slice(0, 100),
    },
  };

  const batch = admin.firestore().batch();
  Object.entries(rankings).forEach(([key, value]) => {
    batch.set(
        cardCatalogRef().collection("cardRankings").doc(key),
        {
          ...value,
          calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedByUid: uid,
        },
        {merge: true},
    );
  });
  await batch.commit();
  return {
    updated: Object.keys(rankings),
    counts: {
      products: cards.length,
      mileage: mileage.length,
      travel: travel.length,
    },
  };
});

/**
 * 카드고릴라 이벤트 항목 정규화
 * @param {Object} item
 * @return {Object|null}
 */
function normalizeCardGorillaEvent(item) {
  if (!item || typeof item !== "object") {
    return null;
  }
  const idx = asIdString(item.idx || item.eid);
  if (!idx) {
    return null;
  }
  const rawCardIds = Array.isArray(item.card_idxs) ?
    item.card_idxs :
    String(item.card_idxs || "")
        .split(",")
        .map((value) => value.trim())
        .filter(Boolean);
  const cardIds = rawCardIds
      .map((value) => asIdString(value))
      .filter(Boolean)
      .map((value) => `cg_${value}`);
  const title = asOptionalString(item.title) ||
    asOptionalString(item.subject) ||
    "카드 이벤트";
  const subject = asOptionalString(item.subject);
  const eventUrl = asOptionalString(item.event_url);
  const absoluteEventUrl = eventUrl && eventUrl.startsWith("http") ?
    eventUrl :
    null;
  const startsAt = asOptionalDate(item.evt_start_time);
  const endsAt = asOptionalDate(item.evt_end_time);
  const benefitText = asOptionalString(item.card_detail_text) || subject;
  return {
    eventId: `cg_${idx}`,
    data: {
      sourceType: "cardGorilla",
      sourceRefs: {
        cardGorilla: {
          idx,
          eventUrl: `https://www.card-gorilla.com/event/detail/${idx}`,
        },
      },
      title,
      issuerName: asOptionalString(item.corp_name) || "카드사",
      issuerId: item.corp_idx ? `cg_${asIdString(item.corp_idx)}` : null,
      type: asOptionalString(item.type) || "event",
      subject,
      cardIds,
      benefitText,
      benefitAmountKRW: extractKrwAmount(benefitText),
      applyUrl: absoluteEventUrl,
      sourceUrl: `https://www.card-gorilla.com/event/detail/${idx}`,
      startsAt,
      endsAt,
      isVisible: item.is_visible !== false,
      isLive: item.is_live !== false && item.evt_status !== "E",
      raw: sanitizeCardJsonValue(item),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  };
}

/**
 * 카드 이벤트를 공개 데이터에서 동기화한다.
 */
exports.syncCardEvents = onCall({
  region: CARD_REGION,
  timeoutSeconds: 120,
  memory: "512MiB",
}, async (request) => {
  const uid = requireAuthUid(request);
  await requireCardAdmin(uid);
  const limit = Math.min(
      200,
      Math.max(1, asOptionalNumber((request.data || {}).limit) || 80),
  );
  const response = await globalThis.fetch(
      `${CARD_GORILLA_API_BASE}/events?p=1&perPage=${limit}`,
  );
  if (!response.ok) {
    throw new HttpsError("unavailable", "카드 이벤트를 가져오지 못했습니다.");
  }
  const payload = await response.json();
  const items = Array.isArray(payload) ? payload : payload.data || [];
  const normalized = items.map(normalizeCardGorillaEvent).filter(Boolean);
  const batch = admin.firestore().batch();
  normalized.forEach((event) => {
    batch.set(
        cardCatalogRef().collection("cardEvents").doc(event.eventId),
        {
          ...event.data,
          syncedByUid: uid,
        },
        {merge: true},
    );
  });
  if (normalized.length > 0) {
    await batch.commit();
  }
  return {
    requested: limit,
    imported: normalized.length,
  };
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
