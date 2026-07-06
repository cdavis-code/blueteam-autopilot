#!/usr/bin/env bash
# aws-get-iam-mfa.sh — Get MFA device status for IAM user
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

USER_NAME="${1:-}"
FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ -z "$USER_NAME" ]; then
  echo '{"error":"user_name required"}'
  exit 1
fi

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_get_iam_mfa.json"
else
  aws iam list-mfa-devices --user-name "$USER_NAME" --output json
fi
