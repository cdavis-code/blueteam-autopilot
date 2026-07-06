#!/usr/bin/env bash
# aws-list-assets.sh — List EC2 instances
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../../.env" 2>/dev/null || true

FIXTURES_DIR="$SCRIPT_DIR/../../blueteam-autopilot-core/fixtures"

if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  cat "$FIXTURES_DIR/aws_list_assets.json"
else
  aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --output json
fi
