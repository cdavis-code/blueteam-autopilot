#!/usr/bin/env bash
# Verify SLS log delivery is working
# Usage: ./verify-log-delivery.sh

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

# ----- Demo mode: always returns verified -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  echo "Verifying WAF log delivery to SLS..."
  echo "Region: ap-southeast-1 (demo)"
  echo "Mode: demo"
  echo "---"
  echo "Step 1: Checking SLS project..."
  echo "  ✓ Project exists: wafnew-project-example-ap-southeast-1 (demo)"
  echo ""
  echo "Step 2: Checking logstore..."
  echo "  ✓ Found 1 logstore(s):"
  echo "    - wafnew-logstore"
  echo ""
  echo "Step 3: Querying recent logs (last 30 minutes)..."
  echo "  ✓ Found 12 recent log(s) (demo)"
  echo ""
  echo "RESULT: ✅ WAF log delivery is working correctly (demo mode)"
  exit 0
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"


# Auto-discover account ID via STS if not already set
if [ -z "${ACCOUNT_ID:-}" ]; then
  ACCOUNT_ID=$(aliyun sts GetCallerIdentity 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('AccountId',''))" 2>/dev/null || echo "")
  if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: Could not discover ACCOUNT_ID via 'aliyun sts GetCallerIdentity'."
    echo "       Export it manually: export ACCOUNT_ID=<your-account-id>"
    exit 1
  fi
fi

echo "Verifying WAF log delivery to SLS..."
echo "Region: $ALIBABA_REGION"
echo "Account ID: $ACCOUNT_ID"
echo "---"

# Calculate timestamps (last 30 minutes)
TO_TS=$(date -u +%s)
FROM_TS=$(date -u -v-30M +%s 2>/dev/null || date -u -d '30 minutes ago' +%s)

# SLS project and logstore
SLS_PROJECT="${WAF_SLS_PROJECT:-wafnew-project-${ACCOUNT_ID}-$ALIBABA_REGION}"
SLS_LOGSTORE="${WAF_SLS_LOGSTORE:-wafnew-logstore}"

echo "Step 1: Checking SLS project..."
aliyun sls GetProject \
  --project "$SLS_PROJECT" \
  --region "$ALIBABA_REGION" \
  2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'  ✓ Project exists: {data.get(\"ProjectName\", \"N/A\")}')
except:
    print('  ✗ Project not found or access denied')
    sys.exit(1)
" || {
  echo "  ✗ Failed to access SLS project"
  echo ""
  echo "Troubleshooting:"
  echo "1. Verify SLS project name (format: wafnew-project-ACCOUNT_ID-REGION)"
  echo "2. Check RAM permission: AliyunLogFullAccess"
  echo "3. Ensure WAF log delivery is enabled in WAF Console"
  exit 1
}

echo ""
echo "Step 2: Checking logstore..."
aliyun sls ListLogStores \
  --project "$SLS_PROJECT" \
  --region "$ALIBABA_REGION" \
  2>&1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
logstores = data.get('logstores', [])
if logstores:
    print(f'  ✓ Found {len(logstores)} logstore(s):')
    for ls in logstores:
        print(f'    - {ls}')
else:
    print('  ✗ No logstores found')
    sys.exit(1)
" || {
  echo "  ✗ Failed to list logstores"
  exit 1
}

echo ""
echo "Step 3: Querying recent logs (last 30 minutes)..."
LOG_COUNT=$(aliyun sls GetLogs \
  --project "$SLS_PROJECT" \
  --logstore "$SLS_LOGSTORE" \
  --from "$FROM_TS" \
  --to "$TO_TS" \
  --query "*" \
  --line 1 \
  --region "$ALIBABA_REGION" \
  2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    logs = data.get('logs', [])
    print(len(logs))
except:
    print('0')
")

if [ "$LOG_COUNT" -gt 0 ]; then
  echo "  ✓ Found $LOG_COUNT recent log(s)"
  echo ""
  echo "  Sample log entry:"
  aliyun sls GetLogs \
    --project "$SLS_PROJECT" \
    --logstore "$SLS_LOGSTORE" \
    --from "$FROM_TS" \
    --to "$TO_TS" \
    --query "*" \
    --line 1 \
    --region "$ALIBABA_REGION" \
    2>&1 | python3 -m json.tool | head -20
  echo "  ..."
  echo ""
  echo "RESULT: ✅ WAF log delivery is working correctly"
else
  echo "  ✗ No logs found in last 30 minutes"
  echo ""
  echo "RESULT: ⚠️  No recent WAF logs detected"
  echo ""
  echo "Possible causes:"
  echo "1. No WAF traffic in the last 30 minutes"
  echo "2. WAF log delivery not enabled at domain level"
  echo "3. Log delivery delay (wait 5-10 minutes after enabling)"
  echo ""
  echo "Next steps:"
  echo "1. Generate test traffic: curl 'http://your-domain.com/?id=1%27%20OR%201%3D1'"
  echo "2. Wait 5 minutes"
  echo "3. Re-run this script"
  echo "4. If still no logs, enable log delivery in WAF Console"
fi
