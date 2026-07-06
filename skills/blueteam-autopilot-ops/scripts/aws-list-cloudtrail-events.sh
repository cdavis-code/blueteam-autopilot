#!/usr/bin/env bash
# aws-list-cloudtrail-events.sh — List CloudTrail API events
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

TIME_RANGE="${1:-lastHour}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_list_cloudtrail_events.json"
else
  HOURS=1
  case "$TIME_RANGE" in
    last15Min) HOURS=0 ;; lastHour) HOURS=1 ;; last4Hours) HOURS=4 ;;
    last24Hours) HOURS=24 ;; last7Days) HOURS=168 ;;
  esac
  START_TIME=$(date -u -v-${HOURS}H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
  aws cloudtrail lookup-events --start-time "$START_TIME" --max-results 20 --output json
fi
