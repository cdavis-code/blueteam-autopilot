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
# Check env vars first, then aliyun CLI config
CREDENTIALS_FOUND=false

# Check environment variables
if [ -n "${ALIBABA_ACCESS_KEY_ID:-}" ] && [ -n "${ALIBABA_ACCESS_KEY_SECRET:-}" ]; then
  MASKED_KEY="${ALIBABA_ACCESS_KEY_ID:0:4}****${ALIBABA_ACCESS_KEY_ID: -4}"
  echo "   ✓ Credentials from environment ($MASKED_KEY)"
  CREDENTIALS_FOUND=true
fi

# Check aliyun CLI config
if [ "$CREDENTIALS_FOUND" = false ]; then
  ALIYUN_CONFIG="$HOME/.aliyun/config.json"
  if [ -f "$ALIYUN_CONFIG" ]; then
    # Try to get current profile's access key ID
    CURRENT_KEY=$(python3 -c "
import json, sys
try:
    with open('$ALIYUN_CONFIG') as f:
        config = json.load(f)
    current = config.get('current', '')
    for profile in config.get('profiles', []):
        if profile.get('name') == current:
            key_id = profile.get('access_key_id', '')
            if key_id:
                print(key_id[:4] + '****' + key_id[-4:])
                sys.exit(0)
    sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null || echo "")
    if [ -n "$CURRENT_KEY" ]; then
      echo "   ✓ Credentials from aliyun CLI config ($CURRENT_KEY)"
      CREDENTIALS_FOUND=true
    fi
  fi
fi

if [ "$CREDENTIALS_FOUND" = false ]; then
  echo "   ✗ No credentials found"
  echo "   Configure: aliyun configure"
  echo "   Or set: export ALIBABA_ACCESS_KEY_ID=\"your-key-id\""
  exit 1
fi

# Check 3: Region configured (auto-discover from CLI if not in env)
echo ""
echo "3. Region"
source "$SCRIPT_DIR/_discover-region.sh"
echo "   ✓ ALIBABA_REGION = $ALIBABA_REGION"

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
