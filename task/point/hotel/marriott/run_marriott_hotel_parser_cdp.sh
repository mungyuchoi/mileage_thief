#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
RUNNER_DIR="${MARRIOTT_PLAYWRIGHT_RUNNER_DIR:-/tmp/marriott-playwright-runner}"
CDP_PORT="${MARRIOTT_CDP_PORT:-9222}"
CDP_URL="http://127.0.0.1:${CDP_PORT}"
CHROME_PATH="${CHROME_PATH:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
CHROME_PROFILE="${MARRIOTT_CDP_PROFILE:-/tmp/marriott-cdp-profile}"
OUTPUT_PATH="$ROOT_DIR/task/point/hotel/marriott/marriott_hotel_meta.json"
UPLOAD="false"
UPLOAD_DRY_RUN="false"
PARSER_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      UPLOAD="true"
      shift
      ;;
    --dry-run-upload)
      UPLOAD="true"
      UPLOAD_DRY_RUN="true"
      shift
      ;;
    --output)
      OUTPUT_PATH="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      PARSER_ARGS+=("$1" "$OUTPUT_PATH")
      shift 2
      ;;
    *)
      PARSER_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -d "$RUNNER_DIR/node_modules/playwright" ]]; then
  mkdir -p "$RUNNER_DIR"
  if [[ ! -f "$RUNNER_DIR/package.json" ]]; then
    npm --prefix "$RUNNER_DIR" init -y >/dev/null
  fi
  npm --prefix "$RUNNER_DIR" install playwright@1.60.0 >/dev/null
fi

if ! curl -fsS "${CDP_URL}/json/version" >/dev/null 2>&1; then
  mkdir -p "$CHROME_PROFILE"
  "$CHROME_PATH" \
    --remote-debugging-port="$CDP_PORT" \
    --user-data-dir="$CHROME_PROFILE" \
    --no-first-run \
    --no-default-browser-check \
    >/tmp/marriott-cdp-chrome.log 2>&1 &

  for _ in {1..40}; do
    if curl -fsS "${CDP_URL}/json/version" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
fi

NODE_PATH="$RUNNER_DIR/node_modules" \
  node "$ROOT_DIR/task/point/hotel/marriott/parse_marriott_hotel.js" \
    --cdp-url "$CDP_URL" \
    --output "$OUTPUT_PATH" \
    "${PARSER_ARGS[@]}"

if [[ "$UPLOAD" == "true" ]]; then
  UPLOAD_ARGS=(--input "$OUTPUT_PATH")
  if [[ "$UPLOAD_DRY_RUN" == "true" ]]; then
    UPLOAD_ARGS+=(--dry-run)
  fi
  python3 "$ROOT_DIR/task/point/hotel/marriott/upload_point_hotel.py" "${UPLOAD_ARGS[@]}"
fi
