#!/usr/bin/env bash
# List WAF security events from SLS logs
# Usage: ./list-waf-events.sh [time_range] [attack_type]
# time_range: last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days (default: lastHour)
# attack_type: sqli, xss, lfi, scanner_behavior (default: all)

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$(dirname "$SCRIPT_DIR")/../../../.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE" 2>/dev/null || true
fi

if [ -z "${ALIBABA_REGION:-}" ]; then
  echo "Error: ALIBABA_REGION not set"
  echo "Create a .env file or export ALIBABA_REGION=ap-southeast-1"
  exit 1
fi

TIME_RANGE="${1:-lastHour}"
ATTACK_TYPE="${2:-}"

# Convert time range to timestamp
case "$TIME_RANGE" in
  last15Min) MINUTES=15 ;;
  lastHour) MINUTES=60 ;;
  last4Hours) MINUTES=240 ;;
  last24Hours) MINUTES=1440 ;;
  last7Days) MINUTES=10080 ;;
  last30Days) MINUTES=43200 ;;
  *)
    echo "Error: Invalid time range '$TIME_RANGE'"
    echo "Valid options: last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days"
    exit 1
    ;;
esac

# Calculate timestamps
TO_TS=$(date -u +%s)
FROM_TS=$(date -u -v-${MINUTES}M +%s 2>/dev/null || date -u -d "${MINUTES} minutes ago" +%s)

echo "Querying WAF events from SLS..."
echo "Region: $ALIBABA_REGION"
echo "Time Range: $TIME_RANGE (last ${MINUTES} minutes)"
[ -n "$ATTACK_TYPE" ] && echo "Attack Type: $ATTACK_TYPE"
echo "From: $(date -u -d "@$FROM_TS" 2>/dev/null || date -u -r "$FROM_TS")"
echo "To: $(date -u -d "@$TO_TS" 2>/dev/null || date -u -r "$TO_TS")"
echo "---"

# Build SLS query
QUERY="*"
if [ -n "$ATTACK_TYPE" ]; then
  QUERY="attack_type: $ATTACK_TYPE"
fi

# Query SLS (project name format: wafnew-project-ACCOUNT_ID-REGION)
# Note: Replace YOUR_ACCOUNT_ID with actual account ID or use variable
SLS_PROJECT="${WAF_SLS_PROJECT:-wafnew-project-YOUR_ACCOUNT_ID-$ALIBABA_REGION}"
SLS_LOGSTORE="${WAF_SLS_LOGSTORE:-wafnew-logstore}"

echo "SLS Project: $SLS_PROJECT"
echo "SLS Logstore: $SLS_LOGSTORE"
echo "Query: $QUERY"
echo "---"

aliyun sls GetLogs \
  --project "$SLS_PROJECT" \
  --logstore "$SLS_LOGSTORE" \
  --from "$FROM_TS" \
  --to "$TO_TS" \
  --query "$QUERY" \
  --line 50 \
  --region "$ALIBABA_REGION" \
  2>&1 | python3 -m json.tool

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to query SLS (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. SLS project or logstore does not exist"
  echo "2. Missing RAM permission: AliyunLogFullAccess"
  echo "3. WAF log delivery not enabled"
  echo ""
  echo "Troubleshooting:"
  echo "  ./verify-log-delivery.sh"
  exit $EXIT_CODE
fi
