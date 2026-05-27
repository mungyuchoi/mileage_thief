#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs/promises");
const path = require("path");

const PROJECT_ROOT = path.resolve(__dirname, "../..");
const FUNCTIONS_NODE_MODULES = path.join(PROJECT_ROOT, "functions", "node_modules");

let cheerio;
try {
  cheerio = require(path.join(FUNCTIONS_NODE_MODULES, "cheerio"));
} catch (error) {
  console.error(
    [
      "cheerio를 찾지 못했습니다.",
      "먼저 프로젝트 루트에서 다음 명령을 실행해주세요:",
      "  cd functions && npm install",
    ].join("\n"),
  );
  process.exit(1);
}

const CAFE_ID = 18786605;
const MENU_ID = 890;
const MENU_NAME = "질문게시판";
const SOURCE = "naver_cafe";
const BOARD_BASE_URL = `https://cafe.naver.com/f-e/cafes/${CAFE_ID}/menus/${MENU_ID}`;
const BOARD_LIST_API_BASE =
  "https://apis.naver.com/cafe-web/cafe-boardlist-api/v1";
const ARTICLE_API_BASE = "https://article.cafe.naver.com/gw/v4";
const COMMENT_API_BASE =
  "https://apis.naver.com/cafe-web/cafe-articleapi/v3";
const DEFAULT_DELAY_MS = 350;
const REQUEST_TIMEOUT_MS = 15000;
const MAX_RETRIES = 3;

const ALLOWED_TAGS = new Set([
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

function parseArgs(argv) {
  const args = {
    startPage: 1,
    endPage: 200,
    perPage: 15,
    out: "",
    delayMs: DEFAULT_DELAY_MS,
    limitArticles: 0,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];

    if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    }

    if (arg === "--start-page") {
      args.startPage = parsePositiveInt(next, "--start-page");
      index += 1;
      continue;
    }
    if (arg === "--end-page") {
      args.endPage = parsePositiveInt(next, "--end-page");
      index += 1;
      continue;
    }
    if (arg === "--per-page") {
      args.perPage = parsePositiveInt(next, "--per-page");
      index += 1;
      continue;
    }
    if (arg === "--out") {
      args.out = requireValue(next, "--out");
      index += 1;
      continue;
    }
    if (arg === "--delay-ms") {
      args.delayMs = parseNonNegativeInt(next, "--delay-ms");
      index += 1;
      continue;
    }
    if (arg === "--limit-articles") {
      args.limitArticles = parseNonNegativeInt(next, "--limit-articles");
      index += 1;
      continue;
    }

    throw new Error(`알 수 없는 옵션입니다: ${arg}`);
  }

  if (args.endPage < args.startPage) {
    throw new Error("--end-page는 --start-page보다 크거나 같아야 합니다.");
  }
  if (args.perPage > 50) {
    throw new Error("--per-page는 50 이하로 지정해주세요.");
  }

  if (!args.out) {
    const fileName = `susasa_qna_${koreaDateKey()}.json`;
    args.out = path.join(PROJECT_ROOT, "docs", "exam", fileName);
  } else {
    args.out = path.resolve(PROJECT_ROOT, args.out);
  }

  return args;
}

function printHelp() {
  console.log(`
Usage:
  node task/cafe/scrape_susasa_qna.js --start-page 1 --end-page 200

Options:
  --start-page <number>     시작 페이지 (default: 1)
  --end-page <number>       종료 페이지 (default: 200)
  --per-page <number>       페이지당 글 수 (default: 15)
  --out <path>              출력 JSON 경로 (default: docs/exam/susasa_qna_YYYYMMDD.json)
  --delay-ms <number>       요청 사이 대기 시간 ms (default: 350)
  --limit-articles <number> 전체 수집 글 수 제한. 0이면 제한 없음.

Environment:
  NAVER_COOKIE              필요한 경우 네이버 쿠키를 요청 헤더에만 사용합니다.
`);
}

function requireValue(value, optionName) {
  if (!value || value.startsWith("--")) {
    throw new Error(`${optionName} 값이 필요합니다.`);
  }
  return value;
}

function parsePositiveInt(value, optionName) {
  const number = Number.parseInt(requireValue(value, optionName), 10);
  if (!Number.isInteger(number) || number < 1) {
    throw new Error(`${optionName}는 1 이상의 정수여야 합니다.`);
  }
  return number;
}

function parseNonNegativeInt(value, optionName) {
  const number = Number.parseInt(requireValue(value, optionName), 10);
  if (!Number.isInteger(number) || number < 0) {
    throw new Error(`${optionName}는 0 이상의 정수여야 합니다.`);
  }
  return number;
}

function koreaDateKey() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date()).replace(/-/g, "");
}

function sleep(ms) {
  if (!ms) return Promise.resolve();
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function textValue(value) {
  return String(value || "").replace(/\s+/g, " ").trim();
}

function numberValue(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const number = Number(String(value || "").replace(/,/g, ""));
  return Number.isFinite(number) ? number : 0;
}

function isoFromTimestamp(value) {
  const number = numberValue(value);
  if (!number) return "";
  try {
    return new Date(number).toISOString();
  } catch (error) {
    return "";
  }
}

function safeUrl(value, baseUrl = null) {
  const raw = String(value || "").trim();
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

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function anonymizeWriter(writer) {
  const source = writer || {};
  const seed = textValue(
    source.memberKey ||
      source.baMemberKey ||
      source.nick ||
      source.nickName ||
      source.nickname,
  );
  const hash = crypto
    .createHash("sha256")
    .update(seed || "unknown")
    .digest("hex")
    .slice(0, 12);

  return {
    anonId: `u_${hash}`,
    memberLevelName: textValue(source.memberLevelName),
  };
}

function requestHeaders(referer) {
  const headers = {
    "User-Agent": [
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
      "AppleWebKit/537.36 (KHTML, like Gecko)",
      "Chrome/126.0.0.0 Safari/537.36",
    ].join(" "),
    Accept: "application/json, text/plain, */*",
    "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
    Referer: referer,
  };
  const cookie = String(process.env.NAVER_COOKIE || "").trim();
  if (cookie) headers.Cookie = cookie;
  return headers;
}

async function fetchJson(url, referer) {
  let lastError = null;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
      const response = await fetch(url, {
        headers: requestHeaders(referer),
        signal: controller.signal,
      });
      const text = await response.text();
      if (!response.ok) {
        const error = new Error(`HTTP ${response.status}`);
        error.status = response.status;
        error.body = text.slice(0, 300);
        throw error;
      }
      try {
        return JSON.parse(text);
      } catch (error) {
        error.message = `JSON 파싱 실패: ${error.message}`;
        error.body = text.slice(0, 300);
        throw error;
      }
    } catch (error) {
      lastError = error;
      const retriable =
        error.name === "AbortError" ||
        error.status === 429 ||
        (error.status >= 500 && error.status < 600);
      if (!retriable || attempt === MAX_RETRIES) {
        break;
      }
      await sleep(500 * attempt);
    } finally {
      clearTimeout(timeout);
    }
  }

  throw lastError;
}

function buildArticleUrl(articleId, sourcePage) {
  const url = new URL(
    `https://cafe.naver.com/f-e/cafes/${CAFE_ID}/articles/${articleId}`,
  );
  url.searchParams.set("boardtype", "L");
  url.searchParams.set("menuid", String(MENU_ID));
  url.searchParams.set("referrerAllArticles", "false");
  if (sourcePage) url.searchParams.set("page", String(sourcePage));
  return url.toString();
}

function listApiUrl(page, perPage) {
  const url = new URL(
    `${BOARD_LIST_API_BASE}/cafes/${CAFE_ID}/menus/${MENU_ID}/articles`,
  );
  url.searchParams.set("page", String(page));
  url.searchParams.set("perPage", String(perPage));
  url.searchParams.set("sortBy", "TIME");
  url.searchParams.set("viewType", "L");
  return url.toString();
}

function detailApiUrl(articleId) {
  return `${ARTICLE_API_BASE}/cafes/${CAFE_ID}/articles/${articleId}`;
}

function commentApiUrl(articleId, page) {
  const url = new URL(
    `${COMMENT_API_BASE}/cafes/${CAFE_ID}/articles/${articleId}/comments/pages/${page}`,
  );
  url.searchParams.set("requestFrom", "A");
  return url.toString();
}

async function fetchArticleList(page, perPage) {
  const pageUrl = `${BOARD_BASE_URL}?viewType=L&page=${page}`;
  const json = await fetchJson(listApiUrl(page, perPage), pageUrl);
  const result = json.result || {};
  const articleList = Array.isArray(result.articleList)
    ? result.articleList
    : [];
  return articleList
    .filter((entry) => entry && entry.type === "ARTICLE" && entry.item)
    .map((entry) => entry.item);
}

function normalizeContentMedia(contentHtml, sourceUrl) {
  const content$ = cheerio.load(contentHtml || "", {
    decodeEntities: false,
  }, false);

  content$("img").each((index, img) => {
    const $img = content$(img);
    let src =
      $img.attr("data-lazy-src") ||
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

    src = safeUrl(src, sourceUrl);
    if (src) $img.attr("src", src);
    if (($img.attr("alt") || "") === "") $img.removeAttr("alt");
  });

  content$("video").each((index, video) => {
    const $video = content$(video);
    const src = safeUrl(
      $video.attr("src") ||
        $video.find("source").first().attr("src") ||
        $video.attr("data-src") ||
        $video.attr("data-gif-url"),
      sourceUrl,
    );
    const poster = safeUrl($video.attr("poster"), sourceUrl);
    if (src) $video.attr("src", src);
    if (poster) $video.attr("poster", poster);
  });

  return content$.root().html() || "";
}

function sanitizeHtml(html, baseUrl) {
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
    if (!ALLOWED_TAGS.has(tagName)) {
      $(node).replaceWith($(node).contents());
    }
  }

  for (const node of $root.find("*").toArray()) {
    const tagName = String(node.tagName || "").toLowerCase();
    const $node = $(node);

    if (tagName === "a") {
      const href = safeUrl($node.attr("href"), baseUrl);
      if (!href) {
        $node.replaceWith($node.contents());
        continue;
      }
      const title = textValue($node.attr("title"));
      $node.attr({});
      $node.attr("href", href);
      if (title) $node.attr("title", title.slice(0, 200));
      continue;
    }

    if (tagName === "img") {
      const src = safeUrl($node.attr("src"), baseUrl);
      if (!src) {
        $node.remove();
        continue;
      }
      const alt = textValue($node.attr("alt"));
      $node.attr({});
      $node.attr("src", src);
      if (alt) $node.attr("alt", alt.slice(0, 200));
      continue;
    }

    if (tagName === "video") {
      const src = safeUrl(
        $node.attr("src") || $node.find("source").first().attr("src"),
        baseUrl,
      );
      if (!src) {
        $node.remove();
        continue;
      }
      const poster = safeUrl($node.attr("poster"), baseUrl);
      $node.attr({});
      $node.attr("src", src);
      if (poster) $node.attr("poster", poster);
      continue;
    }

    $node.attr({});
  }

  $root.find("p").each((index, node) => {
    const $node = $(node);
    if (!textValue($node.text()) && $node.find("img, video").length === 0) {
      $node.remove();
    }
  });

  return ($root.html() || "").trim();
}

function htmlToPlainText(html) {
  if (!html) return "";
  const $ = cheerio.load(`<div id="plain-root">${html}</div>`);
  $("#plain-root br").replaceWith("\n");
  $("#plain-root p, #plain-root li, #plain-root blockquote, #plain-root h2, #plain-root h3, #plain-root h4")
    .each((index, node) => {
      $(node).append("\n");
    });
  return ($("#plain-root").text() || "")
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]{2,}/g, " ")
    .trim();
}

function normalizeBodyHtml(contentHtml, sourceUrl) {
  const normalized = normalizeContentMedia(contentHtml || "", sourceUrl);
  const sanitizedHtml = sanitizeHtml(normalized, sourceUrl);
  return {
    plainText: htmlToPlainText(sanitizedHtml),
    sanitizedHtml,
  };
}

function normalizeCommentHtml(content) {
  const raw = String(content || "").trim();
  if (!raw) {
    return {
      plainText: "",
      sanitizedHtml: "",
    };
  }
  const html = /<[^>]+>/.test(raw) ? raw : `<p>${escapeHtml(raw)}</p>`;
  const sanitizedHtml = sanitizeHtml(html, BOARD_BASE_URL);
  return {
    plainText: htmlToPlainText(sanitizedHtml),
    sanitizedHtml,
  };
}

async function fetchArticleDetail(articleId, sourcePage) {
  const articleUrl = buildArticleUrl(articleId, sourcePage);
  const json = await fetchJson(detailApiUrl(articleId), articleUrl);
  const result = json.result || {};
  const article = result.article || {};
  return {
    result,
    article,
    articleUrl,
  };
}

async function fetchComments(articleId, sourcePage, expectedCount, delayMs) {
  const comments = [];
  let page = 1;
  let hasNext = expectedCount > 0;

  while (hasNext) {
    const articleUrl = buildArticleUrl(articleId, sourcePage);
    const json = await fetchJson(commentApiUrl(articleId, page), articleUrl);
    const result = json.result || {};
    const pageItems = result.comments && Array.isArray(result.comments.items)
      ? result.comments.items
      : [];
    comments.push(...pageItems);
    hasNext = result.hasNext === true;
    page += 1;
    if (hasNext) await sleep(delayMs);
  }

  return comments;
}

function detailComments(result) {
  return result.comments && Array.isArray(result.comments.items)
    ? result.comments.items
    : [];
}

function mergeCommentFallbacks(comments, fallbackComments) {
  if (!fallbackComments.length) return comments;
  const fallbackById = new Map();
  for (const comment of fallbackComments) {
    const commentId = numberValue(comment.id);
    if (commentId) fallbackById.set(commentId, comment);
  }
  return comments.map((comment) => {
    const fallback = fallbackById.get(numberValue(comment.id));
    if (!fallback) return comment;
    return {
      ...fallback,
      ...comment,
      writer: {
        ...(fallback.writer || {}),
        ...(comment.writer || {}),
      },
      memberLevelName: comment.memberLevelName || fallback.memberLevelName,
    };
  });
}

function normalizeComment(comment) {
  const content = normalizeCommentHtml(
    comment.contentHtml || comment.content || "",
  );
  const commentId = numberValue(comment.id);
  const refId = numberValue(comment.refId);
  const parentId = numberValue(
    comment.parentId || comment.parentCommentId || comment.parentCommentNo,
  );

  return {
    commentId,
    parentCommentId: parentId || (refId && refId !== commentId ? refId : null),
    writer: anonymizeWriter({
      ...(comment.writer || {}),
      memberLevelName:
        comment.memberLevelName ||
        (comment.writer && comment.writer.memberLevelName),
    }),
    plainText: content.plainText,
    sanitizedHtml: content.sanitizedHtml,
    writtenAt: isoFromTimestamp(comment.updateDate || comment.writeDate),
    isArticleWriter: comment.isArticleWriter === true,
    isDeleted: comment.isDeleted === true,
  };
}

function normalizeArticle(listItem, detailArticle, articleUrl, sourcePage, comments) {
  const writerInfo = listItem.writerInfo || {};
  const detailWriter = detailArticle.writer || {};
  const rawContentHtml = detailArticle.contentHtml || "";
  const body = normalizeBodyHtml(rawContentHtml, articleUrl);
  const title = textValue(detailArticle.subject || listItem.subject);
  const head = textValue(listItem.headName || "");

  return {
    articleId: numberValue(listItem.articleId || detailArticle.id),
    url: articleUrl,
    sourcePage,
    head,
    title,
    summary: textValue(listItem.summary),
    writer: anonymizeWriter({
      memberKey: writerInfo.memberKey || detailWriter.memberKey,
      baMemberKey: detailWriter.baMemberKey,
      nickName: writerInfo.nickName,
      nick: detailWriter.nick,
      memberLevelName: writerInfo.memberLevelName || detailWriter.memberLevelName,
    }),
    writtenAt: isoFromTimestamp(
      detailArticle.writeDate || listItem.writeDateTimestamp,
    ),
    stats: {
      readCount: numberValue(detailArticle.readCount || listItem.readCount),
      likeCount: numberValue(listItem.likeCount),
      commentCount: numberValue(
        detailArticle.commentCount || listItem.commentCount,
      ),
    },
    body,
    comments: comments.map(normalizeComment),
  };
}

function errorPayload(scope, error, extra = {}) {
  return {
    scope,
    ...extra,
    message: error && error.message ? String(error.message) : String(error),
    status: error && error.status ? error.status : null,
  };
}

function outputHasSensitiveIdentity(jsonText) {
  return /"memberKey"|"baMemberKey"|"nick"|"nickName"|"nickname"|"image"\s*:/i
    .test(jsonText);
}

async function writeJsonAtomic(outputPath, data) {
  const dir = path.dirname(outputPath);
  await fs.mkdir(dir, {recursive: true});
  const tmpPath = path.join(
    dir,
    `.${path.basename(outputPath)}.${process.pid}.tmp`,
  );
  const jsonText = `${JSON.stringify(data, null, 2)}\n`;

  if (outputHasSensitiveIdentity(jsonText)) {
    throw new Error(
      "출력 JSON에 원본 식별자 키가 포함되어 쓰기를 중단했습니다.",
    );
  }

  await fs.writeFile(tmpPath, jsonText, "utf8");
  await fs.rename(tmpPath, outputPath);
}

async function run() {
  const args = parseArgs(process.argv.slice(2));
  const articles = [];
  const errors = [];
  const seenArticleIds = new Set();
  let reachedLimit = false;

  console.log(
    [
      `스사사 질문게시판 수집 시작: page ${args.startPage}-${args.endPage}`,
      `output: ${args.out}`,
      process.env.NAVER_COOKIE ? "NAVER_COOKIE: set" : "NAVER_COOKIE: not set",
    ].join("\n"),
  );

  for (let page = args.startPage; page <= args.endPage; page += 1) {
    let listItems = [];
    try {
      listItems = await fetchArticleList(page, args.perPage);
      console.log(`page ${page}: ${listItems.length}개 글 발견`);
    } catch (error) {
      errors.push(errorPayload("list", error, {page}));
      console.warn(`page ${page}: 목록 수집 실패 - ${error.message}`);
      await sleep(args.delayMs);
      continue;
    }

    for (const listItem of listItems) {
      const articleId = numberValue(listItem.articleId);
      if (!articleId || seenArticleIds.has(articleId)) {
        continue;
      }
      seenArticleIds.add(articleId);

      let detail;
      try {
        detail = await fetchArticleDetail(articleId, page);
      } catch (error) {
        errors.push(errorPayload("article", error, {page, articleId}));
        console.warn(`article ${articleId}: 본문 수집 실패 - ${error.message}`);
        await sleep(args.delayMs);
        continue;
      }

      let rawComments = [];
      const fallbackComments = detailComments(detail.result);
      const expectedCommentCount = numberValue(
        detail.article.commentCount || listItem.commentCount,
      );
      if (expectedCommentCount > 0) {
        try {
          rawComments = await fetchComments(
            articleId,
            page,
            expectedCommentCount,
            args.delayMs,
          );
          rawComments = mergeCommentFallbacks(rawComments, fallbackComments);
        } catch (error) {
          rawComments = fallbackComments;
          errors.push(errorPayload("comments", error, {page, articleId}));
          console.warn(
            [
              `article ${articleId}: 댓글 수집 실패 - ${error.message}`,
              rawComments.length ? "상세 응답의 댓글 일부를 사용합니다." : "",
            ].filter(Boolean).join(" "),
          );
        }
      }

      articles.push(
        normalizeArticle(
          listItem,
          detail.article,
          detail.articleUrl,
          page,
          rawComments,
        ),
      );
      console.log(
        `article ${articleId}: 본문 ok, 댓글 ${rawComments.length}개`,
      );

      if (args.limitArticles > 0 && articles.length >= args.limitArticles) {
        reachedLimit = true;
        break;
      }
      await sleep(args.delayMs);
    }

    if (reachedLimit) break;
    await sleep(args.delayMs);
  }

  const commentCount = articles.reduce(
    (sum, article) => sum + article.comments.length,
    0,
  );
  const output = {
    meta: {
      source: SOURCE,
      cafeId: CAFE_ID,
      menuId: MENU_ID,
      menuName: MENU_NAME,
      startPage: args.startPage,
      endPage: args.endPage,
      perPage: args.perPage,
      fetchedAt: new Date().toISOString(),
      identityPolicy: "anonymized",
      articleCount: articles.length,
      commentCount,
    },
    articles,
    errors,
  };

  await writeJsonAtomic(args.out, output);
  console.log(
    `완료: 글 ${articles.length}개, 댓글 ${commentCount}개, 오류 ${errors.length}개`,
  );
}

run().catch((error) => {
  console.error(error && error.stack ? error.stack : error);
  process.exit(1);
});
