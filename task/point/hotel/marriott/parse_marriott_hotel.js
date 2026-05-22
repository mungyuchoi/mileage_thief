#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..", "..", "..", "..");
const DEFAULT_URL =
  "https://www.marriott.com/ko/hotels/cjuju-jw-marriott-jeju-resort-and-spa/overview/";
const DEFAULT_WARMUP_URL =
  "https://www.marriott.com/search/availabilityCalendar.mi?isRateCalendar=true&propertyCode=CJUJU&isSearch=true&currency=KRW&showFullPrice=false&costTab=total&isAdultsOnly=false&useRewardsPoints=true";
const DEFAULT_OUTPUT = path.join(
  ROOT_DIR,
  "task",
  "point",
  "hotel",
  "marriott",
  "marriott_cjuju_hotel_meta.json",
);
const DEFAULT_CREDENTIALS = path.join(ROOT_DIR, "env", "marriott.json");
const DEFAULT_LOGIN_URL = "https://www.marriott.com/sign-in.mi";
const DEFAULT_PROFILE_DIR = path.join(
  process.env.TMPDIR || "/tmp",
  "marriott-hotel-parser-profile",
);

function parseArgs(argv) {
  const args = {
    url: DEFAULT_URL,
    input: "",
    output: DEFAULT_OUTPUT,
    credentials: DEFAULT_CREDENTIALS,
    fetch: true,
    browserFallback: true,
    login: false,
    loginOn403: true,
    loginUrl: DEFAULT_LOGIN_URL,
    loginTimeoutMs: 45000,
    waitMs: 8000,
    warmupUrl: "",
    warmup: false,
    headful: false,
    profileDir: DEFAULT_PROFILE_DIR,
    cdpUrl: process.env.MARRIOTT_CDP_URL || "",
    chromePath:
      process.env.CHROME_PATH ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    pretty: true,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    const next = () => argv[++i];
    if (item === "--url") args.url = next();
    else if (item === "--input") args.input = path.resolve(next());
    else if (item === "--output") args.output = path.resolve(next());
    else if (item === "--credentials") args.credentials = path.resolve(next());
    else if (item === "--no-fetch") args.fetch = false;
    else if (item === "--fetch-only") args.browserFallback = false;
    else if (item === "--no-browser-fallback") args.browserFallback = false;
    else if (item === "--login") args.login = true;
    else if (item === "--no-login-on-403") args.loginOn403 = false;
    else if (item === "--login-url") args.loginUrl = next();
    else if (item === "--login-timeout-ms") args.loginTimeoutMs = Number(next());
    else if (item === "--wait-ms") args.waitMs = Number(next());
    else if (item === "--warmup-url") args.warmupUrl = next();
    else if (item === "--no-warmup") args.warmup = false;
    else if (item === "--headful") args.headful = true;
    else if (item === "--profile-dir") args.profileDir = path.resolve(next());
    else if (item === "--cdp-url") args.cdpUrl = next();
    else if (item === "--chrome-path") args.chromePath = next();
    else if (item === "--compact") args.pretty = false;
    else if (item === "--help") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${item}`);
    }
  }

  return args;
}

function printHelp() {
  console.log(`Usage:
  node task/point/hotel/marriott/parse_marriott_hotel.js [options]

Options:
  --url URL        Marriott hotel overview URL
  --input PATH     Optional local Marriott hotel HTML. Only used when provided.
  --output PATH    Parsed hotel metadata JSON output
  --credentials PATH
                  Marriott login JSON. Defaults to env/marriott.json
  --no-fetch       Skip direct fetch. Uses --input if provided, otherwise browser.
  --fetch-only     Do not fall back to Playwright after direct fetch failure
  --login          Sign in before browser navigation using env vars
  --no-login-on-403
                  Do not auto-login when direct fetch returns 403
  --login-url URL  Marriott login URL
  --headful        Launch visible Chrome
  --profile-dir PATH
                  Persistent browser profile dir
  --cdp-url URL    Attach to an existing Chrome remote debugging session
  --wait-ms MS     Wait after browser navigation before reading HTML
  --warmup-url URL Optional Marriott page to open before fetching the overview HTML
  --no-warmup      Skip warmup
  --compact        Write compact JSON

Login env vars:
  MARRIOTT_EMAIL
  MARRIOTT_PASSWORD

Credential JSON:
  {
    "email": "your@email.com",
    "memberNumber": "your-member-number",
    "password": "your-password"
  }
`);
}

function decodeHtml(value) {
  if (value == null) return "";
  return String(value)
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/\\x26/g, "&")
    .replace(/\\u0026/g, "&")
    .replace(/\\u002D/g, "-");
}

function cleanText(value) {
  return decodeHtml(value)
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizePhone(value) {
  const raw = cleanText(value);
  if (!raw) return "";
  if (raw.startsWith("+82") && !raw.includes(" ")) {
    const rest = raw.slice(3);
    if (rest.length >= 9) {
      return `+82 ${rest.slice(0, 2)}-${rest.slice(2, 5)}-${rest.slice(5)}`;
    }
  }
  return raw;
}

function getMetaContent(html, selectorName) {
  const escaped = selectorName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const patterns = [
    new RegExp(`<meta\\s+[^>]*(?:property|name)=["']${escaped}["'][^>]*content=["']([^"']*)["'][^>]*>`, "i"),
    new RegExp(`<meta\\s+[^>]*content=["']([^"']*)["'][^>]*(?:property|name)=["']${escaped}["'][^>]*>`, "i"),
  ];
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match) return decodeHtml(match[1]);
  }
  return "";
}

function extractJsonLd(html) {
  const blocks = [];
  const pattern = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  for (const match of html.matchAll(pattern)) {
    const text = decodeHtml(match[1]).trim();
    if (!text) continue;
    try {
      const parsed = JSON.parse(text);
      if (Array.isArray(parsed)) blocks.push(...parsed);
      else blocks.push(parsed);
    } catch (error) {
      blocks.push({ parseError: error.message, rawPreview: text.slice(0, 500) });
    }
  }
  return blocks;
}

function getJsonLdByType(blocks, type) {
  return blocks.find((item) => {
    const rawType = item?.["@type"];
    return Array.isArray(rawType) ? rawType.includes(type) : rawType === type;
  });
}

function extractPropertyCode(html, url) {
  const fromUrl = url.match(/\/hotels\/([a-z0-9]+)-/i)?.[1];
  const patterns = [
    /"prop_marsha_code"\s*:\s*"([^"]+)"/i,
    /"mrshaCode"\s*:\s*"([^"]+)"/i,
    /marshaCode:\s*"([^"]+)"/i,
    /ROOM%3B([A-Z0-9]+)%3B/i,
    /hprid=([A-Z0-9]+)/i,
  ];
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match?.[1]) return match[1].toUpperCase();
  }
  return (fromUrl || "").toUpperCase();
}

function extractPropertyCodeFromUrl(url) {
  return (url.match(/\/hotels\/([a-z0-9]+)-/i)?.[1] || "").toUpperCase();
}

function buildWarmupUrl(args) {
  if (args.warmupUrl) return args.warmupUrl;
  const propertyCode = extractPropertyCodeFromUrl(args.url) || "CJUJU";
  return DEFAULT_WARMUP_URL.replace("propertyCode=CJUJU", `propertyCode=${encodeURIComponent(propertyCode)}`);
}

function inferBrand(name, url, html) {
  const haystack = `${name} ${url} ${html.slice(0, 300000)}`.toLowerCase();
  if (haystack.includes("jw marriott") || haystack.includes("jw 메리어트")) return "JW Marriott";
  if (haystack.includes("le méridien") || haystack.includes("le meridien") || haystack.includes("르메르디앙")) {
    return "Le Meridien";
  }
  if (haystack.includes("westin")) return "Westin";
  if (haystack.includes("sheraton")) return "Sheraton";
  if (haystack.includes("ritz")) return "Ritz-Carlton";
  if (haystack.includes("st. regis")) return "St. Regis";
  if (haystack.includes("marriott")) return "Marriott";
  return "";
}

function inferAmenityKey(title) {
  const text = title.toLowerCase();
  if (/wifi|wi-fi|와이파이/.test(text)) return "wifi";
  if (/수영장|pool/.test(text)) return "pool";
  if (/스파|spa/.test(text)) return "spa";
  if (/피트니스|fitness|gym/.test(text)) return "fitness";
  if (/레스토랑|restaurant|dining/.test(text)) return "restaurant";
  if (/주차|parking/.test(text)) return "parking";
  if (/전기차|ev|충전/.test(text)) return "ev_charging";
  if (/비즈니스/.test(text)) return "business";
  if (/미팅|meeting/.test(text)) return "meeting";
  if (/키즈|어린이|패밀리/.test(text)) return "kids";
  if (/룸 ?서비스|room service/.test(text)) return "room_service";
  if (/모바일 키/.test(text)) return "mobile_key";
  return title
    .toLowerCase()
    .replace(/[^a-z0-9가-힣]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function parseBracketList(text) {
  const bracket = text.match(/\[([^\]]+)\]/)?.[1] || text;
  const listText = bracket.includes(":") ? bracket.slice(bracket.lastIndexOf(":") + 1) : bracket;
  return listText
    .split(/[,;]\s*/)
    .map((item) => cleanText(item).replace(/:+$/g, ""))
    .filter(Boolean);
}

function faqAnswer(faq, keyword) {
  const entities = faq?.mainEntity || [];
  const item = entities.find((entry) => cleanText(entry?.name).includes(keyword));
  return cleanText(item?.acceptedAnswer?.text || "");
}

function faqAnswerAny(faq, keywords) {
  const entities = faq?.mainEntity || [];
  const normalizedKeywords = keywords.map((keyword) => cleanText(keyword).toLowerCase());
  const item = entities.find((entry) => {
    const question = cleanText(entry?.name).toLowerCase();
    return normalizedKeywords.some((keyword) => question.includes(keyword));
  });
  return cleanText(item?.acceptedAnswer?.text || "");
}

function extractGalleryUrls(html, schemaImage, ogImage, propertyCode, limit = 8) {
  const urls = [];
  if (ogImage) urls.push(ogImage);
  if (schemaImage) urls.push(schemaImage);

  const code = propertyCode.toLowerCase();
  const matches = html.matchAll(/https:\/\/cache\.marriott\.com\/[^"'<>\s)]+/g);
  for (const match of matches) {
    const url = decodeHtml(match[0]);
    if (code && !url.toLowerCase().includes(code)) continue;
    if (/logo|coming-soon|pixel|\.gif/i.test(url)) continue;
    if (!/\/is\/image\/marriotts7prod\//i.test(url)) continue;
    if (/Square/i.test(url)) continue;
    urls.push(url);
  }

  const chosen = new Map();
  for (const url of urls) {
    const normalized = normalizeImageUrl(url);
    const key = normalized.split("?")[0].replace(/:(Wide-Hor|Classic-Hor|Pano-Hor|Feature-Hor)$/i, "");
    const old = chosen.get(key);
    if (!old || imageScore(normalized) > imageScore(old)) chosen.set(key, normalized);
  }

  return [...chosen.values()]
    .sort((a, b) => imageScore(b) - imageScore(a))
    .slice(0, limit);
}

function normalizeImageUrl(url) {
  const decoded = decodeHtml(url);
  if (!decoded) return "";
  const [base, query = ""] = decoded.split("?");
  const width =
    base.includes(":Wide-Hor") ? "1336" :
    base.includes(":Classic-Hor") ? "1140" :
    base.includes(":Pano-Hor") ? "1600" :
    base.includes(":Feature-Hor") ? "1920" :
    "1336";
  const fit = query.includes("fit=") ? query.match(/fit=([^&]+)/)?.[1] || "constrain" : "constrain";
  return `${base}?wid=${width}&fit=${fit}`;
}

function imageScore(url) {
  let score = 0;
  if (url.includes(":Wide-Hor")) score += 1000;
  if (url.includes(":Classic-Hor")) score += 900;
  if (url.includes(":Pano-Hor")) score += 800;
  if (url.includes(":Feature-Hor")) score += 700;
  const width = Number(url.match(/[?&]wid=(\d+)/)?.[1] || 0);
  score += Math.min(width, 2000) / 10;
  if (/exterior|lobby|suite|king|pool|dining|restaurant/i.test(url)) score += 50;
  return score;
}

function buildSearchTokens(values) {
  const tokens = new Set();
  for (const value of values) {
    const clean = cleanText(value).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ");
    for (const token of clean.split(/\s+/).filter(Boolean)) {
      if (/^[a-z]$/.test(token)) continue;
      tokens.add(token);
      if (/^[a-z0-9]+$/.test(token)) {
        for (let i = 2; i <= Math.min(token.length, 10); i += 1) {
          tokens.add(token.slice(0, i));
        }
      }
    }
  }
  return [...tokens].slice(0, 80);
}

function titleFromHtml(html) {
  return cleanText(html.match(/<title>([\s\S]*?)<\/title>/i)?.[1] || "");
}

function isAccessDeniedHtml(html) {
  return /<title>\s*Access Denied\s*<\/title>/i.test(html) ||
    /access denied|you don't have permission to access/i.test(cleanText(html).slice(0, 2000));
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function requirePlaywright() {
  try {
    return require("playwright");
  } catch {
    const runnerDir = process.env.MARRIOTT_PLAYWRIGHT_RUNNER_DIR || "/tmp/marriott-playwright-runner";
    const candidate = path.join(runnerDir, "node_modules", "playwright");
    try {
      return require(candidate);
    } catch (error) {
      throw new Error(
        `Playwright is not installed. Install it with: npm --prefix ${runnerDir} install playwright@1.60.0`,
      );
    }
  }
}

function loadCredentials(args) {
  const emailFromEnv = process.env.MARRIOTT_EMAIL || "";
  const passwordFromEnv = process.env.MARRIOTT_PASSWORD || "";
  if (emailFromEnv && passwordFromEnv) {
    return { email: emailFromEnv, password: passwordFromEnv, source: "env" };
  }

  if (!args.credentials || !fs.existsSync(args.credentials)) {
    return { email: "", password: "", source: args.credentials || "" };
  }

  const raw = fs.readFileSync(args.credentials, "utf8");
  const parsed = JSON.parse(raw);
  return {
    email:
      parsed.email ||
      parsed.memberNumber ||
      parsed.membershipNumber ||
      parsed.member_number ||
      parsed.member ||
      parsed.username ||
      parsed.user ||
      "",
    password: parsed.password || parsed.pass || "",
    source: args.credentials,
  };
}

async function fetchHtml(url) {
  const response = await fetch(url, {
    headers: {
      accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "accept-language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
      "user-agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
    },
  });
  const text = await response.text();
  if (!response.ok || isAccessDeniedHtml(text)) {
    const error = new Error(`Fetch failed: status=${response.status} title=${titleFromHtml(text) || "n/a"}`);
    error.status = response.status;
    error.accessDenied = response.status === 403 || isAccessDeniedHtml(text);
    throw error;
  }
  return { html: text, status: response.status };
}

async function loadHtml(args) {
  if (!args.fetch && args.input) {
    return {
      html: fs.readFileSync(args.input, "utf8"),
      source: args.input,
      sourceType: "file",
      status: null,
    };
  }

  let fetchError = null;
  if (args.fetch) {
    try {
      const result = await fetchHtml(args.url);
      return {
        html: result.html,
        source: args.url,
        sourceType: "direct-fetch",
        status: result.status,
      };
    } catch (error) {
      fetchError = error;
      console.warn(`[warn] ${error.message}`);
    }
  }

  if (args.browserFallback) {
    if (
      fetchError?.accessDenied &&
      args.loginOn403 &&
      !args.cdpUrl &&
      (!loadCredentials(args).email || !loadCredentials(args).password)
    ) {
      throw new Error(
        `Marriott returned 403 and login-on-403 is enabled. Set MARRIOTT_EMAIL/MARRIOTT_PASSWORD, create ${args.credentials}, pass --cdp-url for an already signed-in Chrome, or pass --no-login-on-403 to test without login.`,
      );
    }
    return await loadHtmlWithBrowser(args, fetchError);
  }

  if (args.input) {
    console.warn(`[warn] browser fallback disabled; using explicit input=${args.input}`);
    return {
      html: fs.readFileSync(args.input, "utf8"),
      source: args.input,
      sourceType: "file",
      status: null,
    };
  }

  throw fetchError || new Error("No HTML source available. Provide --input or enable browser fallback.");
}

async function firstVisibleLocator(page, selectors, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  let lastError = null;
  while (Date.now() < deadline) {
    for (const selector of selectors) {
      try {
        const locator = page.locator(selector);
        const count = await locator.count();
        for (let index = 0; index < count; index += 1) {
          const item = locator.nth(index);
          if (await item.isVisible()) {
            return item;
          }
        }
      } catch (error) {
        lastError = error;
      }
    }
    await page.waitForTimeout(500);
  }
  throw new Error(
    `No visible selector found: ${selectors.join(", ")}${lastError ? ` (${lastError.message})` : ""}`,
  );
}

async function clickIfVisible(page, selectors, timeoutMs = 3000) {
  for (const selector of selectors) {
    const locator = page.locator(selector).first();
    try {
      await locator.waitFor({ state: "visible", timeout: timeoutMs });
      await locator.click();
      return true;
    } catch {
      // Optional UI such as cookie banners may not exist.
    }
  }
  return false;
}

async function submitLoginForm(page, passwordInput, timeoutMs) {
  const exactSignInButtons = page.getByRole("button", { name: /^Sign In$/i });
  const count = await exactSignInButtons.count();
  for (let i = count - 1; i >= 0; i -= 1) {
    const button = exactSignInButtons.nth(i);
    try {
      if (await button.isVisible()) {
        await button.click();
        return;
      }
    } catch {
      // Try the next matching button.
    }
  }

  try {
    const fallbackButton = await firstVisibleLocator(
      page,
      [
        "button.login-link",
        "button[type='submit']:has-text('Sign In')",
        "button[type='submit']:has-text('로그인')",
        "button:has-text('Sign In')",
        "button:has-text('로그인')",
        "button[aria-label='Sign In']",
        "button[aria-label='로그인']",
        "button[type='submit']",
        "input[type='submit']",
      ],
      Math.min(timeoutMs, 10000),
    );
    await fallbackButton.click();
    return;
  } catch {
    await passwordInput.press("Enter");
  }
}

function loginStatusFromText(text) {
  const lower = text.toLowerCase();
  if (/(captcha|recaptcha|verify you are human|security check)/i.test(text)) return "captcha_or_security_check";
  if (/(verification code|two-step|two factor|2-step|multi-factor|one-time|otp)/i.test(text)) return "mfa_required";
  if (/(incorrect|invalid|try again|does not match|problem signing)/i.test(text)) return "login_error";
  if (/(sign out|my trips|account overview|welcome,|hi,)/i.test(text)) return "possibly_signed_in";
  if (lower.includes("access denied")) return "access_denied";
  return "unknown";
}

async function capturePageDiagnostic(page, outputDir, runStamp, label, extra = {}) {
  const diagnostic = await page.evaluate(() => ({
    url: location.href,
    title: document.title,
    bodyPreview: document.body?.innerText?.slice(0, 1200) || "",
  })).catch((error) => ({ error: error.message }));
  const filePath = path.join(outputDir, `marriott_hotel_page_diagnostic_${label}_${runStamp}.json`);
  writeJson(filePath, { label, ...extra, ...diagnostic });
  console.log(`[diagnostic] ${filePath}`);
  return filePath;
}

async function fetchHtmlInPage(page, url) {
  return await page.evaluate(async (targetUrl) => {
    const response = await fetch(targetUrl, {
      method: "GET",
      credentials: "include",
      headers: {
        accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "accept-language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
      },
    });
    const text = await response.text();
    return {
      ok: response.ok,
      status: response.status,
      statusText: response.statusText,
      url: response.url,
      title: text.match(/<title>([\s\S]*?)<\/title>/i)?.[1] || "",
      body: text,
    };
  }, url);
}

async function signIn(page, args, runStamp) {
  const { email, password, source } = loadCredentials(args);
  if (!email || !password) {
    throw new Error(
      `--login requires MARRIOTT_EMAIL/MARRIOTT_PASSWORD or a credential JSON at ${args.credentials}.`,
    );
  }

  console.log(`[login] credentials=${source}`);
  console.log(`[login] goto=${args.loginUrl}`);
  const loginResponse = await page.goto(args.loginUrl, {
    waitUntil: "domcontentloaded",
    timeout: 90000,
  });
  console.log(`[login] pageStatus=${loginResponse?.status() ?? "n/a"} title=${await page.title()}`);
  await clickIfVisible(page, ["#onetrust-accept-btn-handler", "#onetrust-reject-all-handler"], 2500);

  let emailInput;
  try {
    emailInput = await firstVisibleLocator(
      page,
      [
        "#signin-userid",
        "input[name='userID']",
        "input[name='input-text-Email or Member Number']",
        "input[name='input-text-이메일 또는 멤버 번호']",
        "input[name='username']",
        "input[name='email']",
        "input[type='email']",
        "input[aria-label='email or member number']",
        "input[aria-label='이메일 또는 멤버 번호']",
        "input[id$='-email']",
        "input[autocomplete='username']",
      ],
      args.loginTimeoutMs,
    );
  } catch (error) {
    await capturePageDiagnostic(page, path.dirname(args.output), runStamp, "login_form_missing");
    console.warn(`[login] form not visible; continuing with current browser session (${error.message})`);
    return;
  }
  const passwordInput = await firstVisibleLocator(
    page,
    [
      "#signin-user-password",
      "input[name='input-text-Password']",
      "input[name='input-text-비밀번호']",
      "input[name='password']",
      "input[type='password']",
      "input[aria-label='sign in password']",
      "input[aria-label='로그인 비밀번호']",
      "input[id$='-password']",
      "input[autocomplete='current-password']",
    ],
    args.loginTimeoutMs,
  );

  await emailInput.fill(email);
  await passwordInput.fill(password);

  await Promise.all([
    page.waitForLoadState("networkidle", { timeout: args.loginTimeoutMs }).catch(() => null),
    submitLoginForm(page, passwordInput, args.loginTimeoutMs),
  ]);
  await page.waitForTimeout(5000);

  const loginText = await page.locator("body").innerText({ timeout: 10000 }).catch(() => "");
  const status = loginStatusFromText(loginText);
  await capturePageDiagnostic(page, path.dirname(args.output), runStamp, `login_${status}`);

  if (["captcha_or_security_check", "mfa_required", "login_error", "access_denied"].includes(status)) {
    throw new Error(`Marriott login did not complete automatically: ${status}`);
  }

  console.log(`[login] completed status=${status}`);
}

async function loadHtmlWithBrowser(args, fetchError) {
  const playwright = requirePlaywright();
  const runStamp = new Date().toISOString().replace(/[:.]/g, "-");
  fs.mkdirSync(path.dirname(args.output), { recursive: true });

  let browser = null;
  let context = null;
  let shouldCloseContext = true;
  if (args.cdpUrl) {
    console.log(`[browser] connectOverCDP=${args.cdpUrl}`);
    browser = await playwright.chromium.connectOverCDP(args.cdpUrl);
    context = browser.contexts()[0] || (await browser.newContext());
    shouldCloseContext = false;
  } else {
    console.log(`[browser] profile=${args.profileDir}`);
    console.log(`[browser] headless=${!args.headful}`);
    context = await playwright.chromium.launchPersistentContext(args.profileDir, {
      headless: !args.headful,
      channel: fs.existsSync(args.chromePath) ? undefined : "chrome",
      executablePath: fs.existsSync(args.chromePath) ? args.chromePath : undefined,
      locale: "ko-KR",
      timezoneId: "Asia/Seoul",
      viewport: { width: 1440, height: 1000 },
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36",
      args: ["--disable-blink-features=AutomationControlled"],
    });

    await context.addInitScript(() => {
      Object.defineProperty(navigator, "webdriver", { get: () => undefined });
    });
  }

  const page = await context.newPage();
  try {
    const shouldLogin = args.login || (!args.cdpUrl && args.loginOn403 && fetchError?.accessDenied);
    if (shouldLogin) {
      const credentials = loadCredentials(args);
      if (!credentials.email || !credentials.password) {
        throw new Error(
          `Marriott returned 403 and login-on-403 is enabled. Set MARRIOTT_EMAIL/MARRIOTT_PASSWORD, create ${args.credentials}, pass --cdp-url for an already signed-in Chrome, or pass --no-login-on-403 to test without login.`,
        );
      } else {
        await signIn(page, args, runStamp);
      }
    }

    if (args.warmup) {
      const warmupUrl = buildWarmupUrl(args);
      console.log(`[warmup] ${warmupUrl}`);
      const warmupResponse = await page.goto(warmupUrl, {
        waitUntil: "domcontentloaded",
        timeout: 90000,
      });
      console.log(`[warmup] status=${warmupResponse?.status() ?? "n/a"} title=${await page.title().catch(() => "n/a")}`);
      await page.waitForTimeout(Math.min(args.waitMs, 10000)).catch(() => null);

      if (!page.isClosed()) {
        const fetched = await fetchHtmlInPage(page, args.url).catch((error) => ({
          ok: false,
          status: 0,
          statusText: error.message,
          url: args.url,
          title: "",
          body: "",
        }));
        console.log(`[browser-fetch] status=${fetched.status} title=${cleanText(fetched.title) || "n/a"}`);
        if (fetched.ok && !isAccessDeniedHtml(fetched.body)) {
          return {
            html: fetched.body,
            source: fetched.url || args.url,
            sourceType: args.cdpUrl ? "playwright-cdp-fetch" : "playwright-fetch",
            status: fetched.status,
          };
        }

        await capturePageDiagnostic(
          page,
          path.dirname(args.output),
          runStamp,
          "browser_fetch_failed",
          {
            status: fetched.status,
            statusText: fetched.statusText,
            fetchedUrl: fetched.url,
            fetchedTitle: cleanText(fetched.title),
            bodyPreview: cleanText(fetched.body).slice(0, 1200),
          },
        );
      }
    }

    console.log(`[goto] ${args.url}`);
    const navResponse = await page.goto(args.url, {
      waitUntil: "domcontentloaded",
      timeout: 90000,
    });
    await clickIfVisible(page, ["#onetrust-accept-btn-handler", "#onetrust-reject-all-handler"], 2500);
    if (!page.isClosed()) {
      await page.waitForLoadState("networkidle", { timeout: args.waitMs }).catch(() => null);
    }
    if (!page.isClosed()) {
      await page.waitForTimeout(args.waitMs).catch(() => null);
    }

    if (page.isClosed()) {
      throw new Error("Browser page was closed while navigating to Marriott overview.");
    }

    const title = await page.title();
    const html = await page.content();
    const status = navResponse?.status() ?? null;
    console.log(`[goto] status=${status ?? "n/a"} title=${title}`);

    if (status === 403 || isAccessDeniedHtml(html)) {
      const diagnosticPath = await capturePageDiagnostic(
        page,
        path.dirname(args.output),
        runStamp,
        "access_denied",
        { status },
      );
      throw new Error(`Browser navigation returned Access Denied. diagnostic=${diagnosticPath}`);
    }

    return {
      html,
      source: args.url,
      sourceType: args.cdpUrl ? "playwright-cdp" : "playwright",
      status,
    };
  } finally {
    await page.close({ runBeforeUnload: false }).catch(() => null);
    if (shouldCloseContext) {
      await context.close();
    } else if (browser?.disconnect) {
      browser.disconnect();
    }
  }
}

function parseHotel(html, args, sourceInfo) {
  const jsonLdBlocks = extractJsonLd(html);
  const hotel = getJsonLdByType(jsonLdBlocks, "Hotel") || {};
  const faq = getJsonLdByType(jsonLdBlocks, "FAQPage") || {};
  const propertyCode = extractPropertyCode(html, args.url);
  const name = cleanText(hotel.name || getMetaContent(html, "og:title").split("|")[0]);
  if (!hotel["@type"] || !name) {
    throw new Error(
      `Could not find parseable Hotel JSON-LD. source=${sourceInfo.sourceType} title=${titleFromHtml(html) || "n/a"}`,
    );
  }
  const address = hotel.address || {};
  const street = cleanText(address.streetAddress);
  const city = cleanText(address.addressLocality);
  const country = cleanText(address.addressCountry);
  const postalCode = cleanText(address.postalCode);
  const fullAddress = `${[street, city, country].filter(Boolean).join(", ")}${postalCode ? ` ${postalCode}` : ""}`.trim();
  const latitude = Number((hotel.hasMap || "").match(/query=([0-9.-]+),/)?.[1] || getMetaContent(html, "og:latitude") || NaN);
  const longitude = Number((hotel.hasMap || "").match(/query=[0-9.-]+,([0-9.-]+)/)?.[1] || getMetaContent(html, "og:longitude") || NaN);
  const rating = Number(hotel.aggregateRating?.ratingValue || 0) || null;
  const reviewCount = Number(hotel.aggregateRating?.reviewCount || 0) || null;
  const brand = inferBrand(name, args.url, html);
  const imageUrl = normalizeImageUrl(getMetaContent(html, "og:image") || hotel.image || "");
  const galleryUrls = extractGalleryUrls(html, hotel.image, getMetaContent(html, "og:image"), propertyCode, 8);
  const amenityAnswer = faqAnswerAny(faq, ["편의시설", "amenities"]);
  const amenities = parseBracketList(amenityAnswer).slice(0, 20);
  const parkingAnswer = faqAnswerAny(faq, ["주차", "parking"]);
  const airportAnswer = faqAnswerAny(faq, ["가장 가까운 공항", "closest airport", "nearest airport"]);
  const evAnswer = faqAnswerAny(faq, ["전기차", "electric vehicle", "ev charging"]);
  const petsAnswer = cleanText(hotel.petsAllowed) || faqAnswerAny(faq, ["반려동물", "pets"]);
  const paymentAccepted = Array.isArray(hotel.paymentAccepted)
    ? hotel.paymentAccepted.join(", ")
    : cleanText(hotel.paymentAccepted);

  return {
    hotelId: `marriott_${propertyCode.toLowerCase()}`,
    programId: "marriott",
    loyaltyProgram: "Marriott Bonvoy",
    propertyCode,
    name,
    city,
    country,
    address: fullAddress,
    geo: Number.isFinite(latitude) && Number.isFinite(longitude) ? { lat: latitude, lng: longitude } : null,
    brand,
    officialUrl: cleanText(hotel.url || hotel["@id"] || args.url),
    phone: normalizePhone(hotel.telephone),
    checkInTime: cleanText(hotel.checkinTime),
    checkOutTime: cleanText(hotel.checkoutTime),
    reviewCount,
    rating,
    guestFavorite: rating == null ? false : rating >= 4.5,
    imageUrl,
    galleryUrls,
    mapUrl: cleanText(hotel.hasMap),
    description: cleanText(hotel.description || getMetaContent(html, "description")),
    amenities,
    amenityKeys: [...new Set(amenities.map(inferAmenityKey).filter(Boolean))],
    amenityDetails: amenities.map((title) => ({ title })),
    detailSections: [
      {
        title: "호텔 기본 정보",
        items: [
          { title: "호텔 코드", body: propertyCode },
          { title: "브랜드", body: `${brand} / Marriott Bonvoy` },
          { title: "전화", body: normalizePhone(hotel.telephone) },
          Number.isFinite(latitude) && Number.isFinite(longitude)
            ? { title: "좌표", body: `${latitude}, ${longitude}` }
            : null,
        ].filter(Boolean),
      },
      {
        title: "정책",
        items: [
          hotel.checkinTime || hotel.checkoutTime
            ? { title: "체크인/체크아웃", body: `${cleanText(hotel.checkinTime)} 체크인, ${cleanText(hotel.checkoutTime)} 체크아웃` }
            : null,
          petsAnswer ? { title: "반려동물", body: petsAnswer } : null,
          paymentAccepted ? { title: "결제", body: paymentAccepted } : null,
        ].filter(Boolean),
      },
      {
        title: "주차와 교통",
        items: [
          parkingAnswer ? { title: "주차", body: parkingAnswer } : null,
          evAnswer ? { title: "전기차 충전", body: evAnswer } : null,
          airportAnswer ? { title: "가까운 공항", body: airportAnswer } : null,
        ].filter(Boolean),
      },
    ].filter((section) => section.items.length > 0),
    searchTokens: buildSearchTokens([name, city, country, fullAddress, brand, "marriott", propertyCode]),
    source: {
      type: sourceInfo.sourceType,
      pathOrUrl: sourceInfo.source,
      status: sourceInfo.status,
      parsedAt: new Date().toISOString(),
      jsonLdBlocks: jsonLdBlocks.length,
    },
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const sourceInfo = await loadHtml(args);
  const hotel = parseHotel(sourceInfo.html, args, sourceInfo);

  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  fs.writeFileSync(
    args.output,
    `${JSON.stringify(hotel, null, args.pretty ? 2 : 0)}\n`,
    "utf8",
  );

  console.log(`[source] ${sourceInfo.sourceType}: ${sourceInfo.source}`);
  console.log(`[hotel] ${hotel.hotelId} ${hotel.name}`);
  console.log(`[output] ${args.output}`);
  console.log(
    `[summary] amenities=${hotel.amenities.length} gallery=${hotel.galleryUrls.length} rating=${hotel.rating} reviews=${hotel.reviewCount}`,
  );

  if (args.cdpUrl) {
    process.exit(0);
  }
}

main().catch((error) => {
  console.error(`[error] ${error.stack || error.message}`);
  process.exitCode = 1;
});
