#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const ROOT_DIR = path.resolve(__dirname, "..", "..");
const OUT_DIR = path.join(ROOT_DIR, "task", "point");
const DEFAULT_URL =
  "https://www.marriott.com/search/availabilityCalendar.mi?isRateCalendar=true&propertyCode=SELMM&isSearch=true&currency=KRW&showFullPrice=false&costTab=total&isAdultsOnly=false&useRewardsPoints=true";
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
    url: DEFAULT_URL,
    propertyId: "SELMM",
    startDate: "2026-05-22",
    endDate: "2026-07-02",
    nextStartDate: "2026-07-01",
    nextEndDate: "2026-08-01",
    rooms: 1,
    party: 2,
    days: 1,
    modes: ["points", "cash"],
    outputDir: OUT_DIR,
    waitMs: 20000,
    login: false,
    loginUrl: DEFAULT_LOGIN_URL,
    loginTimeoutMs: 45000,
    headful: false,
    profileDir: path.join(process.env.TMPDIR || "/tmp", "marriott-playwright-profile"),
    cdpUrl: process.env.MARRIOTT_CDP_URL || "",
    chromePath:
      process.env.CHROME_PATH ||
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const item = argv[i];
    const next = () => argv[++i];
    if (item === "--url") args.url = next();
    else if (item === "--property-id") args.propertyId = next();
    else if (item === "--start-date") args.startDate = next();
    else if (item === "--end-date") args.endDate = next();
    else if (item === "--next-start-date") args.nextStartDate = next();
    else if (item === "--next-end-date") args.nextEndDate = next();
    else if (item === "--rooms") args.rooms = Number(next());
    else if (item === "--party") args.party = Number(next());
    else if (item === "--days") args.days = Number(next());
    else if (item === "--modes") args.modes = next().split(",").map((x) => x.trim()).filter(Boolean);
    else if (item === "--output-dir") args.outputDir = path.resolve(next());
    else if (item === "--wait-ms") args.waitMs = Number(next());
    else if (item === "--login") args.login = true;
    else if (item === "--login-url") args.loginUrl = next();
    else if (item === "--login-timeout-ms") args.loginTimeoutMs = Number(next());
    else if (item === "--profile-dir") args.profileDir = path.resolve(next());
    else if (item === "--cdp-url") args.cdpUrl = next();
    else if (item === "--chrome-path") args.chromePath = next();
    else if (item === "--headful") args.headful = true;
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
  node task/point/test_marriott_playwright_capture.js [options]

Options:
  --url URL                       Marriott availabilityCalendar URL
  --property-id SELMM             Marriott property id
  --start-date YYYY-MM-DD         First manual GraphQL range start
  --end-date YYYY-MM-DD           First manual GraphQL range end
  --next-start-date YYYY-MM-DD    Second manual GraphQL range start
  --next-end-date YYYY-MM-DD      Second manual GraphQL range end
  --modes points,cash             Fetch points, cash, or both
  --login                         Sign in first using MARRIOTT_EMAIL and MARRIOTT_PASSWORD env vars
  --login-url URL                 Marriott login URL
  --login-timeout-ms MS           Login wait timeout
  --headful                       Launch visible Chrome
  --profile-dir PATH              Persistent browser profile dir
  --cdp-url URL                   Attach to an existing Chrome remote debugging session
  --output-dir PATH               JSON output directory
`);
}

async function firstVisibleLocator(page, selectors, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  let lastError = null;
  while (Date.now() < deadline) {
    for (const selector of selectors) {
      const locator = page.locator(selector).first();
      try {
        if ((await locator.count()) > 0 && (await locator.isVisible())) {
          return locator;
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
      // Ignore optional UI such as cookie banners.
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
        "button:has-text('Sign In')",
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

async function captureLoginDiagnostic(page, args, runStamp, status, extra = {}) {
  const diagnostic = await page.evaluate(() => ({
    url: location.href,
    title: document.title,
    bodyPreview: document.body?.innerText?.slice(0, 1200) || "",
  }));
  const filePath = path.join(args.outputDir, `marriott_login_diagnostic_${status}_${runStamp}.json`);
  writeJson(filePath, { status, ...extra, ...diagnostic });
  console.log(`[login] status=${status} diagnostic=${filePath}`);
  return filePath;
}

async function signIn(page, args, runStamp) {
  const email = process.env.MARRIOTT_EMAIL || "";
  const password = process.env.MARRIOTT_PASSWORD || "";
  if (!email || !password) {
    throw new Error("--login requires MARRIOTT_EMAIL and MARRIOTT_PASSWORD environment variables.");
  }

  console.log(`[login] goto=${args.loginUrl}`);
  const loginResponse = await page.goto(args.loginUrl, {
    waitUntil: "domcontentloaded",
    timeout: 90000,
  });
  console.log(`[login] pageStatus=${loginResponse?.status() ?? "n/a"} title=${await page.title()}`);
  await clickIfVisible(page, ["#onetrust-accept-btn-handler", "#onetrust-reject-all-handler"], 2500);

  const emailInput = await firstVisibleLocator(
    page,
    [
      "#signin-userid",
      "input[name='userID']",
      "input[name='input-text-Email or Member Number']",
      "input[name='username']",
      "input[name='email']",
      "input[type='email']",
      "input[aria-label='email or member number']",
      "input[id$='-email']",
      "input[autocomplete='username']",
    ],
    args.loginTimeoutMs,
  );
  const passwordInput = await firstVisibleLocator(
    page,
    [
      "#signin-user-password",
      "input[name='input-text-Password']",
      "input[name='password']",
      "input[type='password']",
      "input[aria-label='sign in password']",
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
  await captureLoginDiagnostic(page, args, runStamp, status);

  if (["captcha_or_security_check", "mfa_required", "login_error", "access_denied"].includes(status)) {
    throw new Error(`Marriott login did not complete automatically: ${status}`);
  }

  console.log(`[login] completed status=${status}`);
}

function buildPayload(args, range, mode) {
  const options = {
    startDate: range.startDate,
    numberOfRooms: args.rooms,
    endDate: range.endDate,
    numberInParty: args.party,
    numberOfDays: args.days,
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

function filenameSafe(value) {
  return String(value).replace(/[^a-zA-Z0-9_.-]+/g, "_");
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
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

async function main() {
  const args = parseArgs(process.argv.slice(2));
  let playwright;
  try {
    playwright = require("playwright");
  } catch (error) {
    throw new Error(
      "Playwright is not installed. Run this with NODE_PATH pointing to a Playwright install, or install it locally.",
    );
  }

  fs.mkdirSync(args.outputDir, { recursive: true });
  const capturedResponses = [];
  let successfulFetches = 0;
  const runStamp = new Date().toISOString().replace(/[:.]/g, "-");

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
  page.on("response", async (response) => {
    if (!response.url().includes(ENDPOINT_PATH)) return;
    const status = response.status();
    const request = response.request();
    const postData = request.postData();
    let body = "";
    let parsed = null;
    let parseError = null;
    try {
      body = await response.text();
      parsed = JSON.parse(body);
    } catch (error) {
      parseError = error.message;
    }

    const index = capturedResponses.length + 1;
    const filePrefix = parsed && status >= 200 && status < 300
      ? "marriott_playwright_captured"
      : "marriott_playwright_error_captured";
    const filePath = path.join(
      args.outputDir,
      `${filePrefix}_${runStamp}_${String(index).padStart(2, "0")}.json`,
    );
    writeJson(filePath, {
      url: response.url(),
      status,
      method: request.method(),
      postData,
      parseError,
      summary: parsed ? summarizeCalendar(parsed) : null,
      body: parsed || body.slice(0, 2000),
    });
    capturedResponses.push({ status, filePath, summary: parsed ? summarizeCalendar(parsed) : null });
    console.log(`[capture] status=${status} wrote=${filePath}`);
  });

  try {
    if (args.login) {
      await signIn(page, args, runStamp);
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
    if (!pageConfig.found) {
      const diagnosticPath = path.join(args.outputDir, `marriott_playwright_page_diagnostic_${runStamp}.json`);
      writeJson(diagnosticPath, pageConfig);
      console.log(`[page-config] diagnostic=${diagnosticPath}`);
    }

    const ranges = [
      { label: "initial", startDate: args.startDate, endDate: args.endDate },
      { label: "next", startDate: args.nextStartDate, endDate: args.nextEndDate },
    ];

    for (const range of ranges) {
      for (const mode of args.modes) {
        const payload = buildPayload(args, range, mode);
        const result = await fetchCalendarInPage(page, payload, pageConfig, args.url);
        let parsed = null;
        let parseError = null;
        try {
          parsed = JSON.parse(result.body);
        } catch (error) {
          parseError = error.message;
        }

        const outputName =
          parsed && result.ok && !parsed.errors
            ? `marriott_playwright_${args.propertyId.toLowerCase()}_${mode}_${range.startDate}_${range.endDate}.json`
            : `marriott_playwright_error_${args.propertyId.toLowerCase()}_${mode}_${range.startDate}_${range.endDate}_${runStamp}.json`;
        const outputPath = path.join(args.outputDir, outputName);

        writeJson(outputPath, {
          label: range.label,
          mode,
          status: result.status,
          ok: result.ok,
          contentType: result.contentType,
          parseError,
          payload,
          summary: parsed ? summarizeCalendar(parsed) : null,
          body: parsed || result.body.slice(0, 2000),
        });
        console.log(
          `[manual-fetch] mode=${mode} range=${range.startDate}_${range.endDate} status=${result.status} wrote=${outputPath}`,
        );
        if (parsed) {
          console.log(`[manual-fetch] summary=${JSON.stringify(summarizeCalendar(parsed))}`);
          if (result.ok && !parsed.errors) successfulFetches += 1;
        } else {
          console.log(`[manual-fetch] parseError=${parseError}`);
        }
      }
    }

    console.log(`[capture] responses=${capturedResponses.length}`);
    if (successfulFetches === 0 && !capturedResponses.some((item) => item.status >= 200 && item.status < 300)) {
      process.exitCode = 2;
      console.log("[result] no successful Marriott JSON response was captured or fetched.");
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
  process.exitCode = 1;
});
