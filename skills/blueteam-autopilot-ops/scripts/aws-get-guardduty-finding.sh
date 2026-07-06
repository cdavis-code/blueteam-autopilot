#!/usr/bin/env bash
# aws-get-guardduty-finding.sh — Get GuardDuty finding detail
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

FINDING_ID="${1:-}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ -z "$FINDING_ID" ]; then
  echo '{"error":"finding_id required"}'
  exit 1
fi

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_get_guardduty_finding.json"
else
  DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null)
  aws guardduty get-findings --detector-id "$DETECTOR_ID" --finding-ids "$FINDING_ID" --output json
fi
