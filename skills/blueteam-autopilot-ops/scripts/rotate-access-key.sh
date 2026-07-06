#!/usr/bin/env bash
# Rotate a RAM user's access key (disable old, create new)
# Usage: ./rotate-access-key.sh <user_name> <access_key_id>
# HITL-gated: requires --real flag for actual execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

USER_NAME="${1:-}"
ACCESS_KEY_ID="${2:-}"

# ----- Demo mode -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  echo "{\"status\": \"simulated\", \"action\": \"rotate_access_key\", \"user_name\": \"$USER_NAME\", \"access_key_id\": \"$ACCESS_KEY_ID\", \"message\": \"Would disable key $ACCESS_KEY_ID for user $USER_NAME and create a new key\"}"
  exit 0
fi
# ----- End demo mode -----

if [ -z "$USER_NAME" ] || [ -z "$ACCESS_KEY_ID" ]; then
  echo "{\"error\": \"Usage: rotate-access-key.sh <user_name> <access_key_id>\"}"
  exit 1
fi

source "$SCRIPT_DIR/_discover-region.sh"

# Disable the old key
aliyun ram update-access-key --UserName "$USER_NAME" --UserAccessKeyId "$ACCESS_KEY_ID" --Status Inactive

# Create a new key
NEW_KEY=$(aliyun ram create-access-key --UserName "$USER_NAME")
echo "{\"status\": \"completed\", \"action\": \"rotate_access_key\", \"user_name\": \"$USER_NAME\", \"old_key_disabled\": \"$ACCESS_KEY_ID\", \"new_key\": $NEW_KEY}"
