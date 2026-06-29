#!/usr/bin/env bash
# List top 10 attacker IPs by WAF hit count
# Usage: ./list-waf-top-ips.sh [time_range]
# time_range: last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days (default: last7Days)

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
  FIXTURE_FILE="$FIXTURE_DIR/waf_top_ips.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun waf-openapi describe-rule-hits-top-client-ip > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"


TIME_RANGE="${1:-last7Days}"

# Convert time range to minutes
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
END_TS=$(date -u +%s)
START_TS=$(date -u -v-${MINUTES}M +%s 2>/dev/null || date -u -d "${MINUTES} minutes ago" +%s)

# Get WAF instance ID
WAF_INSTANCE_ID="${WAF_INSTANCE_ID:-}"
if [ -z "$WAF_INSTANCE_ID" ]; then
  echo "Auto-discovering WAF instance..."
  WAF_INSTANCE_ID=$(aliyun waf-openapi describe-instance \
    --region "$ALIBABA_REGION" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('Data', d).get('InstanceId', ''))
except:
    print('')
" 2>/dev/null)
  
  if [ -z "$WAF_INSTANCE_ID" ]; then
    echo "Error: Could not discover WAF instance ID"
    echo "Set WAF_INSTANCE_ID or run ./get-waf-instance.sh first"
    exit 1
  fi
  echo "✓ Discovered: $WAF_INSTANCE_ID"
fi

echo ""
echo "Listing top attacker IPs..."
echo "Region: $ALIBABA_REGION"
echo "Instance: $WAF_INSTANCE_ID"
echo "Time Range: $TIME_RANGE (last ${MINUTES} minutes)"
echo "From: $(date -u -r "$START_TS" 2>/dev/null || date -u -d "@$START_TS" 2>/dev/null)"
echo "To: $(date -u -r "$END_TS" 2>/dev/null || date -u -d "@$END_TS" 2>/dev/null)"
echo "---"

# Call WAF API for top attacker IPs
aliyun waf-openapi describe-rule-hits-top-client-ip \
  --region "$ALIBABA_REGION" \
  --InstanceId "$WAF_INSTANCE_ID" \
  --StartTimestamp "$START_TS" \
  --EndTimestamp "$END_TS" \
  2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ips = data.get('RuleHitsTopClientIp', [])
    
    if not ips:
        print('No attacker IPs found in this time range')
        sys.exit(0)
    
    print(f'Top {len(ips)} attacker IPs:')
    print()
    for i, entry in enumerate(ips, 1):
        ip = entry.get('ClientIp', entry.get('Ip', 'N/A'))
        hit_count = entry.get('HitCount', entry.get('Count', 'N/A'))
        print(f'  {i:2d}. {ip:20s} — {hit_count} hits')
    
    print()
    print('Cross-reference against trusted-networks.md before blocking')
    
except Exception as e:
    print(f'Parse error: {e}', file=sys.stderr)
    sys.exit(1)
"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to list top attacker IPs (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. WAF instance not found or expired"
  echo "2. Missing RAM permissions: AliyunWAFReadOnlyAccess"
  echo "3. No WAF traffic in the specified time range"
  exit $EXIT_CODE
fi
