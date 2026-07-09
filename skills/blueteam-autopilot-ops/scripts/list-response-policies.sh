#!/usr/bin/env bash
# List Agentic SOC response/automation policies
# Usage: ./list-response-policies.sh [scope]
# scope: WAF, ALL (default: ALL)

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
  FIXTURE_FILE="$FIXTURE_DIR/response_policies.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE. Run 'aliyun cloud-siem ListAutomateResponseConfigs --Version 2022-06-16 --CurrentPage 1 --PageSize 50 > $FIXTURE_FILE' to capture.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

SCOPE="${1:-ALL}"

echo "Listing response policies..."
echo "Region: $ALIBABA_REGION"
echo "Scope: $SCOPE"
echo "---"


# Build command
# NOTE: cloud-siem API requires Security Center Enterprise edition or higher
if [ "$SCOPE" = "WAF" ]; then
  aliyun cloud-siem ListAutomateResponseConfigs \
    --Version 2022-06-16 \
    --region "$ALIBABA_REGION" \
    --PageSize 50 \
    --CurrentPage 1 \
    --ActionType doPlaybook \
    2>&1 | python3 -m json.tool
else
  aliyun cloud-siem ListAutomateResponseConfigs \
    --Version 2022-06-16 \
    --region "$ALIBABA_REGION" \
    --PageSize 50 \
    --CurrentPage 1 \
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
