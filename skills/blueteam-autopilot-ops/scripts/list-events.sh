#!/usr/bin/env bash
# List Security Center Agentic SOC events
# Usage: ./list-events.sh [time_range] [severity]
# time_range: last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days (default: lastHour)
# severity: CRITICAL, HIGH, MEDIUM, LOW (default: all)

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

# ----- Demo mode: return fixture data with fresh timestamps -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/events_recent.json"
  if [ -f "$FIXTURE_FILE" ]; then
    source "$SCRIPT_DIR/_rewrite-timestamps.sh"
    cat "$FIXTURE_FILE" | rewrite_timestamps
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-susp-events > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

TIME_RANGE="${1:-lastHour}"
SEVERITY="${2:-}"

log() { if [ "${AGENT_MODE:-}" != "1" ]; then echo "$@"; fi; }

log "Listing Security Center events..."
log "Region: $ALIBABA_REGION"
log "Time Range: $TIME_RANGE"
[ -n "$SEVERITY" ] && log "Severity: $SEVERITY"
log "---"


# Call Security Center API (lowercase with hyphens)
# Note: This API requires Enterprise/Ultimate edition
# Basic/Advanced editions will timeout or return 403
if [ -n "$SEVERITY" ]; then
  RAW_OUTPUT=$(aliyun sas describe-susp-events \
    --region "$ALIBABA_REGION" \
    --time-range "$TIME_RANGE" \
    --severity "$SEVERITY" \
    2>&1)
else
  RAW_OUTPUT=$(aliyun sas describe-susp-events \
    --region "$ALIBABA_REGION" \
    --time-range "$TIME_RANGE" \
    2>&1)
fi
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "$RAW_OUTPUT"
  echo ""
  echo "Error: API call failed (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Security Center is on Basic/Advanced edition (requires Enterprise/Ultimate)"
  echo "2. Missing RAM permissions: AliyunYundunSASReadOnlyAccess"
  echo "3. Invalid credentials or region"
  echo ""
  echo "Workaround: Query SLS directly for WAF logs"
  echo "  ./list-waf-events.sh $TIME_RANGE"
  exit $EXIT_CODE
fi

# Check if events are empty and add WAF fallback hint
TOTAL_COUNT=$(echo "$RAW_OUTPUT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("TotalCount",0))' 2>/dev/null || echo "0")

if [ "$TOTAL_COUNT" = "0" ]; then
  echo "$RAW_OUTPUT" | python3 -m json.tool
  echo ""
  echo "NOTE: Security Center returned 0 events. This is expected on Basic/Advanced"
  echo "edition (Enterprise/Ultimate required for Agentic SOC events)."
  echo "FALLBACK: Use list_waf_security_events tool to query WAF logs from SLS."
else
  echo "$RAW_OUTPUT" | python3 -m json.tool
fi
