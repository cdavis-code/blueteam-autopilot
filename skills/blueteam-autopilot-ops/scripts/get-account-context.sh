#!/usr/bin/env bash
# Get account context — region, Security Center edition, Agentic SOC status
# Usage: ./get-account-context.sh

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

echo "Fetching account context..."
echo "Region: $ALIBABA_REGION"
echo "---"

# Get Security Center edition
echo ""
echo "Security Center Edition:"
RESULT=$(aliyun sas describe-version-config --region "$ALIBABA_REGION" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "$RESULT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    vc = d.get('VersionConfig', {})
    v = vc.get('Version', 0)
    names = {1:'Basic',2:'Anti-virus',3:'Advanced',4:'Enterprise',5:'Ultimate'}
    print(f'  Edition: {names.get(v, \"Unknown\")} (code: {v})')
    print(f'  Asset Count: {vc.get(\"AssetCount\", \"N/A\")}')
    print(f'  Core Asset Count: {vc.get(\"CoreAssetCount\", \"N/A\")}')
    
    # Agentic SOC requires Enterprise (4) or Ultimate (5)
    if v >= 4:
        print('  Agentic SOC: ✓ Available (Enterprise/Ultimate)')
    else:
        print('  Agentic SOC: ✗ Not available (requires Enterprise/Ultimate)')
except Exception as e:
    print(f'  Parse error: {e}')
"
else
  echo "  ✗ Failed to fetch edition (exit: $EXIT_CODE)"
fi

# Check execution mode
echo ""
echo "Execution Mode:"
MODE="${SECURITY_CENTER_MODE:-dry-run}"
echo "  Mode: $MODE"
if [ "$MODE" = "real" ]; then
  echo "  ⚠️  WARNING: Real mode enabled — state-changing APIs are live"
else
  echo "  ✓ Dry-run mode — safe for testing"
fi

echo ""
echo "---"
echo "Account context complete"
