#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER_DIR="${MARRIOTT_PLAYWRIGHT_RUNNER_DIR:-/tmp/marriott-playwright-runner}"

if [[ ! -d "$RUNNER_DIR/node_modules/playwright" ]]; then
  mkdir -p "$RUNNER_DIR"
  if [[ ! -f "$RUNNER_DIR/package.json" ]]; then
    npm --prefix "$RUNNER_DIR" init -y >/dev/null
  fi
  npm --prefix "$RUNNER_DIR" install playwright@1.60.0 >/dev/null
fi

NODE_PATH="$RUNNER_DIR/node_modules" \
  node "$ROOT_DIR/task/point/test_marriott_playwright_capture.js" "$@"
