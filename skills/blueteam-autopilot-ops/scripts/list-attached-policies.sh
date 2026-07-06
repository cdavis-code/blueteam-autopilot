#!/usr/bin/env bash
# List policies attached to a RAM entity (user or role)
# Usage: ./list-attached-policies.sh <entity_type> <entity_name>
# entity_type: user | role

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

ENTITY_TYPE="${1:-}"
ENTITY_NAME="${2:-}"

# ----- Demo mode -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/attached_policies.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE\"}"
    exit 1
  fi
fi
# ----- End demo mode -----

if [ -z "$ENTITY_TYPE" ] || [ -z "$ENTITY_NAME" ]; then
  echo "{\"error\": \"Usage: list-attached-policies.sh <user|role> <name>\"}"
  exit 1
fi

source "$SCRIPT_DIR/_discover-region.sh"

if [ "$ENTITY_TYPE" = "role" ]; then
  aliyun ram list-policies-for-role --RoleName "$ENTITY_NAME"
elif [ "$ENTITY_TYPE" = "user" ]; then
  aliyun ram list-policies-for-user --UserName "$ENTITY_NAME"
else
  echo "{\"error\": \"entity_type must be 'user' or 'role', got: $ENTITY_TYPE\"}"
  exit 1
fi
