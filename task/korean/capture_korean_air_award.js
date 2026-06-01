#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..", "..");
const DEFAULT_CREDENTIALS = path.join(ROOT_DIR, "env", "korean_air.json");
const DEFAULT_LOGIN_URL = "https://www.koreanair.com/login";
const AWARD_SEAT_VIEW_URL =
  "https://www.koreanair.com/booking/book-and-manage/award-seat-availability";
const AWARD_ENDPOINT = "https://www.koreanair.com/api/hmp/bonusSeatView/bonusSeatView";

const DEFAULT_ROUTES = [
  ["ICN", "PQC"],
  ["ICN", "HKT"],
  ["ICN", "CXR"],
  ["ICN", "LAX"],
  ["ICN", "JFK"],
  ["ICN", "HNL"],
  ["ICN", "BCN"],
  ["ICN", "DPS"],
  ["ICN", "FCO"],
  ["ICN", "CDG"],
  ["ICN", "SYD"],
];

function parseArgs(argv) {
  const args = {
    credentials: DEFAULT_CREDENTIALS,
    output: "",
    rawDir: "",
    routes: [],
    startDate: todayInSeoul(),
    daysAhead: 360,
    timestampKey: "",
    runId: "",
    runSlot: "",
    login: true,
    loginUrl: DEFAULT_LOGIN_URL,
    loginTimeoutMs: 45000,
    waitMs: 4000,
    requestDelayMs: 3000,
    cdpUrl: process.env.KOREAN_AIR_CDP_URL || "",
    profileDir: path.join(process.env.TMPDIR || "/tmp", "korean-air-playwright-profile"),
    chromePath:
      process.env.CHROME_PATH ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    headful: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    const next = () => argv[++i];
    if (item === "--credentials") args.credentials = path.resolve(next());
    else if (item === "--output") args.output = path.resolve(next());
    else if (item === "--raw-dir") args.rawDir = path.resolve(next());
    else if (item === "--route") args.routes.push(parseRoute(next()));
    else if (item === "--routes") {
      for (const route of next().split(",")) {
        if (route.trim()) args.routes.push(parseRoute(route.trim()));
      }
    } else if (item === "--start-date") args.startDate = next();
    else if (item === "--days-ahead") args.daysAhead = Number(next());
    else if (item === "--timestamp-key") args.timestampKey = next();
    else if (item === "--run-id") args.runId = next();
    else if (item === "--run-slot") args.runSlot = next();
    else if (item === "--login") args.login = true;
    else if (item === "--no-login") args.login = false;
    else if (item === "--login-url") args.loginUrl = next();
    else if (item === "--login-timeout-ms") args.loginTimeoutMs = Number(next());
    else if (item === "--wait-ms") args.waitMs = Number(next());
    else if (item === "--request-delay-ms") args.requestDelayMs = Number(next());
    else if (item === "--cdp-url") args.cdpUrl = next();
    else if (item === "--profile-dir") args.profileDir = path.resolve(next());
    else if (item === "--chrome-path") args.chromePath = next();
    else if (item === "--headful") args.headful = true;
    else if (item === "--help") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${item}`);
    }
  }

  validateArgs(args);
  if (args.routes.length === 0) args.routes = DEFAULT_ROUTES.map(([departure, arrival]) => ({ departure, arrival }));
  return args;
}

function printHelp() {
  console.log(`Usage:
  node task/korean/capture_korean_air_award.js [options]

Options:
  --route ICN-PQC                 Route to collect. Can be repeated.
  --routes ICN-PQC,ICN-HKT        Comma-separated route list.
  --start-date YYYY-MM-DD         First date to keep. Defaults to today in Asia/Seoul.
  --days-ahead 360                Last date is start-date + days-ahead.
  --credentials PATH              Defaults to env/korean_air.json.
  --output PATH                   Normalized JSON output path.
  --raw-dir PATH                  Optional raw API response directory.
  --dry-run is handled by the Python uploader, not this capture script.
  --no-login                      Reuse the current CDP browser session without login.
  --cdp-url URL                   Connect to an existing Chrome CDP endpoint.
  --headful                       Use visible browser only when not using CDP.
`);
}

function validateArgs(args) {
  if (!Number.isFinite(args.daysAhead) || args.daysAhead <= 0) {
    throw new Error("--days-ahead must be a positive number");
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(args.startDate)) {
    throw new Error("--start-date must be YYYY-MM-DD");
  }
}

function parseRoute(value) {
  const parts = String(value || "")
    .trim()
    .toUpperCase()
    .split("-")
    .filter(Boolean);
  if (parts.length === 1 && parts[0].length === 3) {
    return { departure: "ICN", arrival: parts[0] };
  }
  if (parts.length !== 2 || parts.some((part) => !/^[A-Z]{3}$/.test(part))) {
    throw new Error(`Invalid route: ${value}. Use ICN-PQC.`);
  }
  return { departure: parts[0], arrival: parts[1] };
}

function todayInSeoul() {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function parseDate(value) {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function formatDate(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function compactDate(value) {
  return value.replaceAll("-", "");
}

function addDays(value, days) {
  const date = parseDate(value);
  date.setUTCDate(date.getUTCDate() + days);
  return formatDate(date);
}

function buildMonthAnchors(startDate, endDateInclusive) {
  const start = parseDate(startDate);
  const end = parseDate(endDateInclusive);
  const anchors = [];
  let year = start.getUTCFullYear();
  let month = start.getUTCMonth();
  const endYear = end.getUTCFullYear();
  const endMonth = end.getUTCMonth();

  while (year < endYear || (year === endYear && month <= endMonth)) {
    const anchor = new Date(Date.UTC(year, month, 16));
    anchors.push(compactDate(formatDate(anchor)));
    month += 1;
    if (month > 11) {
      month = 0;
      year += 1;
    }
  }
  return anchors;
}

function readCredentials(credentialsPath) {
  if (!fs.existsSync(credentialsPath)) {
    throw new Error(
      `Korean Air credential file not found: ${credentialsPath}\n` +
        "Create env/korean_air.json from task/korean/korean_air.example.json.",
    );
  }
  const data = JSON.parse(fs.readFileSync(credentialsPath, "utf8"));
  const traveler = data.traveler || {};
  for (const key of ["userId", "password"]) {
    if (!data[key]) throw new Error(`Missing ${key} in ${credentialsPath}`);
  }
  for (const key of ["fqtvNumber", "lastName", "firstName"]) {
    if (!traveler[key]) throw new Error(`Missing traveler.${key} in ${credentialsPath}`);
  }
  return data;
}

async function clickIfVisible(page, selector, timeout = 1500) {
  try {
    const locator = page.locator(selector).first();
    await locator.waitFor({ state: "visible", timeout });
    await locator.click({ timeout });
    return true;
  } catch {
    return false;
  }
}

async function firstVisibleLocator(page, selectors, timeout = 10000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    for (const selector of selectors) {
      const locator = page.locator(selector);
      const count = await locator.count().catch(() => 0);
      for (let index = 0; index < count; index += 1) {
        const candidate = locator.nth(index);
        if (await candidate.isVisible().catch(() => false)) {
          return candidate;
        }
      }
    }
    await page.waitForTimeout(300);
  }
  throw new Error(`No visible locator found for: ${selectors.join(", ")}`);
}

async function handleCookieConsent(page) {
  await clickIfVisible(page, 'button:has-text("동의합니다")');
  await clickIfVisible(page, 'button:has-text("동의")');
  await clickIfVisible(page, 'button:has-text("Accept")');
}

async function isSignedIn(page) {
  try {
    const status = await page.evaluate(async () => {
      const res = await fetch("/api/li/auth/isUserLoggedIn", { credentials: "include" });
      return res.ok ? await res.json() : null;
    });
    return Boolean(status && status.signinStatus === true);
  } catch {
    return false;
  }
}

async function signIn(page, args, credentials) {
  console.log(`[login] goto=${args.loginUrl}`);
  await page.goto(args.loginUrl, { waitUntil: "load", timeout: 90000 });
  await page.waitForTimeout(args.waitMs);
  await handleCookieConsent(page);

  if (await isSignedIn(page)) {
    console.log("[login] existing session is signed in");
    return;
  }

  const userInput = page.locator('input[type="text"]').first();
  const passwordInput = page.locator('input[type="password"]').first();
  try {
    await userInput.waitFor({ state: "visible", timeout: 30000 });
    await passwordInput.waitFor({ state: "visible", timeout: 30000 });
  } catch {
    const bodyPreview = await page.locator("body").innerText({ timeout: 2000 }).catch(() => "");
    console.log(
      `[login] login form not found after wait; reusing existing browser session. body=${bodyPreview.slice(0, 160)}`,
    );
    return;
  }

  await userInput.fill(credentials.userId);
  await passwordInput.fill(credentials.password);
  const submitButton = await firstVisibleLocator(page, [
    "button.login__submit-act",
    'button[type="submit"]:has-text("로그인")',
    'button:has-text("로그인")',
    'button:has-text("Login")',
  ]);
  await Promise.allSettled([
    page.waitForLoadState("networkidle", { timeout: args.loginTimeoutMs }),
    submitButton.click(),
  ]);
  await page.waitForTimeout(5000);
  console.log(`[login] completed url=${page.url()}`);
}

async function ensureAwardSeatViewPage(page) {
  if (page.url().startsWith(AWARD_SEAT_VIEW_URL)) return;
  console.log(`[goto] ${AWARD_SEAT_VIEW_URL}`);
  await page.goto(AWARD_SEAT_VIEW_URL, { waitUntil: "domcontentloaded", timeout: 90000 });
  await page.waitForTimeout(3000);
}

function valueToText(value) {
  if (value === null || value === undefined) return "";
  if (typeof value === "object") {
    if (value.amount !== undefined) return String(value.amount);
    if (value.value !== undefined) return String(value.value);
    return JSON.stringify(value);
  }
  return String(value);
}

function buildAwardPayload(request) {
  return {
    departureDate: request.anchorDate,
    departureAirport: request.departure,
    arrivalAirport: request.arrival,
  };
}

async function callAwardApi(page, request) {
  const payload = buildAwardPayload(request);
  const response = await page.evaluate(
    async ({ endpoint, body }) => {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          channel: "pc",
        },
        credentials: "include",
        body: JSON.stringify(body),
      });
      const text = await res.text();
      let json = null;
      try {
        json = JSON.parse(text);
      } catch {
        json = null;
      }
      return {
        ok: res.ok,
        status: res.status,
        statusText: res.statusText,
        text,
        json,
      };
    },
    { endpoint: AWARD_ENDPOINT, body: payload },
  );

  if (!response.ok || !response.json) {
    throw new Error(
      `Award API failed route=${request.departure}-${request.arrival} anchor=${request.anchorDate} ` +
        `status=${response.status} ${response.statusText} body=${response.text.slice(0, 240)}`,
    );
  }

  return response.json;
}

function countAvailableByBookingClass(flightDetailList) {
  const counts = {};
  if (!Array.isArray(flightDetailList)) return counts;
  for (const detail of flightDetailList) {
    if (!detail || detail.availableSeat !== true) continue;
    const bookingClass = valueToText(detail.bookingClass).toUpperCase();
    if (!bookingClass) continue;
    counts[bookingClass] = (counts[bookingClass] || 0) + 1;
  }
  return counts;
}

function countToSeatData(count) {
  if (!count) return null;
  return {
    amount: String(count),
    mileage: "",
  };
}

function parseBonusSeatViewResponse(response, request, startKey, endKey) {
  if (!response || !Array.isArray(response.flightList)) {
    throw new Error(`Unexpected response shape for ${request.departure}-${request.arrival}`);
  }

  const entries = [];
  for (const flightDay of response.flightList) {
    const departureDate = valueToText(flightDay.departureDate);
    if (!/^\d{8}$/.test(departureDate)) continue;
    if (departureDate < startKey || departureDate > endKey) continue;

    const availableCounts = countAvailableByBookingClass(flightDay.flightDetailList);
    const entry = {
      departureDate,
      departureAirport: request.departure,
      arrivalAirport: request.arrival,
      direction: request.direction,
    };

    const economy = countToSeatData(availableCounts.X);
    const business = countToSeatData(availableCounts.O);
    const first = countToSeatData(availableCounts.A);
    if (economy) entry.economy = economy;
    if (business) entry.business = business;
    if (first) entry.first = first;

    entries.push(entry);
  }

  return entries;
}

function ensureRouteResult(routeResults, departure, arrival) {
  const key = `${departure}-${arrival}`;
  if (!routeResults[key]) {
    routeResults[key] = {
      routeKey: key,
      departureAirport: departure,
      arrivalAirport: arrival,
      seatsByDate: {},
      entryCount: 0,
      requestCount: 0,
    };
  }
  return routeResults[key];
}

function mergeEntry(routeResults, entry) {
  const result = ensureRouteResult(routeResults, entry.departureAirport, entry.arrivalAirport);
  const dateKey = entry.departureDate;
  const current = result.seatsByDate[dateKey] || {};
  for (const seatClass of ["economy", "business", "first"]) {
    if (entry[seatClass]) current[seatClass] = entry[seatClass];
  }
  result.seatsByDate[dateKey] = current;
  result.entryCount += 1;
}

function buildRequests(args) {
  const endDateInclusive = addDays(args.startDate, args.daysAhead);
  const anchors = buildMonthAnchors(args.startDate, endDateInclusive);
  const requests = [];
  for (const route of args.routes) {
    for (const anchorDate of anchors) {
      requests.push({
        departure: route.departure,
        arrival: route.arrival,
        anchorDate,
        direction: "outbound",
      });
      requests.push({
        departure: route.arrival,
        arrival: route.departure,
        anchorDate,
        direction: "inbound",
      });
    }
  }
  return { requests, endDateInclusive };
}

function safeFileName(value) {
  return String(value).toLowerCase().replace(/[^a-z0-9_-]+/g, "_");
}

function runStamp() {
  const now = new Date();
  const compact = now.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  return {
    runId: `run_${compact.slice(0, 8)}_${compact.slice(9, 15)}`,
    runSlot: compact,
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const credentials = readCredentials(args.credentials);
  const stamp = runStamp();
  const runId = args.runId || stamp.runId;
  const runSlot = args.runSlot || stamp.runSlot;
  const timestampKey = args.timestampKey || runSlot.replace(/\D/g, "").slice(0, 12);
  const outputPath =
    args.output ||
    path.join("/tmp", "korean-air-runs", runSlot, `korean_air_award_${runSlot}.json`);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  if (args.rawDir) fs.mkdirSync(args.rawDir, { recursive: true });

  const { requests, endDateInclusive } = buildRequests(args);
  const startKey = compactDate(args.startDate);
  const endKey = compactDate(endDateInclusive);
  const routeResults = {};
  for (const route of args.routes) {
    ensureRouteResult(routeResults, route.departure, route.arrival);
    ensureRouteResult(routeResults, route.arrival, route.departure);
  }

  let playwright;
  try {
    playwright = require("playwright");
  } catch {
    throw new Error(
      "Playwright is not installed. Use task/korean/run_korean_air_capture.sh or install Playwright.",
    );
  }

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
  let successfulRequestCount = 0;
  let failedRequestCount = 0;

  try {
    if (args.login) {
      await signIn(page, args, credentials);
    }
    await ensureAwardSeatViewPage(page);

    console.log(`[queue] requests=${requests.length} routes=${args.routes.length}`);
    for (let index = 0; index < requests.length; index += 1) {
      const request = requests[index];
      const routeKey = `${request.departure}-${request.arrival}`;
      console.log(`[queue] ${index + 1}/${requests.length} route=${routeKey} anchor=${request.anchorDate}`);
      try {
        const response = await callAwardApi(page, request);
        if (args.rawDir) {
          const rawPath = path.join(
            args.rawDir,
            `${safeFileName(routeKey)}_${request.anchorDate}.json`,
          );
          fs.writeFileSync(rawPath, JSON.stringify(response, null, 2));
        }
        const entries = parseBonusSeatViewResponse(response, request, startKey, endKey);
        ensureRouteResult(routeResults, request.departure, request.arrival).requestCount += 1;
        for (const entry of entries) mergeEntry(routeResults, entry);
        successfulRequestCount += 1;
      } catch (error) {
        failedRequestCount += 1;
        console.error(`[request-failed] ${routeKey} ${request.anchorDate}: ${error.message}`);
        throw error;
      }
      if (index < requests.length - 1 && args.requestDelayMs > 0) {
        await page.waitForTimeout(args.requestDelayMs);
      }
    }
  } finally {
    await page.close().catch(() => {});
    if (shouldCloseContext && context) await context.close().catch(() => {});
    else if (browser?.disconnect) browser.disconnect();
  }

  const output = {
    sourceProvider: "korean_air_bonus_seat_view_api",
    runId,
    runSlot,
    timestampKey,
    startDate: args.startDate,
    endDateInclusive,
    daysAhead: args.daysAhead,
    requestedRoutes: args.routes,
    routeResults,
    stats: {
      requestCount: requests.length,
      successfulRequestCount,
      failedRequestCount,
    },
  };

  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
  console.log(`[output] ${outputPath}`);

  if (args.cdpUrl) {
    process.exit(0);
  }
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exit(1);
});
