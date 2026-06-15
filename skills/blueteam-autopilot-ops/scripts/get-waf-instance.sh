#!/usr/bin/env bash
# Discover WAF instance in the configured region
# Usage: ./get-waf-instance.sh

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

echo "Discovering WAF instance..."
echo "Region: $ALIBABA_REGION"
echo "---"

# Call WAF API (2021-10-01)
aliyun waf-openapi describe-instance \
  --region "$ALIBABA_REGION" \
  2>&1 | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    instance = data.get('Data', data)
    
    instance_id = instance.get('InstanceId', 'N/A')
    status = instance.get('Status', 'N/A')
    edition = instance.get('Edition', 'N/A')
    region = instance.get('RegionId', 'N/A')
    
    print(f'Instance ID: {instance_id}')
    print(f'Status: {status}')
    print(f'Edition: {edition}')
    print(f'Region: {region}')
    
    # Show features if available
    if 'InDebt' in instance:
        print(f'In Debt: {instance[\"InDebt\"]}')
    if 'ExpireTime' in instance:
        print(f'Expire Time: {instance[\"ExpireTime\"]}')
    
    print()
    print('✓ WAF instance discovered')
    print(f'  Use this Instance ID for other WAF scripts:')
    print(f'  export WAF_INSTANCE_ID=\"{instance_id}\"')
    
except Exception as e:
    print(f'Parse error: {e}', file=sys.stderr)
    sys.exit(1)
"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to discover WAF instance (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. WAF not provisioned in region $ALIBABA_REGION"
  echo "2. Missing RAM permissions: AliyunWAFReadOnlyAccess"
  echo "3. WAF instance expired"
  echo ""
  echo "Next steps:"
  echo "1. Provision WAF in the Alibaba Cloud Console"
  echo "2. Verify region matches your WAF deployment"
  exit $EXIT_CODE
fi
