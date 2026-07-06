#!/usr/bin/env bash
# aws-list-guardduty-findings.sh — List GuardDuty findings
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

TIME_RANGE="${1:-lastHour}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_list_guardduty_findings.json"
else
  DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null)
  if [ -z "$DETECTOR_ID" ] || [ "$DETECTOR_ID" = "None" ]; then
    echo '{"Findings":[],"message":"GuardDuty not enabled"}'
    exit 0
  fi
  aws guardduty list-findings --detector-id "$DETECTOR_ID" \
    --max-results 20 --output json 2>/dev/null || echo '{"Findings":[]}'
fi
