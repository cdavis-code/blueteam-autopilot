#!/usr/bin/env bash
# List cloud assets (ECS instances) registered in Security Center
# Usage: ./list-assets.sh [criteria] [page]
# criteria: optional search string to filter assets
# page: page number (default: 1)

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
