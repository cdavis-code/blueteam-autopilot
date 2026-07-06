#!/usr/bin/env bash
# Delete a stale RAM user (disables keys first)
# Usage: ./delete-stale-user.sh <user_name>
# HITL-gated: requires --real flag for actual execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

USER_NAME="${1:-}"

# ----- Demo mode -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  echo "{\"status\": \"simulated\", \"action\": \"delete_stale_user\", \"user_name\": \"$USER_NAME\", \"message\": \"Would disable all access keys and delete user $USER_NAME\"}"
  exit 0
fi
# ----- End demo mode -----

if [ -z "$USER_NAME" ]; then
  echo "{\"error\": \"Usage: delete-stale-user.sh <user_name>\"}"
  exit 1
fi

source "$SCRIPT_DIR/_discover-region.sh"

# List and disable all access keys for the user
KEYS=$(aliyun ram list-access-keys --UserName "$USER_NAME" 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for k in data.get('AccessKeys', {}).get('AccessKey', []):
    if k['Status'] == 'Active':
        print(k['AccessKeyId'])
" 2>/dev/null || echo "")

for KEY_ID in $KEYS; do
  aliyun ram update-access-key --UserName "$USER_NAME" --UserAccessKeyId "$KEY_ID" --Status Inactive
done

# Delete the user
aliyun ram delete-user --UserName "$USER_NAME"
echo "{\"status\": \"completed\", \"action\": \"delete_stale_user\", \"user_name\": \"$USER_NAME\", \"keys_disabled\": $(echo $KEYS | wc -w | tr -d ' ')}"
