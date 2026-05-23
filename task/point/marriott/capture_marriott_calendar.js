#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..", "..", "..");
const DEFAULT_CREDENTIALS = path.join(ROOT_DIR, "env", "marriott.json");
const DEFAULT_LOGIN_URL = "https://www.marriott.com/sign-in.mi";
const ENDPOINT_PATH = "/mi/query/phoenixShopADFSearchProductsByProperty";
const OPERATION_NAME = "phoenixShopADFSearchProductsByProperty";
const DEFAULT_SIGNATURE =
  "887375892e1ad2a43f46a9c95c55ea47cf6eca3af03331c2134f1b440cff3f9f";
const DEFAULT_REQUEST_ID =
  "/search/availabilityCalendar.mi~X~2FBCFF1C-51DD-5603-BB82-0DEAF9897ECF";

const ADF_QUERY = `query phoenixShopADFSearchProductsByProperty($search: CalendarSearchByPropertyInput!, $id: [ID!]!) {
  search {
    calendarSearchByProperty(search: $search) {
      total
      edges {
        node {
          endDate
          startDate
          rateModes {
            lowestAverageRate {
              amount {
                currency
                amount
                decimalPoint
                __typename
              }
              __typename
            }
            pointsPerQuantity {
              points
              __typename
            }
            totalRate {
              amount {
                amount
                currency
                decimalPoint
                __typename
              }
              __typename
            }
            sourceOfRate
            __typename
          }
          __typename
        }
        __typename
      }
      __typename
    }
    __typename
  }
  propertiesByIds(ids: $id) {
    basicInformation {
      isAdultsOnly
      descriptions(
        filter: [RESORT_FEE_DESCRIPTION, DESTINATION_FEE_DESCRIPTION, SURCHARGE_ORDINANCE_COST_DESCRIPTION]
      ) {
        type {
          enumCode
          __typename
        }
        __typename
      }
      resort
      __typename
    }
    __typename
  }
}
`;

function parseArgs(argv) {
  const args = {
    hotelId: "marriott_selmm",
    programId: "marriott",
    propertyId: "SELMM",
    url: "",
    startDate: todayInSeoul(),
    endDate: "",
    daysAhead: 365,
    windowDays: 31,
    windowMode: "month-grid",
    startMonthOffset: 1,
    rooms: 1,
    adults: 1,
    nights: 1,
    modes: ["points", "cash"],
    currency: "KRW",
    output: "",
    rawDir: "",
    credentials: DEFAULT_CREDENTIALS,
    waitMs: 8000,
    requestDelayMs: 1500,
    retryCount: 2,
    retryDelayMs: 15000,
    stopAtBlocked: true,
    login: false,
    loginUrl: DEFAULT_LOGIN_URL,
    loginTimeoutMs: 45000,
    profileDir: path.join(process.env.TMPDIR || "/tmp", "marriott-playwright-profile"),
    cdpUrl: process.env.MARRIOTT_CDP_URL || "",
    chromePath:
      process.env.CHROME_PATH ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    headful: false,
    runId: "",
    runSlot: "",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    const next = () => argv[++i];
    if (item === "--hotel-id") args.hotelId = next();
    else if (item === "--program-id") args.programId = next();
    else if (item === "--property-id") args.propertyId = next();
    else if (item === "--url") args.url = next();
    else if (item === "--start-date") args.startDate = next();
    else if (item === "--end-date") args.endDate = next();
    else if (item === "--days-ahead") args.daysAhead = Number(next());
    else if (item === "--window-days") args.windowDays = Number(next());
    else if (item === "--window-mode") args.windowMode = next();
    else if (item === "--start-month-offset") args.startMonthOffset = Number(next());
    else if (item === "--rooms") args.rooms = Number(next());
    else if (item === "--adults" || item === "--party") args.adults = Number(next());
    else if (item === "--nights" || item === "--days") args.nights = Number(next());
    else if (item === "--modes") args.modes = next().split(",").map((x) => x.trim()).filter(Boolean);
    else if (item === "--currency") args.currency = next();
    else if (item === "--output") args.output = path.resolve(next());
    else if (item === "--raw-dir") args.rawDir = path.resolve(next());
    else if (item === "--credentials") args.credentials = path.resolve(next());
    else if (item === "--wait-ms") args.waitMs = Number(next());
    else if (item === "--request-delay-ms") args.requestDelayMs = Number(next());
    else if (item === "--retry-count") args.retryCount = Number(next());
    else if (item === "--retry-delay-ms") args.retryDelayMs = Number(next());
    else if (item === "--stop-at-blocked") args.stopAtBlocked = true;
    else if (item === "--no-stop-at-blocked") args.stopAtBlocked = false;
    else if (item === "--login") args.login = true;
    else if (item === "--login-url") args.loginUrl = next();
    else if (item === "--login-timeout-ms") args.loginTimeoutMs = Number(next());
    else if (item === "--profile-dir") args.profileDir = path.resolve(next());
    else if (item === "--cdp-url") args.cdpUrl = next();
    else if (item === "--chrome-path") args.chromePath = next();
    else if (item === "--headful") args.headful = true;
    else if (item === "--run-id") args.runId = next();
    else if (item === "--run-slot") args.runSlot = next();
    else if (item === "--help") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${item}`);
    }
  }

  validateArgs(args);
  if (!args.url) args.url = buildAvailabilityUrl(args.propertyId, args.currency);
  return args;
}

function printHelp() {
  console.log(`Usage:
  node task/point/marriott/capture_marriott_calendar.js [options]

Options:
  --hotel-id marriott_selmm        Firestore hotel id for the normalized payload
  --property-id SELMM              Marriott property code
  --url URL                        Marriott availabilityCalendar URL
  --start-date YYYY-MM-DD          First check-in date, inclusive
  --end-date YYYY-MM-DD            End date, exclusive. Overrides --days-ahead
  --days-ahead 365                 Number of check-in dates to collect
  --window-days 31                 Marriott GraphQL request chunk size
  --window-mode month-grid         Use month-grid or rolling request dates
  --start-month-offset 1           Month offset for month-grid mode
  --modes points,cash              Fetch points, cash, or both
  --login                          Sign in before opening the calendar page
  --credentials PATH               Defaults to env/marriott.json
  --cdp-url URL                    Attach to an existing Chrome debugging session
  --output PATH                    Normalized payload JSON path
  --raw-dir PATH                   Optional raw response directory
  --request-delay-ms 1500          Delay between GraphQL requests
  --retry-count 2                  Retries for blocked/temporary responses
  --retry-delay-ms 15000           Delay before retrying blocked/temporary responses
  --no-stop-at-blocked             Keep requesting after 401/403/429 responses
`);
}

function validateArgs(args) {
  if (!/^[A-Z0-9]+$/i.test(args.propertyId)) {
    throw new Error(`Invalid --property-id: ${args.propertyId}`);
  }
  if (!isIsoDate(args.startDate)) {
    throw new Error(`Invalid --start-date: ${args.startDate}`);
  }
  if (args.endDate && !isIsoDate(args.endDate)) {
    throw new Error(`Invalid --end-date: ${args.endDate}`);
  }
  if (!Number.isInteger(args.daysAhead) || args.daysAhead <= 0) {
    throw new Error("--days-ahead must be a positive integer");
  }
  if (!Number.isInteger(args.windowDays) || args.windowDays <= 0 || args.windowDays > 62) {
    throw new Error("--window-days must be between 1 and 62");
  }
  if (!["month-grid", "rolling"].includes(args.windowMode)) {
    throw new Error("--window-mode must be month-grid or rolling");
  }
  if (!Number.isInteger(args.startMonthOffset) || args.startMonthOffset < 0 || args.startMonthOffset > 12) {
    throw new Error("--start-month-offset must be between 0 and 12");
  }
  if (!Number.isInteger(args.requestDelayMs) || args.requestDelayMs < 0) {
    throw new Error("--request-delay-ms must be a non-negative integer");
  }
  if (!Number.isInteger(args.retryCount) || args.retryCount < 0) {
    throw new Error("--retry-count must be a non-negative integer");
  }
  if (!Number.isInteger(args.retryDelayMs) || args.retryDelayMs < 0) {
    throw new Error("--retry-delay-ms must be a non-negative integer");
  }
  const allowedModes = new Set(["points", "cash"]);
  for (const mode of args.modes) {
    if (!allowedModes.has(mode)) throw new Error(`Unsupported mode: ${mode}`);
  }
}

function todayInSeoul() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function buildAvailabilityUrl(propertyId, currency) {
  const params = new URLSearchParams({
    isRateCalendar: "true",
    propertyCode: propertyId.toUpperCase(),
    isSearch: "true",
    currency,
    showFullPrice: "false",
    costTab: "total",
    isAdultsOnly: "false",
    useRewardsPoints: "true",
  });
  return `https://www.marriott.com/search/availabilityCalendar.mi?${params.toString()}`;
}

function isIsoDate(value) {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function parseIsoDate(value) {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function formatIsoDate(date) {
  const year = date.getUTCFullYear();
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const day = String(date.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function addDays(value, days) {
  const date = typeof value === "string" ? parseIsoDate(value) : new Date(value.getTime());
  date.setUTCDate(date.getUTCDate() + days);
  return formatIsoDate(date);
}

function compareIsoDate(a, b) {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}

function minIsoDate(a, b) {
  return compareIsoDate(a, b) <= 0 ? a : b;
}

function maxIsoDate(a, b) {
  return compareIsoDate(a, b) >= 0 ? a : b;
}

function eachDate(startDate, endExclusive) {
  const dates = [];
  for (let cursor = startDate; compareIsoDate(cursor, endExclusive) < 0; cursor = addDays(cursor, 1)) {
    dates.push(cursor);
  }
  return dates;
}

function startOfMonth(value) {
  const date = parseIsoDate(value);
  date.setUTCDate(1);
  return formatIsoDate(date);
}

function addMonths(value, months) {
  const date = parseIsoDate(value);
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() + months);
  return formatIsoDate(date);
}

function lastDayOfMonth(monthStart) {
  return addDays(addMonths(monthStart, 1), -1);
}

function sundayOnOrBefore(value) {
  const date = parseIsoDate(value);
  return addDays(value, -date.getUTCDay());
}

function saturdayOnOrAfter(value) {
  const date = parseIsoDate(value);
  return addDays(value, 6 - date.getUTCDay());
}

function buildRollingWindows(startDate, endExclusive, windowDays) {
  const windows = [];
  for (let cursor = startDate; compareIsoDate(cursor, endExclusive) < 0;) {
    const next = minIsoDate(addDays(cursor, windowDays), endExclusive);
    windows.push({
      startDate: cursor,
      endDate: next,
      apiStartDate: addDays(cursor, -1),
      apiEndDate: addDays(next, -1),
    });
    cursor = next;
  }
  return windows;
}

function buildMonthGridWindows(startDate, endExclusive, startMonthOffset) {
  const windows = [];
  for (
    let monthStart = addMonths(startOfMonth(startDate), startMonthOffset);
    compareIsoDate(monthStart, endExclusive) < 0;
    monthStart = addMonths(monthStart, 1)
  ) {
    const apiStartDate = sundayOnOrBefore(monthStart);
    const apiEndDate = saturdayOnOrAfter(lastDayOfMonth(monthStart));
    const endDate = minIsoDate(addDays(apiEndDate, 1), endExclusive);
    const visibleStartDate = maxIsoDate(apiStartDate, startDate);
    if (compareIsoDate(visibleStartDate, endDate) >= 0) continue;
    windows.push({
      startDate: visibleStartDate,
      endDate,
      apiStartDate,
      apiEndDate,
      calendarMonth: monthStart.slice(0, 7),
    });
  }
  return windows;
}

function buildWindows(startDate, endExclusive, args) {
  if (args.windowMode === "rolling") {
    return buildRollingWindows(startDate, endExclusive, args.windowDays);
  }
  return buildMonthGridWindows(startDate, endExclusive, args.startMonthOffset);
}

function dateKey(date) {
  return `d${date.slice(5, 7)}${date.slice(8, 10)}`;
}

function yearKey(date) {
  return date.slice(0, 4);
}

function runStamp() {
  const now = new Date();
  const runSlot = now.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  const runId = `run_${runSlot.replace("T", "_").replace("Z", "").toLowerCase()}`;
  return { runId, runSlot };
}

function filenameSafe(value) {
  return String(value).replace(/[^a-zA-Z0-9_.-]+/g, "_");
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

  const parsed = JSON.parse(fs.readFileSync(args.credentials, "utf8"));
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
          if (await item.isVisible()) return item;
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
      // Optional UI.
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

async function fillLoginInput(locator, value, label) {
  try {
    await locator.fill(value, { timeout: 10000 });
    return;
  } catch (error) {
    const currentValue = await locator.inputValue().catch(() => "");
    if (currentValue && currentValue.trim() === String(value).trim()) {
      console.log(`[login] ${label} already populated`);
      return;
    }
    await locator.evaluate(
      (element, text) => {
        element.removeAttribute("readonly");
        element.value = text;
        element.dispatchEvent(new Event("input", { bubbles: true }));
        element.dispatchEvent(new Event("change", { bubbles: true }));
      },
      value,
    );
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

async function captureLoginDiagnostic(page, args, stamp, status, extra = {}) {
  const diagnostic = await page.evaluate(() => ({
    url: location.href,
    title: document.title,
    bodyPreview: document.body?.innerText?.slice(0, 1200) || "",
  }));
  const filePath = path.join(
    path.dirname(args.output || path.join(ROOT_DIR, "task", "point", "marriott", "out.json")),
    `marriott_calendar_login_diagnostic_${status}_${stamp.runSlot}.json`,
  );
  writeJson(filePath, { status, ...extra, ...diagnostic });
  console.log(`[login] status=${status} diagnostic=${filePath}`);
}

async function signIn(page, args, stamp) {
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
  const titleAfterGoto = await page.title();
  console.log(`[login] pageStatus=${loginResponse?.status() ?? "n/a"} title=${titleAfterGoto}`);
  await clickIfVisible(page, ["#onetrust-accept-btn-handler", "#onetrust-reject-all-handler"], 2500);
  if (!/(sign[- ]?in|login|account login)/i.test(`${page.url()} ${titleAfterGoto}`)) {
    console.log("[login] sign-in form was not shown; continuing with current browser session");
    return;
  }

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
    await captureLoginDiagnostic(page, args, stamp, "login_form_missing", {
      detail: error.message,
    });
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

  await fillLoginInput(emailInput, email, "member/email");
  await fillLoginInput(passwordInput, password, "password");
  await Promise.all([
    page.waitForLoadState("networkidle", { timeout: args.loginTimeoutMs }).catch(() => null),
    submitLoginForm(page, passwordInput, args.loginTimeoutMs),
  ]);
  await page.waitForTimeout(5000);

  const loginText = await page.locator("body").innerText({ timeout: 10000 }).catch(() => "");
  const status = loginStatusFromText(loginText);
  await captureLoginDiagnostic(page, args, stamp, status);

  if (["captcha_or_security_check", "mfa_required", "login_error", "access_denied"].includes(status)) {
    throw new Error(`Marriott login did not complete automatically: ${status}`);
  }
  console.log(`[login] completed status=${status}`);
}

function buildPayload(args, range, mode) {
  const options = {
    startDate: range.apiStartDate || range.startDate,
    numberOfRooms: args.rooms,
    endDate: range.apiEndDate || range.endDate,
    numberInParty: args.adults,
    numberOfDays: args.nights,
  };
  if (mode === "points") {
    options.rateRequestTypes = [{ type: "REDEMPTION" }];
  } else if (mode === "cash") {
    options.rateRequestTypes = [{ value: "", type: "STANDARD" }];
  }

  return {
    operationName: OPERATION_NAME,
    variables: {
      id: [args.propertyId],
      search: {
        propertyId: args.propertyId,
        options,
      },
    },
    query: ADF_QUERY,
  };
}

function summarizeCalendar(data) {
  const connection = data?.data?.search?.calendarSearchByProperty;
  const edges = connection?.edges || [];
  const first = edges[0]?.node;
  const last = edges[edges.length - 1]?.node;
  return {
    total: connection?.total ?? null,
    edges: edges.length,
    firstDate: first?.startDate ?? null,
    firstPoints: first?.rateModes?.pointsPerQuantity?.points ?? null,
    firstCash:
      first?.rateModes?.totalRate?.amount?.amount ??
      first?.rateModes?.lowestAverageRate?.amount?.amount ??
      null,
    lastDate: last?.startDate ?? null,
    lastPoints: last?.rateModes?.pointsPerQuantity?.points ?? null,
    lastCash:
      last?.rateModes?.totalRate?.amount?.amount ??
      last?.rateModes?.lowestAverageRate?.amount?.amount ??
      null,
  };
}

async function extractPageConfig(page) {
  return await page.evaluate(
    ({ defaultSignature, defaultRequestId, operationName }) => {
      const script = document.querySelector("#__NEXT_DATA__");
      if (!script?.textContent) {
        return {
          found: false,
          title: document.title,
          bodyPreview: document.body?.innerText?.slice(0, 500) || "",
          operationSignature: defaultSignature,
          requestId: defaultRequestId,
        };
      }

      const nextData = JSON.parse(script.textContent);
      const pageProps = nextData?.props?.pageProps || {};
      const signature =
        (pageProps.operationSignatures || []).find(
          (item) => item.operationName === operationName,
        )?.signature || defaultSignature;

      return {
        found: true,
        title: document.title,
        requestId: pageProps.requestId || defaultRequestId,
        operationSignature: signature,
        apolloEnvVars: pageProps.apolloEnvVars || {},
        query: nextData.query || {},
      };
    },
    {
      defaultSignature: DEFAULT_SIGNATURE,
      defaultRequestId: DEFAULT_REQUEST_ID,
      operationName: OPERATION_NAME,
    },
  );
}

async function fetchCalendarInPage(page, payload, pageConfig, referer) {
  return await page.evaluate(
    async ({ endpointPath, payload: requestPayload, pageConfig: config, refererUrl }) => {
      const response = await fetch(endpointPath, {
        method: "POST",
        credentials: "include",
        headers: {
          accept: "*/*",
          "accept-language": "en-US",
          "content-type": "application/json",
          "apollographql-client-name": "phoenix_shop",
          "apollographql-client-version": "v1",
          "application-name": "shop",
          "graphql-operation-name": requestPayload.operationName,
          "graphql-operation-signature": config.operationSignature,
          "graphql-require-safelisting": "true",
          "x-request-id": config.requestId,
          "x-dtreferer": refererUrl,
        },
        body: JSON.stringify(requestPayload),
      });
      const text = await response.text();
      return {
        ok: response.ok,
        status: response.status,
        statusText: response.statusText,
        contentType: response.headers.get("content-type"),
        body: text,
      };
    },
    {
      endpointPath: ENDPOINT_PATH,
      payload,
      pageConfig,
      refererUrl: referer,
    },
  );
}

function shouldRetryFetch(result, parsed) {
  if (!result) return true;
  if ([401, 403, 408, 429, 500, 502, 503, 504].includes(result.status)) return true;
  const message = JSON.stringify(parsed?.errors || "");
  return /token has expired|unauthorized|temporar|try again|rate|blocked/i.test(message);
}

function isBlockedFetch(result, parsed) {
  if (!result) return false;
  if ([401, 403, 429].includes(result.status)) return true;
  const bodyText = typeof result.body === "string" ? result.body : "";
  const message = `${bodyText} ${JSON.stringify(parsed?.errors || "")}`;
  return /access denied|token has expired|unauthorized|rate limit|too many/i.test(message);
}

async function fetchCalendarWithRetry(page, payload, pageConfig, referer, args, range, mode) {
  let lastResult = null;
  let lastParsed = null;
  let lastParseError = null;
  for (let attempt = 0; attempt <= args.retryCount; attempt += 1) {
    if (attempt > 0) {
      console.log(
        `[retry] mode=${mode} range=${range.startDate}_${range.endDate} attempt=${attempt + 1}/${args.retryCount + 1}`,
      );
      await sleep(args.retryDelayMs);
    }

    lastResult = await fetchCalendarInPage(page, payload, pageConfig, referer);
    lastParsed = null;
    lastParseError = null;
    try {
      lastParsed = JSON.parse(lastResult.body);
    } catch (error) {
      lastParseError = error.message;
    }

    const ok = Boolean(lastResult.ok && lastParsed && !lastParsed.errors);
    if (ok || !shouldRetryFetch(lastResult, lastParsed)) {
      return {
        result: lastResult,
        parsed: lastParsed,
        parseError: lastParseError,
        attemptCount: attempt + 1,
      };
    }
  }

  return {
    result: lastResult,
    parsed: lastParsed,
    parseError: lastParseError,
    attemptCount: args.retryCount + 1,
  };
}

function parseNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseInteger(value) {
  const parsed = parseNumber(value);
  if (parsed === null) return null;
  const rounded = Math.round(parsed);
  return rounded > 0 ? rounded : null;
}

function parseAmount(amount) {
  if (!amount) return { value: null, currency: "" };
  const parsed = parseNumber(amount.amount);
  if (parsed === null) return { value: null, currency: amount.currency || "" };
  const decimalPoint = Number(amount.decimalPoint || 0);
  const divisor = decimalPoint > 0 ? 10 ** decimalPoint : 1;
  const value = Math.round(parsed / divisor);
  return {
    value: value > 0 ? value : null,
    currency: amount.currency || "",
  };
}

function parseCalendarEntries(data, mode) {
  const edges = data?.data?.search?.calendarSearchByProperty?.edges || [];
  const entries = [];
  for (const edge of edges) {
    const node = edge?.node || {};
    const startDate = typeof node.startDate === "string" ? node.startDate.slice(0, 10) : "";
    if (!isIsoDate(startDate)) continue;
    const rateModes = node.rateModes || {};
    if (mode === "points") {
      const points = parseInteger(rateModes.pointsPerQuantity?.points);
      if (points) entries.push({ date: startDate, points });
    } else if (mode === "cash") {
      const amount =
        rateModes.totalRate?.amount ||
        rateModes.lowestAverageRate?.amount ||
        null;
      const cash = parseAmount(amount);
      if (cash.value) {
        entries.push({ date: startDate, cash: cash.value, currency: cash.currency });
      }
    }
  }
  return entries;
}

function mergeEntries(entriesByDate, parsed, mode) {
  const parsedEntries = parseCalendarEntries(parsed, mode);
  for (const entry of parsedEntries) {
    const current = entriesByDate.get(entry.date) || {
      date: entry.date,
      points: null,
      cash: null,
      currency: "",
    };
    if (mode === "points") current.points = entry.points;
    if (mode === "cash") {
      current.cash = entry.cash;
      current.currency = entry.currency || current.currency;
    }
    entriesByDate.set(entry.date, current);
  }
  return parsedEntries.length;
}

function buildYears(args, entriesByDate, startDate, endExclusive) {
  const years = {};
  let awardCount = 0;
  let cashCount = 0;

  for (const date of eachDate(startDate, endExclusive)) {
    const entry = entriesByDate.get(date) || {};
    const points = parseInteger(entry.points);
    const cash = parseInteger(entry.cash);
    if (points) awardCount += 1;
    if (cash) cashCount += 1;
    const day = {
      a: Boolean(points),
      p: points,
      c: cash,
    };
    if (points && cash) day.v = Number((cash / points).toFixed(2));

    const y = yearKey(date);
    if (!years[y]) years[y] = {};
    years[y][dateKey(date)] = day;
  }

  return { years, awardCount, cashCount };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  let playwright;
  try {
    playwright = require("playwright");
  } catch {
    throw new Error(
      "Playwright is not installed. Use task/point/marriott/run_marriott_calendar_capture.sh or install Playwright.",
    );
  }

  const stamp = runStamp();
  const runId = args.runId || stamp.runId;
  const runSlot = args.runSlot || stamp.runSlot;
  const endExclusive = args.endDate || addDays(args.startDate, args.daysAhead);
  const outputPath =
    args.output ||
    path.join(
      ROOT_DIR,
      "task",
      "point",
      "marriott",
      "output",
      `marriott_calendar_${filenameSafe(args.propertyId.toLowerCase())}_${runSlot}.json`,
    );
  const rawDir = args.rawDir || "";

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  if (rawDir) fs.mkdirSync(rawDir, { recursive: true });

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
      locale: "en-US",
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
  const requests = [];
  const entriesByDate = new Map();
  let successfulFetches = 0;
  let failedFetches = 0;
  let nonBlockedFailureCount = 0;
  let blockedAt = "";
  let blockedSummary = null;
  const blockedModes = new Map();
  const blockedSummariesByMode = {};

  try {
    if (args.login) {
      await signIn(page, args, { runId, runSlot });
    }

    console.log(`[goto] ${args.url}`);
    const navResponse = await page.goto(args.url, {
      waitUntil: "domcontentloaded",
      timeout: 90000,
    });
    console.log(`[goto] status=${navResponse?.status() ?? "n/a"} title=${await page.title()}`);
    await page.waitForTimeout(args.waitMs);

    const pageConfig = await extractPageConfig(page);
    console.log(
      `[page-config] found=${pageConfig.found} requestId=${pageConfig.requestId} signature=${pageConfig.operationSignature}`,
    );

    const windows = buildWindows(args.startDate, endExclusive, args);
    const observedStartDate = windows[0]?.startDate || args.startDate;
    let effectiveEndExclusive = observedStartDate;
    windowLoop:
    for (const range of windows) {
      let activeModeCount = 0;
      for (const mode of args.modes) {
        if (blockedModes.has(mode)) continue;
        activeModeCount += 1;
        const payload = buildPayload(args, range, mode);
        const { result, parsed, parseError, attemptCount } = await fetchCalendarWithRetry(
          page,
          payload,
          pageConfig,
          args.url,
          args,
          range,
          mode,
        );

        const ok = Boolean(result.ok && parsed && !parsed.errors);
        const blocked = !ok && args.stopAtBlocked && isBlockedFetch(result, parsed);
        if (ok) successfulFetches += 1;
        else {
          failedFetches += 1;
          if (!blocked) nonBlockedFailureCount += 1;
        }

        const parsedEntryCount = ok ? mergeEntries(entriesByDate, parsed, mode) : 0;
        if (ok) {
          effectiveEndExclusive = maxIsoDate(effectiveEndExclusive, range.endDate);
        }
        const summary = parsed ? summarizeCalendar(parsed) : null;
        const requestSummary = {
          mode,
          startDate: range.startDate,
          endDate: range.endDate,
          apiStartDate: range.apiStartDate,
          apiEndDate: range.apiEndDate,
          calendarMonth: range.calendarMonth || null,
          status: result.status,
          ok,
          contentType: result.contentType,
          parseError,
          attemptCount,
          parsedEntryCount,
          summary,
          errorCount: parsed?.errors?.length || 0,
        };
        requests.push(requestSummary);
        console.log(
          `[fetch] mode=${mode} range=${range.startDate}_${range.endDate} api=${range.apiStartDate}_${range.apiEndDate} status=${result.status} ok=${ok} entries=${parsedEntryCount}`,
        );

        if (rawDir) {
          const rawPath = path.join(
            rawDir,
            `marriott_${args.propertyId.toLowerCase()}_${mode}_${range.apiStartDate}_${range.apiEndDate}.json`,
          );
          writeJson(rawPath, {
            ...requestSummary,
            payload,
            body: parsed || result.body.slice(0, 4000),
          });
        }
        if (args.requestDelayMs > 0) {
          await sleep(args.requestDelayMs);
        }
        if (blocked) {
          blockedModes.set(mode, range.startDate);
          blockedSummariesByMode[mode] = requestSummary;
          if (!blockedAt) {
            blockedAt = range.startDate;
            blockedSummary = requestSummary;
          }
          console.log(`[blocked] mode=${mode} stopping that mode before range=${range.startDate}_${range.endDate}`);
          if (mode === "points" && args.modes.includes("points")) {
            console.log(`[blocked] primary points mode blocked before range=${range.startDate}_${range.endDate}`);
            break windowLoop;
          }
          if (blockedModes.size >= args.modes.length) {
            console.log(`[blocked] all modes blocked before range=${range.startDate}_${range.endDate}`);
            break windowLoop;
          }
        }
      }
      if (activeModeCount === 0) break;
    }

    const hasObservedRange = compareIsoDate(observedStartDate, effectiveEndExclusive) < 0;
    const normalized = hasObservedRange
      ? buildYears(args, entriesByDate, observedStartDate, effectiveEndExclusive)
      : { years: {}, awardCount: 0, cashCount: 0 };
    const payload = {
      runId,
      runSlot,
      sourceProvider: "marriott_adf",
      hotelId: args.hotelId,
      programId: args.programId,
      propertyCode: args.propertyId.toUpperCase(),
      occupancyKey: `r${args.rooms}_a${args.adults}`,
      rooms: args.rooms,
      adults: args.adults,
      nights: args.nights,
      currency: args.currency,
      rangeStart: observedStartDate,
      rangeEnd: hasObservedRange ? addDays(effectiveEndExclusive, -1) : "",
      rangeEndExclusive: effectiveEndExclusive,
      requestedRangeEnd: addDays(endExclusive, -1),
      requestedRangeEndExclusive: endExclusive,
      truncated: blockedModes.size > 0,
      blockedAt: blockedAt || null,
      blockedByMode: Object.fromEntries(blockedModes),
      years: normalized.years,
      fetchSummary: {
        url: args.url,
        windowDays: args.windowDays,
        windowMode: args.windowMode,
        startMonthOffset: args.startMonthOffset,
        stopAtBlocked: args.stopAtBlocked,
        requestCount: requests.length,
        successfulFetches,
        failedFetches,
        nonBlockedFailureCount,
        blockedSummary,
        blockedByMode: Object.fromEntries(blockedModes),
        blockedSummariesByMode,
        awardDateCount: normalized.awardCount,
        cashDateCount: normalized.cashCount,
        requests,
      },
    };

    writeJson(outputPath, payload);
    console.log(`[output] ${outputPath}`);
    console.log(
      `[summary] requests=${requests.length} success=${successfulFetches} failed=${failedFetches} range=${observedStartDate}_${effectiveEndExclusive} truncated=${blockedModes.size > 0} awardDates=${normalized.awardCount} cashDates=${normalized.cashCount}`,
    );

    if (successfulFetches === 0 || !hasObservedRange || nonBlockedFailureCount > 0) {
      process.exitCode = 2;
    }
  } finally {
    await page.close({ runBeforeUnload: false }).catch(() => null);
    if (shouldCloseContext) {
      await context.close();
    } else if (browser?.disconnect) {
      browser.disconnect();
    }
  }

  if (args.cdpUrl) {
    process.exit(process.exitCode || 0);
  }
}

main().catch((error) => {
  console.error(`[error] ${error.stack || error.message}`);
  process.exit(1);
});
