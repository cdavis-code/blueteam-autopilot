#!/usr/bin/env bash
# Get Security Center event detail with attack chain
# Usage: ./get-event-detail.sh <event_id>

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
  EVENT_ID="${1:-}"
  # Try per-event fixture first, then fall back to default
  if [ -n "$EVENT_ID" ] && [ -f "$FIXTURE_DIR/event_detail_${EVENT_ID}.json" ]; then
    FIXTURE_FILE="$FIXTURE_DIR/event_detail_${EVENT_ID}.json"
  elif [ -f "$FIXTURE_DIR/event_detail.json" ]; then
    FIXTURE_FILE="$FIXTURE_DIR/event_detail.json"
  else
    echo "{\"error\": \"Fixture not found. Run 'aliyun sas describe-susp-event-detail > event_detail.json' to capture.\"}"
    exit 1
  fi
  cat "$FIXTURE_FILE"
  exit 0
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

EVENT_ID="${1:-}"
if [ -z "$EVENT_ID" ]; then
  echo "Usage: $0 <event_id>"
  echo "Example: $0 evt-xxx-yyy-zzz"
  exit 1
fi

echo "Fetching event detail..."
echo "Region: $ALIBABA_REGION"
echo "Event ID: $EVENT_ID"
echo "---"


# Call Security Center API (lowercase with hyphens)
aliyun sas describe-susp-event-detail \
  --region "$ALIBABA_REGION" \
  --suspicious-event-id "$EVENT_ID" \
  2>&1 | python3 -m json.tool

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to fetch event detail (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Event ID does not exist"
  echo "2. Missing RAM permission: AliyunYundunSASReadOnlyAccess"
  echo "3. Security Center edition does not support this API"
  exit $EXIT_CODE
fi
