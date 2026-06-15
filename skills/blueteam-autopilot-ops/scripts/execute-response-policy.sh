#!/usr/bin/env bash
# Execute a response policy (supports dry-run simulation)
# Usage: ./execute-response-policy.sh <policy_id> [event_id] [--real]
# policy_id: the response policy to execute
# event_id: optional event ID to associate
# --real: actually execute (default: dry-run)

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
echo ""
echo "⚠️  EXECUTING IN REAL MODE"
echo "   This will make state-changing API calls."
echo ""

# Build command
if [ -n "$EVENT_ID" ]; then
  aliyun siem-socket execute-automate-response \
    --region "$ALIBABA_REGION" \
    --config-id "$POLICY_ID" \
    --event-id "$EVENT_ID" \
    2>&1 | python3 -m json.tool
else
  aliyun siem-socket execute-automate-response \
    --region "$ALIBABA_REGION" \
    --config-id "$POLICY_ID" \
    2>&1 | python3 -m json.tool
fi

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Error: Failed to execute response policy (exit code: $EXIT_CODE)"
  echo ""
  echo "Possible causes:"
  echo "1. Policy ID does not exist"
  echo "2. Missing RAM permissions for Agentic SOC"
  echo "3. Policy execution not allowed in current mode"
  exit $EXIT_CODE
fi
