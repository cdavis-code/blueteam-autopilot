#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# grc-sync.sh
#
# Main GRC sync orchestration script for BlueTeam Autopilot.
# Fetches compliance frameworks from configured GRC providers and writes
# them as knowledge documents.
#
# Usage:
#   ./grc-sync.sh [policy_id]       Sync specific policy, or all GRC policies
#   ./grc-sync.sh --list            List all policies and their sync status
#   ./grc-sync.sh --dry-run         Show what would be synced without writing
#   ./grc-sync.sh --providers       List available GRC providers
#
# Environment:
#   GRC_MODE=demo                   Use fixture data, no network calls
# =============================================================================

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POLICIES_FILE="${SKILLS_ROOT}/blueteam-autopilot-knowledge/policies.json"
DOCUMENTS_DIR="${SKILLS_ROOT}/blueteam-autopilot-knowledge/documents"
ARCHIVE_DIR="${DOCUMENTS_DIR}/archive"
PROVIDERS_DIR="${SKILLS_ROOT}/blueteam-autopilot-knowledge/grc-providers"
SYNC_LOG="${SKILLS_ROOT}/blueteam-autopilot-knowledge/sync-log.jsonl"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Ensure archive directory exists
mkdir -p "$ARCHIVE_DIR"

# =============================================================================
# Helper: Read a field from policies.json
# =============================================================================
read_policies_field() {
  local path="$1"
  python3 -c "
import sys, json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
keys = '$path'.split('.')
val = data
for k in keys:
  if isinstance(val, dict):
    val = val.get(k, '')
  else:
    val = ''
print(str(val) if val is not None else '')
" 2>/dev/null || echo ""
}

# =============================================================================
# Helper: Update a field in policies.json
# =============================================================================
update_policies_field() {
  local path="$1"
  local new_value="$2"
  python3 -c "
import sys, json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
keys = '$path'.split('.')
parent = data
for k in keys[:-1]:
  if k not in parent:
    parent[k] = {}
  parent = parent[k]
last_key = keys[-1]
if '$new_value' == 'null':
  parent[last_key] = None
else:
  parent[last_key] = '$new_value'
with open('$POLICIES_FILE', 'w') as f:
  json.dump(data, f, indent=2)
  f.write('\n')
" 2>/dev/null
}

# =============================================================================
# Helper: Append to sync log
# =============================================================================
log_sync_event() {
  local policy_id="$1"
  local action="$2"
  local status="$3"
  local grc_version="$4"
  local local_version="$5"
  local hash_val="$6"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "{\"timestamp\":\"${timestamp}\",\"policy_id\":\"${policy_id}\",\"action\":\"${action}\",\"status\":\"${status}\",\"grc_version\":\"${grc_version}\",\"local_version\":\"${local_version}\",\"hash\":\"${hash_val}\"}" >> "$SYNC_LOG"
}

# =============================================================================
# Helper: Compute MD5 hash of a file
# =============================================================================
file_hash() {
  md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | cut -d' ' -f1
}

# =============================================================================
# Helper: Extract version from YAML frontmatter
# =============================================================================
extract_yaml_version() {
  local file="$1"
  python3 -c "
import sys
with open('$file') as f:
  for line in f:
    line = line.strip()
    if line.startswith('version:'):
      print(line.split(':',1)[1].strip().strip('\"'))
      break
" 2>/dev/null || echo "unknown"
}

# =============================================================================
# Helper: Validate that a document contains expected controls
# =============================================================================
validate_controls() {
  local content="$1"
  local expected_controls="$2"

  # Pass untrusted content via stdin to avoid shell injection
  printf '%s' "$content" | python3 -c "
import sys, json
content = sys.stdin.read()
controls = json.loads('''${expected_controls}''')
missing = []
for c in controls:
  if c not in content:
    missing.append(c)
if missing:
  print('MISSING: ' + ', '.join(missing))
  sys.exit(1)
" 2>/dev/null
}

# =============================================================================
# Main: --list mode
# =============================================================================
if [ "${1:-}" = "--list" ]; then
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║${NC}  ${BOLD}Policy Sync Status${NC}                                      ${BOLD}║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""

  python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)

# Calculate column widths from data
policies = data['policies']
max_pid = max(len(p['id']) for p in policies)
max_source = max(len(p.get('source','')) for p in policies)
max_doc = max(len(p.get('document','')) for p in policies)

# Ensure minimum widths
max_pid = max(max_pid, 12)
max_source = max(max_source, 8)
max_doc = max(max_doc, 10)

# Print table header
print(f\"{'Policy ID':<{max_pid}}  {'Source':<{max_source}}  {'Document':<{max_doc}}  {'Status'}\")
print('=' * (max_pid + max_source + max_doc + 45))

grc_count = 0
synced_count = 0

for p in policies:
  pid = p['id']
  source = p.get('source','')
  doc = p.get('document','')

  if source == 'grc':
    grc_count += 1
    sync = p.get('sync',{})
    sync_mode = sync.get('mode','manual')
    last = sync.get('last_sync','')
    
    if last:
      synced_count += 1
      status = f\"\\033[0;32m✔ synced\\033[0m\"
      last_sync_display = last
    else:
      status = f\"\\033[0;31m✖ not synced\\033[0m\"
      last_sync_display = 'never'
    
    print(f\"{pid:<{max_pid}}  {source:<{max_source}}  {doc:<{max_doc}}  {status}\")
    print(f\"{'':<{max_pid}}  {'':<{max_source}}  │  provider:  {p['grc']['provider']}\")
    print(f\"{'':<{max_pid}}  {'':<{max_source}}  │  framework: {p['grc']['library_name']}\")
    print(f\"{'':<{max_pid}}  {'':<{max_source}}  │  sync_mode: {sync_mode}\")
    print(f\"{'':<{max_pid}}  {'':<{max_source}}  │  last_sync: {last_sync_display}\")
    print()
  else:
    print(f\"{pid:<{max_pid}}  {source:<{max_source}}  {doc:<{max_doc}}  {'-'}\")

print('=' * (max_pid + max_source + max_doc + 45))
print()
print(f\"Summary: {grc_count} GRC policies, {synced_count} synced, {grc_count - synced_count} pending\")
print()

# GRC Provider configuration
provider = data.get('grc_providers',{}).get('ciso-assistant',{})
enabled = provider.get('enabled',False)
url = provider.get('base_url','not configured')

status_color = '\\033[0;32m' if enabled else '\\033[0;31m'
status_reset = '\\033[0m'
status_text = f\"{status_color}{'Enabled' if enabled else 'Disabled'}{status_reset}\"

print(f\"\\033[1mGRC Provider Configuration:\\033[0m\")
print(f\"  Provider:  ciso-assistant\")
print(f\"  Status:    {status_text}\")
print(f\"  URL:       {url}\")
"
  exit 0
fi

# =============================================================================
# Main: --providers mode
# =============================================================================
if [ "${1:-}" = "--providers" ]; then
  echo ""
  echo -e "${BOLD}Available GRC Providers${NC}"
  echo "========================"
  echo ""

  for provider_script in "$PROVIDERS_DIR"/*.sh; do
    if [ ! -f "$provider_script" ]; then
      continue
    fi
    script_name=$(basename "$provider_script")
    if [ "$script_name" = "_template.sh" ]; then
      continue
    fi

    # Source and describe
    # shellcheck disable=SC1090
    source "$provider_script" 2>/dev/null || true
    if [ "$(type -t grc_describe 2>/dev/null)" = "function" ]; then
      grc_describe
      echo ""
    else
      echo "  ${script_name} (no description available)"
    fi
  done
  exit 0
fi

# =============================================================================
# Main: --dry-run mode
# =============================================================================
DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
  echo ""
  echo -e "${YELLOW}[DRY RUN] No files will be modified.${NC}"
  echo ""
  shift || true
fi

# =============================================================================
# Main: sync mode
# =============================================================================

# Determine which policies to sync
POLICY_FILTER="${1:-}"
if [ -n "$POLICY_FILTER" ] && [ "$POLICY_FILTER" != "--dry-run" ]; then
  echo ""
  echo -e "${BOLD}Syncing policy: ${POLICY_FILTER}${NC}"
  echo ""
else
  POLICY_FILTER=""
  echo ""
  echo -e "${BOLD}Syncing all GRC policies${NC}"
  echo ""
fi

# Load policy list
SYNC_COUNT=0
FAIL_COUNT=0

python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
for p in data['policies']:
  if p.get('source') == 'grc':
    filter_id = '${POLICY_FILTER}'
    if filter_id and p['id'] != filter_id:
      continue
    print(json.dumps({
      'id': p['id'],
      'provider': p['grc']['provider'],
      'library_name': p['grc']['library_name'],
      'framework_id': p['grc'].get('framework_id',''),
      'document': p['document'],
      'controls': json.dumps(p.get('controls',[]))
    }))
" 2>/dev/null | while IFS= read -r policy_json; do
  POLICY_ID=$(echo "$policy_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['id'])" 2>/dev/null)
  PROVIDER=$(echo "$policy_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['provider'])" 2>/dev/null)
  LIBRARY_NAME=$(echo "$policy_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['library_name'])" 2>/dev/null)
  FRAMEWORK_ID=$(echo "$policy_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['framework_id'])" 2>/dev/null)
  DOC_FILE=$(echo "$policy_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['document'])" 2>/dev/null)
  CONTROLS=$(echo "$policy_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['controls'])" 2>/dev/null)

  DOC_PATH="${DOCUMENTS_DIR}/${DOC_FILE##*/}"

  echo -e "${BLUE}[${POLICY_ID}]${NC} ${LIBRARY_NAME}"
  echo "  Provider:  ${PROVIDER}"
  echo "  Document:  ${DOC_FILE}"
  echo ""

  # Locate provider script
  PROVIDER_SCRIPT="${PROVIDERS_DIR}/${PROVIDER}.sh"
  if [ ! -f "$PROVIDER_SCRIPT" ]; then
    echo -e "  ${RED}ERROR: Provider script not found: ${PROVIDER_SCRIPT}${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Source provider
  # shellcheck disable=SC1090
  source "$PROVIDER_SCRIPT" 2>/dev/null || {
    echo -e "  ${RED}ERROR: Failed to source provider script${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  }

  # Connect
  echo -n "  Connecting to ${GRC_PROVIDER_DISPLAY_NAME}... "
  if grc_connect 2>&1; then
    echo -e "${GREEN}OK${NC}"
  else
    echo -e "${RED}FAILED${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    continue
  fi

  # Determine which library ID to use
  if [ -n "$FRAMEWORK_ID" ] && [ "$FRAMEWORK_ID" != "null" ]; then
    USE_LIBRARY_ID="$FRAMEWORK_ID"
  else
    # Try to find by name
    echo -n "  Looking up framework by name... "
    FRAMEWORKS_JSON=$(grc_list_frameworks 2>/dev/null || echo '[]')
    USE_LIBRARY_ID=$(echo "$FRAMEWORKS_JSON" | python3 -c "
import sys, json
try:
  fws = json.load(sys.stdin)
  target = '${LIBRARY_NAME}'
  for fw in fws:
    if fw.get('name','') == target:
      print(fw['id'])
      break
except:
  pass
" 2>/dev/null || echo "")

    if [ -z "$USE_LIBRARY_ID" ]; then
      echo -e "${YELLOW}NOT FOUND${NC}"
      echo -e "  ${YELLOW}WARNING: Could not find framework '${LIBRARY_NAME}' in GRC platform.${NC}"
      echo "  Available frameworks:"
      echo "$FRAMEWORKS_JSON" | python3 -c "
import sys, json
fws = json.load(sys.stdin)
for fw in fws[:10]:
  print(f\"    - {fw['name']}\")
" 2>/dev/null || echo "    (none)"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      continue
    fi
    echo -e "${GREEN}Found (${USE_LIBRARY_ID})${NC}"
  fi

  # Get framework content
  echo -n "  Fetching framework content... "
  FRAMEWORK_CONTENT=$(grc_get_framework "$USE_LIBRARY_ID" 2>/dev/null || echo "")

  if [ -z "$FRAMEWORK_CONTENT" ]; then
    echo -e "${RED}EMPTY RESPONSE${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log_sync_event "$POLICY_ID" "sync" "failed" "" "" ""
    continue
  fi

  echo -e "${GREEN}OK ($(echo "$FRAMEWORK_CONTENT" | wc -l | tr -d ' ') lines)${NC}"

  # Extract versions
  GRC_VERSION=$(echo "$FRAMEWORK_CONTENT" | python3 -c "
import sys
for line in sys.stdin:
  line = line.strip()
  if line.startswith('version:'):
    print(line.split(':',1)[1].strip().strip('\"'))
    break
" 2>/dev/null || echo "unknown")

  # Validate controls
  if [ -n "${CONTROLS:-}" ] && [ "${CONTROLS:-}" != "[]" ]; then
    echo -n "  Validating expected controls... "
    if validate_controls "$FRAMEWORK_CONTENT" "$CONTROLS" 2>/dev/null; then
      echo -e "${GREEN}ALL PRESENT${NC}"
    else
      echo -e "${YELLOW}WARNING: Some expected controls may be missing${NC}"
    fi
  fi

  # Write document
  if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}[DRY RUN] Would write to: ${DOC_PATH}${NC}"
  else
    # Human review gate: show diff and require explicit approval before writing
    if [ -f "$DOC_PATH" ]; then
      CURRENT_VERSION=$(extract_yaml_version "$DOC_PATH")
      CURRENT_HASH=$(file_hash "$DOC_PATH")
      echo -e "  ${BOLD}Proposed changes to ${DOC_PATH}:${NC}"
      diff "$DOC_PATH" <(echo "$FRAMEWORK_CONTENT") 2>/dev/null || true
      echo ""
      read -rp "  Apply this update? [y/N] " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  Skipped."
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
      fi
    else
      CURRENT_VERSION="none"
      CURRENT_HASH=""
      echo -e "  ${YELLOW}New document will be created at: ${DOC_PATH}${NC}"
      read -rp "  Create this document? [y/N] " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  Skipped."
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
      fi
    fi

    # Archive current version if it exists
    if [ -f "$DOC_PATH" ]; then
      TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
      ARCHIVE_PATH="${ARCHIVE_DIR}/$(basename "$DOC_FILE" .md)-backup-${TIMESTAMP}.md"
      cp "$DOC_PATH" "$ARCHIVE_PATH"
      echo "  Archived previous version to: ${ARCHIVE_PATH}"
    fi

    # Write new content
    echo "$FRAMEWORK_CONTENT" > "$DOC_PATH"
    NEW_HASH=$(file_hash "$DOC_PATH")

    # Update policies.json with sync status
    update_policies_field "policies.${POLICY_ID}.sync.last_sync" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    update_policies_field "policies.${POLICY_ID}.sync.grc_version" "$GRC_VERSION"
    if [ -n "$USE_LIBRARY_ID" ]; then
      update_policies_field "policies.${POLICY_ID}.grc.framework_id" "$USE_LIBRARY_ID"
    fi

    # Log the event
    log_sync_event "$POLICY_ID" "sync" "success" "$GRC_VERSION" "$CURRENT_VERSION" "$NEW_HASH"

    echo -e "  ${GREEN}Written to: ${DOC_PATH}${NC}"
  fi

  SYNC_COUNT=$((SYNC_COUNT + 1))
  echo ""
done

# Summary
echo "----------------------------------------"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY RUN] Would sync ${SYNC_COUNT} policies (${FAIL_COUNT} would fail)${NC}"
else
  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}Sync complete: ${SYNC_COUNT} policies synced successfully.${NC}"
  else
    echo -e "${YELLOW}Sync complete: ${SYNC_COUNT} successful, ${FAIL_COUNT} failed.${NC}"
  fi
fi
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
