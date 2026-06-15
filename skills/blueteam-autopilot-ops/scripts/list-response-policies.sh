#!/usr/bin/env bash
# List Agentic SOC response/automation policies
# Usage: ./list-response-policies.sh [scope]
# scope: WAF, ALL (default: ALL)

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

SCOPE="${1:-ALL}"

echo "Listing response policies..."
echo "Region: $ALIBABA_REGION"
echo "Scope: $SCOPE"
echo "---"

# Build command
if [ "$SCOPE" = "WAF" ]; then
  aliyun siem-socket list-automate-response-configs \
    --region "$ALIBABA_REGION" \
    --page-size 50 \
    --page-number 1 \
    --product-code waf \
    2>&1 | python3 -m json.tool
else
  aliyun siem-socket list-automate-response-configs \
    --region "$ALIBABA_REGION" \
    --page-size 50 \
    --page-number 1 \
    2>&1 | python3 -m json.tool
fi

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to list response policies (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Agentic SOC not enabled (requires Enterprise/Ultimate edition)"
  echo "2. Missing RAM permissions for Agentic SOC"
  echo "3. Invalid scope filter"
  exit $EXIT_CODE
fi
