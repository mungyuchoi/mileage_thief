#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/vory/StudioProjects/mileage_thief"
LOG_DIR="$HOME/Library/Logs/mileage_thief"
LOCK_DIR="/tmp/mileage_thief_korean_air_daily.lock"

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/korean-air-daily.log" 2>&1

echo "[$(date -Is)] start korean air award update"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "[$(date -Is)] another korean air update is already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$ROOT_DIR"

python3 "$ROOT_DIR/task/korean/run_korean_air_award.py" "$@"

echo "[$(date -Is)] done korean air award update"
