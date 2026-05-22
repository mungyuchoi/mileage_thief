#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/vory/StudioProjects/mileage_thief"
LOG_DIR="$HOME/Library/Logs/mileage_thief"
LOCK_DIR="/tmp/mileage_thief_marriott_hotels_monthly.lock"

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/marriott-hotels-monthly.log" 2>&1

echo "[$(date -Is)] start marriott monthly hotel update"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "[$(date -Is)] another marriott hotel update is already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$ROOT_DIR"

python3 "$ROOT_DIR/task/point/hotel/marriott/update_marriott_hotels_from_firestore.py"

echo "[$(date -Is)] done marriott monthly hotel update"
