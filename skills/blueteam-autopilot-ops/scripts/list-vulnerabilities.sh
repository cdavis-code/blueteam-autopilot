#!/usr/bin/env bash
# List vulnerabilities detected by Security Center
# Usage: ./list-vulnerabilities.sh [severity] [asset_id] [vul_type] [page]
# severity: CRITICAL, HIGH, MEDIUM, LOW (default: all)
# asset_id: filter by specific asset (default: all)
# vul_type: CVE, WEB_CMS, APP, SYSTEM (default: CVE)
# page: page number (default: 1)

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
  FIXTURE_FILE="$FIXTURE_DIR/vulnerabilities.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-vul-list > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

SEVERITY="${1:-}"
ASSET_ID="${2:-}"
VUL_TYPE="${3:-cve}"
PAGE="${4:-1}"
PAGE_SIZE=20

echo "Listing Security Center vulnerabilities..."
echo "Region: $ALIBABA_REGION"
[ -n "$SEVERITY" ] && echo "Severity: $SEVERITY"
[ -n "$ASSET_ID" ] && echo "Asset: $ASSET_ID"
echo "Type: $VUL_TYPE"
echo "Page: $PAGE"
echo "---"


# Build command args
ARGS="--region \"$ALIBABA_REGION\" --current-page \"$PAGE\" --page-size \"$PAGE_SIZE\" --type \"$VUL_TYPE\""
[ -n "$SEVERITY" ] && ARGS="$ARGS --level \"$(echo "$SEVERITY" | tr '[:upper:]' '[:lower:]')\""
[ -n "$ASSET_ID" ] && ARGS="$ARGS --uuid \"$ASSET_ID\""

# Call Security Center API
eval aliyun sas describe-vul-list $ARGS 2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    vulns = data.get('Data', {}).get('VulRecords', [])
    total = data.get('PageInfo', {}).get('TotalCount', len(vulns))
    
    if not vulns:
        print('No vulnerabilities found')
        sys.exit(0)
    
    print(f'Found {total} vulnerability(ies) (showing page):')
    print()
    for v in vulns:
        vul_id = v.get('VulId', 'N/A')
        name = v.get('Name', 'N/A')
        level = v.get('Level', 'N/A')
        vtype = v.get('Type', 'N/A')
        cve = v.get('CveId', 'N/A')
        print(f'  [{level.upper()}] {name}')
        print(f'    ID: {vul_id} | CVE: {cve} | Type: {vtype}')
        print()
    
except Exception as e:
    # Fall back to raw output
    print(f'Parse error: {e}', file=sys.stderr)
    sys.exit(1)
"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to list vulnerabilities (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Missing RAM permissions: AliyunYundunSASReadOnlyAccess"
  echo "2. Security Center edition does not support vulnerability scanning"
  echo "3. Invalid severity or type filter"
  exit $EXIT_CODE
fi
