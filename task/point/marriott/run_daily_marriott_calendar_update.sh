#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/vory/StudioProjects/mileage_thief"
LOG_DIR="$HOME/Library/Logs/mileage_thief"
LOCK_DIR="/tmp/mileage_thief_marriott_calendar_daily.lock"

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/marriott-calendar-daily.log" 2>&1

echo "[$(date -Is)] start marriott daily calendar update"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "[$(date -Is)] another marriott calendar update is already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$ROOT_DIR"

python3 "$ROOT_DIR/task/point/marriott/update_marriott_calendar_from_firestore.py" \
  --window-mode month-grid \
  --start-month-offset 1 \
  --adults 1 \
  --request-delay-ms 4000 \
  --retry-count 3 \
  --retry-delay-ms 30000

python3 "$ROOT_DIR/task/point/build_point_award_indexes.py" \
  --program-id marriott

echo "[$(date -Is)] done marriott daily calendar update"
