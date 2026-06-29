#!/usr/bin/env bash
# Health check — verify CLI, credentials, and region configuration
# Usage: ./ping.sh

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
  FIXTURE_FILE="$FIXTURE_DIR/ping.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-version-config > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

echo "BlueTeam Autopilot — Health Check"
echo "==================================="

# Check 1: aliyun CLI installed
echo ""
echo "1. CLI Installation"
if command -v aliyun &>/dev/null; then
  CLI_VERSION=$(aliyun version 2>/dev/null || echo "unknown")
  echo "   ✓ aliyun CLI installed (version: $CLI_VERSION)"
else
  echo "   ✗ aliyun CLI not found"
  echo "   Install: brew install aliyun-cli (macOS)"
  exit 1
fi

# Check 2: Credentials configured
echo ""
echo "2. Credentials"
if [ -n "${ALIBABA_ACCESS_KEY_ID:-}" ]; then
  MASKED_KEY="${ALIBABA_ACCESS_KEY_ID:0:4}****${ALIBABA_ACCESS_KEY_ID: -4}"
  echo "   ✓ ALIBABA_ACCESS_KEY_ID set ($MASKED_KEY)"
else
  echo "   ✗ ALIBABA_ACCESS_KEY_ID not set"
  echo "   Set: export ALIBABA_ACCESS_KEY_ID=\"your-key-id\""
  exit 1
fi

if [ -n "${ALIBABA_ACCESS_KEY_SECRET:-}" ]; then
  echo "   ✓ ALIBABA_ACCESS_KEY_SECRET set"
else
  echo "   ✗ ALIBABA_ACCESS_KEY_SECRET not set"
  echo "   Set: export ALIBABA_ACCESS_KEY_SECRET=\"your-key-secret\""
  exit 1
fi

# Check 3: Region configured
echo ""
echo "3. Region"
if [ -n "${ALIBABA_REGION:-}" ]; then
  echo "   ✓ ALIBABA_REGION = $ALIBABA_REGION"
else
  echo "   ✗ ALIBABA_REGION not set"
  echo "   Set: export ALIBABA_REGION=\"ap-southeast-1\""
  exit 1
fi

# Check 4: Execution mode
echo ""
echo "4. Execution Mode"
MODE="${SECURITY_CENTER_MODE:-demo}"
echo "   SECURITY_CENTER_MODE = $MODE"
if [ "$MODE" = "real" ]; then
  echo "   ⚠️  WARNING: Real mode — state-changing APIs are live"
fi

# Check 5: API connectivity (quick call)
echo ""
echo "5. API Connectivity"
RESULT=$(aliyun sas describe-version-config --region "$ALIBABA_REGION" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
  EDITION=$(echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    v = d.get('VersionConfig', {}).get('Version', 0)
    names = {1:'Basic',2:'Anti-virus',3:'Advanced',4:'Enterprise',5:'Ultimate'}
    print(f'{names.get(v, \"Unknown\")} (code: {v})')
except:
    print('Unknown (parse error)')
" 2>/dev/null || echo "Unknown (parse error)")
  echo "   ✓ Security Center API reachable"
  echo "   Edition: $EDITION"
else
  echo "   ⚠️  Security Center API call failed (exit: $EXIT_CODE)"
  echo "   This may indicate credential or permission issues"
fi

echo ""
echo "==================================="
echo "Health check complete"
