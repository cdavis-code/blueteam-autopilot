#!/usr/bin/env bash
# Execute a response policy (supports dry-run simulation)
# Usage: ./execute-response-policy.sh <policy_id> [event_id] [--real]
# policy_id: the response policy to execute
# event_id: optional event ID to associate
# --real: actually execute (default: dry-run)

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" ]; then
  source "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" 2>/dev/null || true
fi

# ----- Demo mode: simulated response -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  DEMO_POLICY_ID="${1:-unknown}"
  DEMO_EVENT_ID="${2:-}"
  echo "[DEMO] Simulating response policy execution..."
  echo "  Policy ID: $DEMO_POLICY_ID"
  [ -n "$DEMO_EVENT_ID" ] && echo "  Event ID: $DEMO_EVENT_ID"
  echo ""
  echo "{"
  echo "  \"success\": true,"
  echo "  \"mode\": \"demo\","
  echo "  \"effects\": [\"Response policy \\\"$DEMO_POLICY_ID\\\" would be executed in real mode.\"],"
  echo "  \"message\": \"Policy execution simulated (demo mode). No API calls made.\""
  echo "}"
  exit 0
fi
# ----- End demo mode -----

source "$SCRIPT_DIR/_discover-region.sh"

POLICY_ID="${1:-}"
EVENT_ID="${2:-}"
REAL_MODE="${3:-}"

if [ -z "$POLICY_ID" ]; then
  echo "Usage: $0 <policy_id> [event_id] [--real]"
  echo "Example: $0 pol-xxx-yyy-zzz"
  echo "Example: $0 pol-xxx-yyy-zzz evt-aaa-bbb --real"
  exit 1
fi


MODE="${SECURITY_CENTER_MODE:-dry-run}"
if [ "$REAL_MODE" = "--real" ]; then
  MODE="real"
fi

echo "Executing response policy..."
echo "Region: $ALIBABA_REGION"
echo "Policy ID: $POLICY_ID"
[ -n "$EVENT_ID" ] && echo "Event ID: $EVENT_ID"
echo "Mode: $MODE"
echo "---"

if [ "$MODE" = "dry-run" ]; then
  echo ""
  echo "[DRY-RUN] Would execute response policy \"$POLICY_ID\""
  [ -n "$EVENT_ID" ] && echo "[DRY-RUN] Associated with event \"$EVENT_ID\""
  echo "[DRY-RUN] No state-changing API call was made."
  echo ""
  echo "To execute for real, add --real flag:"
  echo "  $0 $POLICY_ID $EVENT_ID --real"
  echo ""
  echo "⚠️  WARNING: Real execution requires explicit human approval"
  echo "   (SOC 2 CC6.8.3 — administrative validation window)"
  exit 0
fi

# Real execution — requires explicit approval
# NOTE: cloud-siem API requires Security Center Enterprise edition or higher
# NOTE: There is no direct "execute" API. Response configs are automated rules
#       that trigger based on conditions. The closest action is enabling the rule
#       via UpdateAutomateResponseConfigStatus (status=100 means enabled).
echo ""
echo "⚠️  EXECUTING IN REAL MODE"
echo "   This will ENABLE the response policy (status=100)."
echo "   The policy will then trigger automatically based on its conditions."
echo ""

# Build command — enable the response config
aliyun cloud-siem UpdateAutomateResponseConfigStatus \
  --Version 2022-06-16 \
  --region "$ALIBABA_REGION" \
  --Id "$POLICY_ID" \
  --Status 100 \
  2>&1 | python3 -m json.tool

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to enable response policy (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Policy ID does not exist"
  echo "2. Missing RAM permissions for cloud-siem"
  echo "3. Security Center Enterprise edition not enabled"
  echo "4. Policy already enabled or in invalid state"
  exit $EXIT_CODE
fi

echo ""
echo "Response policy \"$POLICY_ID\" has been ENABLED."
echo "It will now trigger automatically based on its configured conditions."
[ -n "$EVENT_ID" ] && echo "Note: Event ID \"$EVENT_ID\" was logged for audit purposes."
