#!/usr/bin/env bash
# aws-update-finding.sh — Update Security Hub finding status (STATE-CHANGING)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

FINDING_ID="${1:-}"
STATUS="${2:-NOTIFIED}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ -z "$FINDING_ID" ]; then
  echo '{"error":"finding_id required"}'
  exit 1
fi

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_update_finding.json"
else
  aws securityhub batch-update-findings \
    --finding-ids "$FINDING_ID" \
    --workflow-status "$STATUS" \
    --output json
fi
