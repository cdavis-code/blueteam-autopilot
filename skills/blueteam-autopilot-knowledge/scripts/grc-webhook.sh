#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# grc-webhook.sh
#
# Webhook receiver for event-driven GRC sync.
# Accepts JSON on stdin or via --request-body, matches the event to
# configured policies, and triggers grc-sync.sh for matching policies.
#
# Usage:
#   echo '{"event":"framework_update","library":"NIST CSF v2.0"}' | ./grc-webhook.sh
#   ./grc-webhook.sh --request-body '{"event":"framework_update","library":"SOC2"}'
#
# CISO Assistant doesn't natively send webhooks on framework changes,
# but this provides the infrastructure for:
#   - Wrapping in a cron job that polls for changes
#   - Future webhook support from CISO Assistant
#   - Integration with external change notification systems
#
# Environment:
#   GRC_MODE=demo                     Use fixture data, no network calls
# =============================================================================

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICIES_FILE="${SKILLS_ROOT}/blueteam-autopilot-knowledge/policies.json"
GRC_SYNC_SCRIPT="${SKILLS_ROOT}/blueteam-autopilot-knowledge/scripts/grc-sync.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
REQUEST_BODY=""
if [ "${1:-}" = "--request-body" ]; then
  REQUEST_BODY="${2:-}"
elif [ ! -t 0 ]; then
  # Read from stdin
  REQUEST_BODY=$(cat)
else
  echo "Usage: $0 --request-body '<json>'"
  echo "   or: echo '<json>' | $0"
  echo ""
  echo "Event format:"
  echo '  {"event":"framework_update","library":"<library name>"}'
  echo '  {"event":"sync_all"}'
  exit 1
fi

echo ""
echo -e "${BOLD}=== GRC Webhook Receiver ===${NC}"
echo ""

# ---------------------------------------------------------------------------
# Parse event
# ---------------------------------------------------------------------------
EVENT=$(echo "$REQUEST_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('event',''))" 2>/dev/null || echo "unknown")
LIBRARY=$(echo "$REQUEST_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('library',''))" 2>/dev/null || echo "")

echo "  Event:   ${EVENT}"
echo "  Library: ${LIBRARY:-<none>}"
echo ""

# ---------------------------------------------------------------------------
# Match event to policies
# ---------------------------------------------------------------------------
case "$EVENT" in
  "framework_update")
    if [ -z "$LIBRARY" ]; then
      echo -e "${RED}ERROR: 'framework_update' event requires a 'library' field${NC}"
      exit 1
    fi

    # Find matching policy
    MATCHED=$(python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
for p in data['policies']:
  if p.get('source') == 'grc' and '${LIBRARY}' in p.get('grc',{}).get('library_name',''):
    print(p['id'])
    break
" 2>/dev/null || echo "")

    if [ -n "$MATCHED" ]; then
      echo -e "  Matched policy: ${GREEN}${MATCHED}${NC}"
      echo ""
      echo "  Triggering sync..."
      "$GRC_SYNC_SCRIPT" "$MATCHED"
    else
      echo -e "  ${YELLOW}No matching policy found for library '${LIBRARY}'.${NC}"
      echo "  Check policies.json to ensure a GRC-sourced policy references this library."
    fi
    ;;

  "sync_all")
    echo "  Triggering full sync..."
    "$GRC_SYNC_SCRIPT"
    ;;

  *)
    echo -e "${YELLOW}Unknown event type: ${EVENT}${NC}"
    echo "  Supported events: framework_update, sync_all"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}Webhook processing complete.${NC}"
