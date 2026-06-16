#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# configure-policies.sh
#
# Interactive configuration wizard for BlueTeam Autopilot compliance policies.
# Guides users through connecting their GRC tool (CISO Assistant) and selecting
# which compliance frameworks to sync.
#
# Reads policies.json and writes updated configuration.
# =============================================================================

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICIES_FILE="${SKILLS_ROOT}/blueteam-autopilot-knowledge/policies.json"
KNOWLEDGE_SCRIPTS="${SKILLS_ROOT}/blueteam-autopilot-knowledge/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}=== BlueTeam Autopilot: Policy Configuration Wizard ===${NC}"
echo ""

# ---------------------------------------------------------------------------
# Helper: Read a value from policies.json using simple grep/sed
# ---------------------------------------------------------------------------
read_json_field() {
  local file="$1"
  local path="$2"
  python3 -c "
import sys, json
try:
  with open('$file') as f:
    data = json.load(f)
  keys = '$path'.split('.')
  val = data
  for k in keys:
    if isinstance(val, dict):
      val = val.get(k, '')
    else:
      val = ''
  if isinstance(val, bool):
    print('true' if val else 'false')
  elif val is None:
    print('')
  else:
    print(str(val))
except Exception as e:
  print('')
" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# Helper: Write a value to policies.json at a dot-separated path
# ---------------------------------------------------------------------------
write_json_field() {
  local file="$1"
  local path="$2"
  local new_value="$3"
  python3 -c "
import sys, json
with open('$file') as f:
  data = json.load(f)
keys = '$path'.split('.')
parent = data
for k in keys[:-1]:
  if k not in parent:
    parent[k] = {}
  parent = parent[k]
last_key = keys[-1]
# Auto-detect type
if new_value in ('true', 'True'):
  parent[last_key] = True
elif new_value in ('false', 'False'):
  parent[last_key] = False
elif new_value.isdigit():
  parent[last_key] = int(new_value)
else:
  parent[last_key] = new_value
with open('$file', 'w') as f:
  json.dump(data, f, indent=2)
  f.write('\n')
" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Step 1: Load current policies and show status
# ---------------------------------------------------------------------------

if [ ! -f "$POLICIES_FILE" ]; then
  echo -e "${RED}Error: policies.json not found at ${POLICIES_FILE}${NC}"
  echo "Run this script from the skills root or ensure the knowledge skill is installed."
  exit 1
fi

echo -e "${BLUE}[Step 1/5] Current Policy Configuration${NC}"
echo "----------------------------------------"
echo ""

# Show all policies
python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
print(f'  {\"POLICY\":<24} {\"TYPE\":<14} {\"SOURCE\":<16} {\"SYNC MODE\":<12}')
print(f'  {\"-\"*24} {\"-\"*14} {\"-\"*16} {\"-\"*12}')
for p in data['policies']:
  pid = p['id']
  ptype = p.get('type','')
  source = p.get('source','')
  sync_mode = p.get('sync',{}).get('mode','') if source == 'grc' else 'N/A'
  last = p.get('sync',{}).get('last_sync','') if source == 'grc' else ''
  status = 'synced' if last else 'not synced'
  print(f'  {pid:<24} {ptype:<14} {source:<16} {status:<12}')
"
echo ""

# Show GRC provider status
echo -e "${BLUE}GRC Provider Status:${NC}"
GRC_ENABLED=$(read_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.enabled")
GRC_URL=$(read_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.base_url")
GRC_EMAIL=$(read_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.auth.email")

echo "  Provider:  ciso-assistant (CISO Assistant Community)"
echo "  Status:    ${GRC_ENABLED:-disabled}"
echo "  URL:       ${GRC_URL:-not configured}"
echo "  Email:     ${GRC_EMAIL:-not configured}"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Configure GRC provider connection
# ---------------------------------------------------------------------------

echo -e "${BLUE}[Step 2/5] GRC Provider Connection${NC}"
echo "----------------------------------------"
echo ""
echo "Configure your CISO Assistant Community instance."
echo "This is the GRC platform that will provide compliance framework data."
echo ""

read -r -p "  CISO Assistant URL [${GRC_URL:-https://localhost:8443}]: " input_url
GRC_URL="${input_url:-${GRC_URL:-https://localhost:8443}}"

read -r -p "  Admin email (for API auth): " input_email
GRC_EMAIL="${input_email:-${GRC_EMAIL:-}}"

read -r -s -p "  Password (input hidden): " input_password
echo ""
GRC_PASSWORD="${input_password}"

# Try to authenticate and get a token
echo ""
echo -n "  Testing connection to ${GRC_URL}... "

TOKEN_RESPONSE=$(curl -s -k -X POST "${GRC_URL}/api/iam/login/" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${GRC_EMAIL}\",\"password\":\"${GRC_PASSWORD}\"}" 2>&1) || true

GRC_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null || echo "")

if [ -n "$GRC_TOKEN" ]; then
  echo -e "${GREEN}Connected successfully!${NC}"
  GRC_ENABLED="true"
else
  echo -e "${YELLOW}Connection failed. Response:${NC}"
  echo "  ${TOKEN_RESPONSE}"
  echo ""
  echo "  You can still save the configuration and fix the connection later."
  echo "  Set GRC_ENABLED=false until the connection is verified."
  read -r -p "  Save connection config anyway? [Y/n]: " save_anyway
  if [ "${save_anyway:-Y}" = "Y" ] || [ "${save_anyway:-Y}" = "y" ]; then
    GRC_ENABLED="false"
  else
    echo "  Skipping GRC configuration. Policies will remain in manual mode."
    GRC_ENABLED="false"
  fi
fi

# Write provider config to policies.json
write_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.enabled" "$GRC_ENABLED"
write_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.base_url" "$GRC_URL"
write_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.auth.email" "$GRC_EMAIL"
write_json_field "$POLICIES_FILE" "grc_providers.ciso-assistant.auth.api_token" "$GRC_TOKEN"

echo ""

# ---------------------------------------------------------------------------
# Step 3: Discover available frameworks from GRC
# ---------------------------------------------------------------------------

if [ "$GRC_ENABLED" = "true" ] && [ -n "$GRC_TOKEN" ]; then
  echo -e "${BLUE}[Step 3/5] Framework Discovery${NC}"
  echo "----------------------------------------"
  echo ""
  echo "  Fetching available frameworks from CISO Assistant..."
  echo ""

  # Get stored libraries
  LIBS_JSON=$(curl -s -k -X GET "${GRC_URL}/api/stored-libraries/" \
    -H "Authorization: Token ${GRC_TOKEN}" \
    -H "Content-Type: application/json" 2>&1) || true

  # Try to display available libraries
  echo "$LIBS_JSON" | python3 -c "
import sys, json
try:
  data = json.load(sys.stdin)
  results = data.get('results', data) if isinstance(data, dict) else data
  if isinstance(results, list):
    frameworks = [l for l in results if l.get('is_published',False)]
    if frameworks:
      print('  Available compliance frameworks:')
      for fw in frameworks:
        name = fw.get('name','Unknown')
        desc = fw.get('description','')[:60]
        print(f'    - {name}')
        if desc:
          print(f'      {desc}')
    else:
      print('  No published libraries found.')
  else:
    print('  Unexpected response format.')
except Exception as e:
  print(f'  Could not parse response: {e}')
" 2>/dev/null || echo "  (Could not display frameworks — check API connectivity)"

  echo ""
else
  echo -e "${YELLOW}[Step 3/5] Framework Discovery — SKIPPED (GRC not connected)${NC}"
  echo ""
fi

# ---------------------------------------------------------------------------
# Step 4: Configure which policies to sync
# ---------------------------------------------------------------------------

echo -e "${BLUE}[Step 4/5] Policy Sync Configuration${NC}"
echo "----------------------------------------"
echo ""
echo "For each GRC-sourced policy, specify whether to enable syncing."
echo ""

python3 -c "
import json
with open('$POLICIES_FILE') as f:
  data = json.load(f)
for p in data['policies']:
  if p.get('source') == 'grc':
    print(f'  Policy: {p[\"id\"]} ({p[\"title\"]})')
    print(f'    Framework: {p[\"grc\"][\"library_name\"]}')
    print(f'    Controls:  {\", \".join(p.get(\"controls\",[]))}')
    print()
" 2>/dev/null

read -r -p "  Enable GRC sync for compliance policies? [Y/n]: " enable_sync
if [ "${enable_sync:-Y}" = "n" ] || [ "${enable_sync:-Y}" = "N" ]; then
  echo ""
  echo "  GRC sync disabled. Policies will use bundled documents."
  echo "  Run this wizard again to enable syncing later."
else
  echo ""
  echo "  GRC sync enabled for compliance policies."
  echo "  Run 'grc-sync.sh' to perform the initial sync."
fi

echo ""

# ---------------------------------------------------------------------------
# Step 5: Review and save
# ---------------------------------------------------------------------------

echo -e "${BLUE}[Step 5/5] Review Configuration${NC}"
echo "----------------------------------------"
echo ""

echo "  Configuration summary:"
echo "    GRC Provider:  ${GRC_URL}"
echo "    GRC Enabled:   ${GRC_ENABLED}"
echo "    Auth Email:    ${GRC_EMAIL:-not set}"
echo "    Config saved:  ${POLICIES_FILE}"
echo ""

echo ""

# ---------------------------------------------------------------------------
# Next steps
# ---------------------------------------------------------------------------

echo -e "${GREEN}=== Configuration Complete ===${NC}"
echo ""
echo "Next steps:"
echo ""
if [ "$GRC_ENABLED" = "true" ]; then
  echo "  1. Test the connection:"
  echo "     cd skills/blueteam-autopilot-knowledge"
  echo "     ./scripts/grc-sync.sh --list"
  echo ""
  echo "  2. Perform initial sync:"
  echo "     cd skills/blueteam-autopilot-knowledge"
  echo "     ./scripts/grc-sync.sh"
  echo ""
else
  echo "  1. Verify your CISO Assistant instance is running:"
  echo "     docker compose up -d"
  echo "     (in the ciso-assistant-community directory)"
  echo ""
  echo "  2. Re-run this wizard to configure the connection:"
  echo "     ./scripts/configure-policies.sh"
  echo ""
fi
echo "  3. Validate the full configuration:"
echo "     ./scripts/validate-configuration.sh"
echo ""
