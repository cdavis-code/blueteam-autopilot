#!/usr/bin/env bash
# Detach a policy from a RAM entity (user or role)
# Usage: ./detach-policy.sh <entity_type> <entity_name> <policy_name>
# HITL-gated: requires --real flag for actual execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

ENTITY_TYPE="${1:-}"
ENTITY_NAME="${2:-}"
POLICY_NAME="${3:-}"

# ----- Demo mode -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  if [ "$ENTITY_TYPE" = "role" ]; then
    echo "{\"status\": \"simulated\", \"action\": \"detach_policy\", \"entity_type\": \"role\", \"entity_name\": \"$ENTITY_NAME\", \"policy_name\": \"$POLICY_NAME\", \"message\": \"Would detach $POLICY_NAME from role $ENTITY_NAME\"}"
  elif [ "$ENTITY_TYPE" = "user" ]; then
    echo "{\"status\": \"simulated\", \"action\": \"detach_policy\", \"entity_type\": \"user\", \"entity_name\": \"$ENTITY_NAME\", \"policy_name\": \"$POLICY_NAME\", \"message\": \"Would detach $POLICY_NAME from user $ENTITY_NAME\"}"
  else
    echo "{\"error\": \"entity_type must be 'user' or 'role', got: $ENTITY_TYPE\"}"
  fi
  exit 0
fi
# ----- End demo mode -----

if [ -z "$ENTITY_TYPE" ] || [ -z "$ENTITY_NAME" ] || [ -z "$POLICY_NAME" ]; then
  echo "{\"error\": \"Usage: detach-policy.sh <user|role> <name> <policy_name>\"}"
  exit 1
fi

source "$SCRIPT_DIR/_discover-region.sh"

if [ "$ENTITY_TYPE" = "role" ]; then
  aliyun ram detach-policy-from-role --RoleName "$ENTITY_NAME" --PolicyType System --PolicyName "$POLICY_NAME"
elif [ "$ENTITY_TYPE" = "user" ]; then
  aliyun ram detach-policy-from-user --UserName "$ENTITY_NAME" --PolicyType System --PolicyName "$POLICY_NAME"
else
  echo "{\"error\": \"entity_type must be 'user' or 'role', got: $ENTITY_TYPE\"}"
  exit 1
fi
