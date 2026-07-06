#!/usr/bin/env bash
# aws-list-iam-users.sh — List IAM users
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_list_iam_users.json"
else
  aws iam list-users --output json
fi
