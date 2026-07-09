#!/usr/bin/env bash
# Get trust policy for a specific RAM role
# Usage: ./get-role-trust-policy.sh <role_name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" ]; then
  source "${BLUETEAM_PROJECT_ROOT:-$(dirname "$SCRIPT_DIR")/..}/.env" 2>/dev/null || true
fi

ROLE_NAME="${1:-}"

# ----- Demo mode -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="${BLUETEAM_FIXTURES_DIR:-$SCRIPT_DIR/../fixtures}"
  FIXTURE_FILE="$FIXTURE_DIR/role_trust_policy.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

if [ -z "$ROLE_NAME" ]; then
  echo "{\"error\": \"Usage: get-role-trust-policy.sh <role_name>\"}"
  exit 1
fi

source "$SCRIPT_DIR/_discover-region.sh"
aliyun ram get-role --RoleName "$ROLE_NAME"
