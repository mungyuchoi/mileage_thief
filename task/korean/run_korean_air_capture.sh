#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER_DIR="${KOREAN_AIR_PLAYWRIGHT_RUNNER_DIR:-/tmp/korean-air-playwright-runner}"
CDP_PORT="${KOREAN_AIR_CDP_PORT:-9223}"
CDP_URL="http://127.0.0.1:${CDP_PORT}"
CHROME_PATH="${CHROME_PATH:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
CHROME_PROFILE="${KOREAN_AIR_CDP_PROFILE:-/tmp/korean-air-cdp-profile}"

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
    >/tmp/korean-air-cdp-chrome.log 2>&1 &

  for _ in {1..40}; do
    if curl -fsS "${CDP_URL}/json/version" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
fi

NODE_PATH="$RUNNER_DIR/node_modules" \
  node "$ROOT_DIR/task/korean/capture_korean_air_award.js" \
    --cdp-url "$CDP_URL" \
    "$@"
