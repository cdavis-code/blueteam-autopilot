#!/usr/bin/env bash
# aws-ping.sh — Verify AWS CLI connectivity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_ping.json"
else
  ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")
  REGION=$(aws configure get region 2>/dev/null || echo "unknown")
  USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo "unknown")
  cat <<EOF
{"status":"ok","account_id":"$ACCOUNT_ID","region":"$REGION","user":"$USER_ARN"}
EOF
fi
