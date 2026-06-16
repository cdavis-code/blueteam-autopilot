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
if [ "${SECURITY_CENTER_MODE:-real}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/event_detail.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-susp-event-detail > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

if [ -z "${ALIBABA_REGION:-}" ]; then
  echo "Error: ALIBABA_REGION not set"
  echo "Create a .env file or export ALIBABA_REGION=ap-southeast-1"
  exit 1
fi

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
