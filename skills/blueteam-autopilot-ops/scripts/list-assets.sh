#!/usr/bin/env bash
# List cloud assets (ECS instances) registered in Security Center
# Usage: ./list-assets.sh [criteria] [page]
# criteria: optional search string to filter assets
# page: page number (default: 1)

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" ]; then
  source "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" 2>/dev/null || true
fi

# ----- Demo mode: return fixture data -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="${BLUETEAM_FIXTURES_DIR:-$SCRIPT_DIR/../fixtures}"
  FIXTURE_FILE="$FIXTURE_DIR/assets.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun sas describe-cloud-center-instances > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

CRITERIA="${1:-}"
PAGE="${2:-1}"
PAGE_SIZE=20

echo "Listing cloud assets..."
echo "Region: $ALIBABA_REGION"
[ -n "$CRITERIA" ] && echo "Filter: $CRITERIA"
echo "Page: $PAGE"
echo "---"


# Build command
if [ -n "$CRITERIA" ]; then
  aliyun sas describe-cloud-center-instances \
    --region "$ALIBABA_REGION" \
    --current-page "$PAGE" \
    --page-size "$PAGE_SIZE" \
    --criteria "$CRITERIA" \
    2>&1 | python3 -m json.tool
else
  aliyun sas describe-cloud-center-instances \
    --region "$ALIBABA_REGION" \
    --current-page "$PAGE" \
    --page-size "$PAGE_SIZE" \
    2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    instances = data.get('Data', [])
    page_info = data.get('PageInfo', {})
    total = page_info.get('TotalCount', len(instances))
    
    if not instances:
        print('No assets found')
        sys.exit(0)
    
    print(f'Found {total} asset(s) (showing page):')
    print()
    for inst in instances:
        name = inst.get('InstanceName', inst.get('InstanceId', 'N/A'))
        inst_id = inst.get('InstanceId', 'N/A')
        ip_public = inst.get('InternetIp', inst.get('PublicIp', 'N/A'))
        ip_private = inst.get('IntranetIp', inst.get('PrivateIp', 'N/A'))
        asset_type = inst.get('AssetType', 'N/A')
        os = inst.get('OsName', inst.get('OSType', 'N/A'))
        region = inst.get('RegionId', 'N/A')
        uuid = inst.get('Uuid', 'N/A')
        
        print(f'  {name}')
        print(f'    Instance ID: {inst_id}')
        print(f'    Public IP:   {ip_public}')
        print(f'    Private IP:  {ip_private}')
        print(f'    Type: {asset_type} | OS: {os} | Region: {region}')
        print(f'    UUID: {uuid}')
        print()
    
except Exception as e:
    # Fall back to raw JSON
    print(f'Parse error: {e}', file=sys.stderr)
    sys.exit(1)
"
fi

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to list assets (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Missing RAM permissions: AliyunYundunSASReadOnlyAccess"
  echo "2. No assets registered in Security Center"
  echo "3. Invalid search criteria"
  exit $EXIT_CODE
fi
