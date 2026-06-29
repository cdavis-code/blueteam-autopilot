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

# ----- Demo mode: return fixture data -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/events_recent.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-susp-events > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

if [ -z "${ALIBABA_REGION:-}" ]; then
  echo "Error: ALIBABA_REGION not set"
  echo "Create a .env file or export ALIBABA_REGION=ap-southeast-1"
  exit 1
fi

TIME_RANGE="${1:-lastHour}"
SEVERITY="${2:-}"

echo "Listing Security Center events..."
echo "Region: $ALIBABA_REGION"
echo "Time Range: $TIME_RANGE"
[ -n "$SEVERITY" ] && echo "Severity: $SEVERITY"
echo "---"


# Call Security Center API (lowercase with hyphens)
# Note: This API requires Enterprise/Ultimate edition
# Basic/Advanced editions will timeout or return 403
if [ -n "$SEVERITY" ]; then
  aliyun sas describe-susp-events \
    --region "$ALIBABA_REGION" \
    --time-range "$TIME_RANGE" \
    --severity "$SEVERITY" \
    2>&1 | python3 -m json.tool
else
  aliyun sas describe-susp-events \
    --region "$ALIBABA_REGION" \
    --time-range "$TIME_RANGE" \
    2>&1 | python3 -m json.tool
fi

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: API call failed (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Security Center is on Basic/Advanced edition (requires Enterprise/Ultimate)"
  echo "2. Missing RAM permission: AliyunYundunSASReadOnlyAccess"
  echo "3. Invalid credentials or region"
  echo ""
  echo "Workaround: Query SLS directly for WAF logs"
  echo "  ./list-waf-events.sh $TIME_RANGE"
  exit $EXIT_CODE
fi
