#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-popular}"
case "$MODE" in
  master|popular|alert|urgent|backfill|all) ;;
  *)
    echo "Usage: $0 {master|popular|alert|urgent|backfill|all}" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${HOTEL_AWARD_ENV_FILE:-$ROOT_DIR/env/hotel_award_cron.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

PYTHON_BIN="${PYTHON_BIN:-python3}"
ACTOR_UID="${HOTEL_AWARD_ACTOR_UID:-task_hotel_award_cron}"
LOG_DIR="${HOTEL_AWARD_LOG_DIR:-$ROOT_DIR/logs/hotel_award}"
LOCK_DIR="${HOTEL_AWARD_LOCK_DIR:-/tmp}"
DOMAIN_DELAY_SECONDS="${HOTEL_AWARD_DOMAIN_DELAY_SECONDS:-0}"

SERVICE_ACCOUNT_ARGS=()
if [[ -n "${FIREBASE_SERVICE_ACCOUNT:-}" ]]; then
  SERVICE_ACCOUNT_ARGS=(--service-account "$FIREBASE_SERVICE_ACCOUNT")
elif [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
  SERVICE_ACCOUNT_ARGS=(--service-account "$GOOGLE_APPLICATION_CREDENTIALS")
fi

DRY_RUN_ARGS=()
if [[ "${HOTEL_AWARD_DRY_RUN:-false}" == "true" ]]; then
  DRY_RUN_ARGS=(--dry-run)
fi

case "$MODE" in
  master)
    BUILD_LIMIT="${HOTEL_AWARD_MASTER_BUILD_LIMIT:-100}"
    COLLECT_LIMIT="${HOTEL_AWARD_MASTER_COLLECT_LIMIT:-100}"
    ;;
  popular)
    BUILD_LIMIT="${HOTEL_AWARD_POPULAR_BUILD_LIMIT:-80}"
    COLLECT_LIMIT="${HOTEL_AWARD_POPULAR_COLLECT_LIMIT:-50}"
    ;;
  alert)
    BUILD_LIMIT="${HOTEL_AWARD_ALERT_BUILD_LIMIT:-80}"
    COLLECT_LIMIT="${HOTEL_AWARD_ALERT_COLLECT_LIMIT:-40}"
    ;;
  urgent)
    BUILD_LIMIT="${HOTEL_AWARD_URGENT_BUILD_LIMIT:-40}"
    COLLECT_LIMIT="${HOTEL_AWARD_URGENT_COLLECT_LIMIT:-20}"
    ;;
  backfill)
    BUILD_LIMIT="${HOTEL_AWARD_BACKFILL_BUILD_LIMIT:-60}"
    COLLECT_LIMIT="${HOTEL_AWARD_BACKFILL_COLLECT_LIMIT:-30}"
    ;;
  all)
    BUILD_LIMIT="${HOTEL_AWARD_ALL_BUILD_LIMIT:-250}"
    COLLECT_LIMIT="${HOTEL_AWARD_ALL_COLLECT_LIMIT:-100}"
    ;;
esac

COLLECT_TYPE_ARGS=()
if [[ "$MODE" != "all" ]]; then
  COLLECT_TYPE_ARGS=(--job-type "$MODE")
fi

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${MODE}_$(date +%Y%m%d).log"
LOCK_FILE="$LOCK_DIR/milecatch_hotel_award_${MODE}.lock"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  echo "$(date -Is) $MODE cycle already running"
  exit 0
fi

{
  echo "$(date -Is) [$MODE] build start"
  "$PYTHON_BIN" task/hotel/build_award_crawl_jobs.py \
    --mode "$MODE" \
    --limit "$BUILD_LIMIT" \
    --actor-uid "$ACTOR_UID" \
    "${SERVICE_ACCOUNT_ARGS[@]}" \
    "${DRY_RUN_ARGS[@]}"

  echo "$(date -Is) [$MODE] collect start"
  "$PYTHON_BIN" task/hotel/collect_award_rates.py \
    --job-batch queued \
    "${COLLECT_TYPE_ARGS[@]}" \
    --limit "$COLLECT_LIMIT" \
    --domain-delay-seconds "$DOMAIN_DELAY_SECONDS" \
    --actor-uid "$ACTOR_UID" \
    "${SERVICE_ACCOUNT_ARGS[@]}" \
    "${DRY_RUN_ARGS[@]}"

  echo "$(date -Is) [$MODE] done"
} >>"$LOG_FILE" 2>&1
