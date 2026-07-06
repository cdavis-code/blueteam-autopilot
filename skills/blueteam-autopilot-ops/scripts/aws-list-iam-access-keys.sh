#!/usr/bin/env bash
# aws-list-iam-access-keys.sh — List access keys for IAM user
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
  cat "$FIXTURES_DIR/aws_list_iam_access_keys.json"
else
  aws iam list-access-keys --user-name "$USER_NAME" --output json
fi
