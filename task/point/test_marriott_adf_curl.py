from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[2]
DEFAULT_FIXTURE = ROOT_DIR / "docs" / "hotel" / "phoenixShopADFSearchProductsByProperty.txt"
DEFAULT_ENDPOINT = "https://www.marriott.com/mi/query/phoenixShopADFSearchProductsByProperty"
DEFAULT_REFERER = (
    "https://www.marriott.com/search/availabilityCalendar.mi?"
    "isRateCalendar=true&propertyCode=SELMM&isSearch=true&currency=KRW&"
    "showFullPrice=false&costTab=total&isAdultsOnly=false&useRewardsPoints=true"
)
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/148.0.0.0 Safari/537.36"
)
DEFAULT_REQUEST_ID = "/search/availabilityCalendar.mi~X~2FBCFF1C-51DD-5603-BB82-0DEAF9897ECF"
DEFAULT_OPERATION_SIGNATURE = "887375892e1ad2a43f46a9c95c55ea47cf6eca3af03331c2134f1b440cff3f9f"


ADF_QUERY = """query phoenixShopADFSearchProductsByProperty($search: CalendarSearchByPropertyInput!, $id: [ID!]!) {
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
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Test Marriott ADF calendar GraphQL with curl and print whether the "
            "response is valid JSON."
        ),
    )
    parser.add_argument("--property-id", default="SELMM", help="Marriott property id.")
    parser.add_argument("--start-date", default="2026-05-22", help="Calendar start date.")
    parser.add_argument("--end-date", default="2026-07-02", help="Calendar end date.")
    parser.add_argument("--rooms", type=int, default=1, help="numberOfRooms value.")
    parser.add_argument("--party", type=int, default=2, help="numberInParty value.")
    parser.add_argument("--days", type=int, default=1, help="numberOfDays value.")
    parser.add_argument("--endpoint", default=DEFAULT_ENDPOINT, help="GraphQL endpoint.")
    parser.add_argument("--referer", default=DEFAULT_REFERER, help="Marriott page referer.")
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT, help="curl User-Agent.")
    parser.add_argument(
        "--cookie",
        default=os.environ.get("MARRIOTT_COOKIE"),
        help=(
            "Optional Cookie header value copied from a browser session. "
            "Can also be provided with MARRIOTT_COOKIE env var. "
            "Useful when Marriott/Akamai blocks stock curl."
        ),
    )
    parser.add_argument(
        "--header",
        action="append",
        default=[],
        help="Extra curl header. Repeatable. Example: --header 'x-request-id: ...'",
    )
    parser.add_argument(
        "--no-warmup",
        action="store_true",
        help="Skip the overview-page GET before the GraphQL POST.",
    )
    parser.add_argument(
        "--no-browser-headers",
        action="store_true",
        help="Skip Apollo/safelisting/sec-* headers copied from the browser request.",
    )
    parser.add_argument(
        "--request-id",
        default=DEFAULT_REQUEST_ID,
        help="x-request-id value copied from a successful browser request.",
    )
    parser.add_argument(
        "--operation-signature",
        default=DEFAULT_OPERATION_SIGNATURE,
        help="graphql-operation-signature copied from a successful browser request.",
    )
    parser.add_argument(
        "--fixture",
        default=str(DEFAULT_FIXTURE),
        help="Saved JSON fixture used only for local summary comparison.",
    )
    parser.add_argument("--output", help="Write raw response body to this file.")
    parser.add_argument("--verbose", action="store_true", help="Print the curl command.")
    return parser.parse_args()


def build_payload(args: argparse.Namespace) -> dict[str, Any]:
    return {
        "operationName": "phoenixShopADFSearchProductsByProperty",
        "variables": {
            "id": [args.property_id],
            "search": {
                "propertyId": args.property_id,
                "options": {
                    "startDate": args.start_date,
                    "numberOfRooms": args.rooms,
                    "rateRequestTypes": [{"type": "REDEMPTION"}],
                    "endDate": args.end_date,
                    "numberInParty": args.party,
                    "numberOfDays": args.days,
                },
            },
        },
        "query": ADF_QUERY,
    }


def run_curl(cmd: list[str], verbose: bool) -> subprocess.CompletedProcess[str]:
    if verbose:
        redacted = [
            "[REDACTED_COOKIE]" if part.lower().startswith("cookie: ") else part
            for part in cmd
        ]
        print("$ " + " ".join(redacted))
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def split_body_and_status(stdout: str) -> tuple[str, int | None]:
    marker = "\nHTTP_STATUS:"
    if marker not in stdout:
        return stdout, None

    body, raw_status = stdout.rsplit(marker, 1)
    match = re.search(r"(\d{3})", raw_status)
    return body, int(match.group(1)) if match else None


def calendar_connection(data: dict[str, Any]) -> dict[str, Any]:
    return data["data"]["search"]["calendarSearchByProperty"]


def summarize_calendar(data: dict[str, Any], label: str) -> None:
    connection = calendar_connection(data)
    edges = connection.get("edges") or []
    print(f"[{label}] total={connection.get('total')} edges={len(edges)}")
    if not edges:
        return

    first = edges[0]["node"]
    last = edges[-1]["node"]
    first_points = points_from_node(first)
    last_points = points_from_node(last)
    print(
        f"[{label}] first={first.get('startDate')} points={first_points} "
        f"last={last.get('startDate')} points={last_points}"
    )


def points_from_node(node: dict[str, Any]) -> int | None:
    points = (
        (node.get("rateModes") or {})
        .get("pointsPerQuantity") or {}
    ).get("points")
    return points if isinstance(points, int) else None


def load_fixture(path: str) -> dict[str, Any] | None:
    fixture = Path(path)
    if not fixture.exists():
        print(f"[fixture] not found: {fixture}")
        return None

    try:
        return json.loads(fixture.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"[fixture] invalid JSON: {exc}")
        return None


def print_non_json_diagnostic(body: str, status: int | None) -> None:
    trimmed = body.strip()
    print(f"[remote] status={status} JSON parse failed")
    if "Access Denied" in trimmed:
        print("[remote] Marriott/Akamai returned Access Denied. Browser cookies or a real browser TLS fingerprint may be required.")
    print("[remote] body preview:")
    print(trimmed[:800] or "(empty body)")


def main() -> int:
    args = parse_args()
    payload = build_payload(args)
    payload_json = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)

    fixture_data = load_fixture(args.fixture)
    if fixture_data:
        summarize_calendar(fixture_data, "fixture")

    with tempfile.TemporaryDirectory(prefix="marriott_adf_curl_") as tmp_dir:
        cookie_jar = str(Path(tmp_dir) / "cookies.txt")

        if not args.no_warmup:
            warmup_cmd = [
                "curl",
                "--silent",
                "--show-error",
                "--location",
                "--max-time",
                "30",
                "--cookie-jar",
                cookie_jar,
                "--cookie",
                cookie_jar,
                "-H",
                f"user-agent: {args.user_agent}",
                "-H",
                "accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "-H",
                "accept-language: ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
                args.referer,
            ]
            warmup = run_curl(warmup_cmd, args.verbose)
            if warmup.returncode != 0:
                print(f"[warmup] curl failed: {warmup.stderr.strip()}")
            else:
                print(f"[warmup] ok bytes={len(warmup.stdout)}")

        post_cmd = [
            "curl",
            "--silent",
            "--show-error",
            "--location",
            "--max-time",
            "30",
            "--cookie-jar",
            cookie_jar,
            "--cookie",
            cookie_jar,
            "--write-out",
            "\nHTTP_STATUS:%{http_code}\n",
            args.endpoint,
            "-H",
            f"user-agent: {args.user_agent}",
            "-H",
            "accept: */*",
            "-H",
            "accept-language: en-US",
            "-H",
            "content-type: application/json",
            "-H",
            "origin: https://www.marriott.com",
            "-H",
            f"referer: {args.referer}",
        ]

        if not args.no_browser_headers:
            browser_headers = [
                ("apollographql-client-name", "phoenix_shop"),
                ("apollographql-client-version", "v1"),
                ("application-name", "shop"),
                ("graphql-operation-name", "phoenixShopADFSearchProductsByProperty"),
                ("graphql-operation-signature", args.operation_signature),
                ("graphql-require-safelisting", "true"),
                ("priority", "u=1, i"),
                ("sec-ch-ua", '"Chromium";v="148", "Google Chrome";v="148", "Not/A)Brand";v="99"'),
                ("sec-ch-ua-mobile", "?0"),
                ("sec-ch-ua-platform", '"macOS"'),
                ("sec-fetch-dest", "empty"),
                ("sec-fetch-mode", "cors"),
                ("sec-fetch-site", "same-origin"),
                ("x-dtreferer", args.referer),
            ]
            if args.request_id:
                browser_headers.append(("x-request-id", args.request_id))
            for name, value in browser_headers:
                post_cmd.extend(["-H", f"{name}: {value}"])

        if args.cookie:
            post_cmd.extend(["-H", f"cookie: {args.cookie}"])
        for header in args.header:
            post_cmd.extend(["-H", header])

        post_cmd.extend(["--data-raw", payload_json])

        response = run_curl(post_cmd, args.verbose)
        if response.stderr.strip():
            print(response.stderr.strip(), file=sys.stderr)
        if response.returncode != 0:
            print(f"[remote] curl failed with exit code {response.returncode}")
            return response.returncode

    body, status = split_body_and_status(response.stdout)
    try:
        remote_data = json.loads(body)
    except json.JSONDecodeError:
        print_non_json_diagnostic(body, status)
        return 1

    if args.output:
        Path(args.output).write_text(body, encoding="utf-8")
        print(f"[remote] wrote JSON body: {args.output}")

    print(f"[remote] status={status} valid_json=true")
    if "errors" in remote_data:
        print(json.dumps(remote_data["errors"], ensure_ascii=False, indent=2))
        return 1

    summarize_calendar(remote_data, "remote")
    return 0 if status == 200 else 1


if __name__ == "__main__":
    raise SystemExit(main())
