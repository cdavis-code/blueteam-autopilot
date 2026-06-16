#!/usr/bin/env bash
# =============================================================================
# CISO Assistant Community — GRC Provider
# =============================================================================
# Integrates with the CISO Assistant Community GRC platform by intuitem.
# GitHub: https://github.com/intuitem/ciso-assistant-community
#
# API:
#   POST /api/iam/login/         — Authenticate (returns token)
#   GET  /api/stored-libraries/  — List built-in framework libraries
#   GET  /api/loaded-libraries/  — List user-loaded libraries
#   GET  /api/requirement-nodes/?library=<id>  — Get control nodes for a library
#
# Auth: Authorization: Token <token> header
# =============================================================================

set -euo pipefail

# --- Provider metadata ---
GRC_PROVIDER_NAME="ciso-assistant"
GRC_PROVIDER_DISPLAY_NAME="CISO Assistant Community"
GRC_PROVIDER_DESCRIPTION="Open-source GRC platform by intuitem. Supports 150+ frameworks."

# --- Configuration (overridable via env vars) ---
GRC_BASE_URL="${GRC_BASE_URL:-https://localhost:8443}"
GRC_EMAIL="${GRC_EMAIL:-}"
GRC_API_TOKEN="${GRC_API_TOKEN:-}"
GRC_VERIFY_SSL="${GRC_VERIFY_SSL:-false}"

# Determine curl SSL flag
if [ "$GRC_VERIFY_SSL" = "false" ] || [ "$GRC_VERIFY_SSL" = "0" ]; then
  CURL_SSL_FLAG="-k"
else
  CURL_SSL_FLAG=""
fi

# --- Demo fixture data ---
DEMO_FRAMEWORKS='[
  {
    "id": "demo-nist-csf-v2",
    "name": "NIST Cyber Security Framework (CSF) v2.0",
    "type": "compliance",
    "description": "NIST Cybersecurity Framework version 2.0 — Govern, Identify, Protect, Detect, Respond, Recover"
  },
  {
    "id": "demo-soc2",
    "name": "SOC2",
    "type": "compliance",
    "description": "SOC 2 Type II Trust Services Criteria — Security, Availability, Confidentiality, Privacy, Processing Integrity"
  },
  {
    "id": "demo-iso27001",
    "name": "ISO 27001:2022",
    "type": "compliance",
    "description": "ISO/IEC 27001:2022 Information Security Management System requirements"
  }
]'

DEMO_FRAMEWORK_CONTENT_NIST='---
document_id: nist-csf
version: "2026.1"
source: grc
grc_provider: ciso-assistant
framework: NIST CSF v2.0
library_id: demo-nist-csf-v2
sync_date: "2026-06-16"
---

# NIST Cybersecurity Framework (CSF) v2.0
## Source: CISO Assistant Community (demo mode)

### PR.PT-4: Network Bounding and Communications Protection
*   **Control Objective:** Manage communication and control networks to protect information systems.
*   **Category:** Protect — Platform Security (PR.PT)
*   **Alibaba Cloud Mapping:** All public endpoints must tunnel inbound traffic through Web Application Firewall instances configured in strict disruption (Block) mode.

### DE.AE-2: Detection of Anomalous Events and Impact Analysis
*   **Control Objective:** Detected events are analyzed to understand potential impact and attack vectors.
*   **Category:** Detect — Anomalies and Events (DE.AE)
*   **Requirement:** Security tooling must correlate independent telemetry signals to establish a comprehensive attack chain profile.

### RS.RP-1: Response Planning Implementation
*   **Control Objective:** Response processes and procedures are executed and maintained to ensure timely response to detected cybersecurity events.
*   **Category:** Respond — Response Planning (RS.RP)
*   **Requirement:** Mitigation strategies must balance operational availability against data risk. Perimeter containment via IP ACL adjustments is authorized for known-malicious behavior profiles.

> **Demo notice:** This content is fixture data for testing. Run with GRC_MODE=real against a live CISO Assistant instance for real framework data.
'

DEMO_FRAMEWORK_CONTENT_SOC2='---
document_id: soc2-cc6
version: "2026.1"
source: grc
grc_provider: ciso-assistant
framework: SOC2
library_id: demo-soc2
sync_date: "2026-06-16"
---

# SOC 2 Type II — CC6 Logical Access Controls
## Source: CISO Assistant Community (demo mode)

### CC6.1: Boundary Protection and Perimeter Defense
*   **Control Objective:** The organization protects points of entry to the infrastructure containing customer data from unauthorized access.
*   **Trust Services Criterion:** CC6.0 — Logical and Physical Access Controls
*   **Requirement:** All public-facing web applications must be fronted by an active WAF capable of inspecting and blocking layer 7 malicious traffic. Perimeter defenses must log all blocked access attempts. Security team must review perimeter security anomalies at least daily.

### CC6.8: Unauthorized Activity Triage and Mitigation
*   **Control Objective:** The organization prevents, detects, and acts upon unauthorized logical access to infrastructure assets.
*   **Trust Services Criterion:** CC6.0 — Logical and Physical Access Controls
*   **Requirement:** Threat detection mechanisms must be continuously active across all production nodes. Automated blocking mechanisms must be initiated for verified attack patterns. Every automated mitigation action must be traceable to an authoritative system event log and authenticated by an explicit administrative validation window.

> **Demo notice:** This content is fixture data for testing. Run with GRC_MODE=real against a live CISO Assistant instance for real framework data.
'

# =============================================================================
# grc_connect — Authenticate with CISO Assistant
# =============================================================================
grc_connect() {
  if [ "${GRC_MODE:-}" = "demo" ]; then
    echo "[demo] Simulating connection to ${GRC_PROVIDER_DISPLAY_NAME}..." >&2
    echo "[demo] URL: ${GRC_BASE_URL}" >&2
    return 0
  fi

  echo "Connecting to CISO Assistant at ${GRC_BASE_URL}..." >&2

  # If we already have a token, test it
  if [ -n "${GRC_API_TOKEN:-}" ]; then
    echo "  Testing existing token..." >&2
    local test_response
    test_response=$(curl -s ${CURL_SSL_FLAG} -o /dev/null -w "%{http_code}" \
      -H "Authorization: Token ${GRC_API_TOKEN}" \
      "${GRC_BASE_URL}/api/build/" 2>&1) || true

    if [ "$test_response" = "200" ]; then
      echo "  Token is valid." >&2
      return 0
    fi
    echo "  Token expired or invalid. Re-authenticating..." >&2
  fi

  # Authenticate with email + password
  if [ -z "${GRC_EMAIL:-}" ]; then
    echo "ERROR: GRC_EMAIL is not set" >&2
    echo "  Set GRC_EMAIL and GRC_PASSWORD environment variables, or run configure-policies.sh" >&2
    return 1
  fi

  if [ -z "${GRC_PASSWORD:-}" ]; then
    # Try to read from policies.json
    echo "  GRC_PASSWORD not in environment. Checking policies.json..." >&2
  fi

  echo "  Authenticating as ${GRC_EMAIL}..." >&2

  local auth_response
  auth_response=$(curl -s ${CURL_SSL_FLAG} -X POST "${GRC_BASE_URL}/api/iam/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${GRC_EMAIL}\",\"password\":\"${GRC_PASSWORD:-}\"}" 2>&1)

  GRC_API_TOKEN=$(echo "$auth_response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null || echo "")

  if [ -z "${GRC_API_TOKEN:-}" ]; then
    echo "ERROR: Authentication failed" >&2
    echo "  Response: ${auth_response}" >&2
    return 1
  fi

  echo "  Authenticated successfully." >&2
  return 0
}

# =============================================================================
# grc_list_frameworks — List available compliance frameworks
# =============================================================================
grc_list_frameworks() {
  if [ "${GRC_MODE:-}" = "demo" ]; then
    echo "${DEMO_FRAMEWORKS}"
    return 0
  fi

  if [ -z "${GRC_API_TOKEN:-}" ]; then
    echo "ERROR: Not authenticated. Call grc_connect first." >&2
    return 1
  fi

  # Fetch stored libraries (built-in frameworks)
  local stored_json
  stored_json=$(curl -s ${CURL_SSL_FLAG} -X GET "${GRC_BASE_URL}/api/stored-libraries/" \
    -H "Authorization: Token ${GRC_API_TOKEN}" \
    -H "Content-Type: application/json" 2>&1)

  # Fetch loaded libraries (user-loaded frameworks)
  local loaded_json
  loaded_json=$(curl -s ${CURL_SSL_FLAG} -X GET "${GRC_BASE_URL}/api/loaded-libraries/" \
    -H "Authorization: Token ${GRC_API_TOKEN}" \
    -H "Content-Type: application/json" 2>&1)

  # Combine and output as JSON array
  python3 -c "
import sys, json

stored = []
loaded = []

try:
  stored_data = json.loads('''${stored_json}''')
  stored = stored_data.get('results', stored_data) if isinstance(stored_data, dict) else stored_data
  if not isinstance(stored, list):
    stored = []
except:
  pass

try:
  loaded_data = json.loads('''${loaded_json}''')
  loaded = loaded_data.get('results', loaded_data) if isinstance(loaded_data, dict) else loaded_data
  if not isinstance(loaded, list):
    loaded = []
except:
  pass

frameworks = []
for lib in stored + loaded:
  fw = {
    'id': lib.get('id', ''),
    'name': lib.get('name', 'Unknown'),
    'type': lib.get('framework_type', lib.get('type', 'compliance')),
    'description': lib.get('description', '')[:120]
  }
  frameworks.append(fw)

print(json.dumps(frameworks, indent=2))
" 2>/dev/null || echo '[]'
}

# =============================================================================
# grc_get_framework — Export a framework's controls as Markdown
# =============================================================================
grc_get_framework() {
  local library_id="${1:-}"

  if [ -z "$library_id" ]; then
    echo "ERROR: grc_get_framework requires a library_id argument" >&2
    return 1
  fi

  if [ "${GRC_MODE:-}" = "demo" ]; then
    case "$library_id" in
      demo-nist-csf-v2)
        echo "${DEMO_FRAMEWORK_CONTENT_NIST}"
        ;;
      demo-soc2)
        echo "${DEMO_FRAMEWORK_CONTENT_SOC2}"
        ;;
      *)
        echo "ERROR: Unknown demo library_id: ${library_id}" >&2
        return 1
        ;;
    esac
    return 0
  fi

  if [ -z "${GRC_API_TOKEN:-}" ]; then
    echo "ERROR: Not authenticated. Call grc_connect first." >&2
    return 1
  fi

  # Fetch the library metadata
  local lib_json
  lib_json=$(curl -s ${CURL_SSL_FLAG} -X GET "${GRC_BASE_URL}/api/stored-libraries/${library_id}/" \
    -H "Authorization: Token ${GRC_API_TOKEN}" \
    -H "Content-Type: application/json" 2>&1)

  local lib_name
  lib_name=$(echo "$lib_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name','Unknown Framework'))" 2>/dev/null || echo "Unknown Framework")

  local lib_desc
  lib_desc=$(echo "$lib_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description',''))" 2>/dev/null || echo "")

  # Fetch requirement nodes for this library (handle pagination)
  local all_requirements="[]"
  local page_url="${GRC_BASE_URL}/api/requirement-nodes/?library=${library_id}"

  while [ -n "$page_url" ]; do
    local page_json
    page_json=$(curl -s ${CURL_SSL_FLAG} -X GET "$page_url" \
      -H "Authorization: Token ${GRC_API_TOKEN}" \
      -H "Content-Type: application/json" 2>&1)

    # Merge results
    all_requirements=$(python3 -c "
import sys, json
existing = json.loads('''${all_requirements}''')
page = json.loads('''${page_json}''')
results = page.get('results', [])
existing.extend(results)
print(json.dumps(existing))
" 2>/dev/null || echo "$all_requirements")

    # Check for next page
    page_url=$(echo "$page_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('next',''))" 2>/dev/null || echo "")
  done

  # Transform to Markdown
  echo "---"
  echo "document_id: $(echo "${lib_name}" | tr '[:upper:] ' '[:lower:]-' | sed 's/[^a-z0-9-]//g')"
  echo "version: \"2026.1\""
  echo "source: grc"
  echo "grc_provider: ${GRC_PROVIDER_NAME}"
  echo "framework: ${lib_name}"
  echo "library_id: ${library_id}"
  echo "sync_date: \"$(date -u +"%Y-%m-%d")\""
  echo "---"
  echo ""
  echo "# ${lib_name}"
  echo "## Source: CISO Assistant Community"
  echo ""

  if [ -n "$lib_desc" ]; then
    echo "${lib_desc}"
    echo ""
  fi

  # Output each requirement node
  python3 -c "
import sys, json

data = json.loads('''${all_requirements}''')

for req in data:
  ref_id = req.get('ref_id', req.get('display_short', '')).strip()
  name = req.get('name', '')
  description = req.get('description', '')

  if not ref_id and not name:
    continue

  heading = ref_id if ref_id else name
  print(f'### {heading}')
  if name and ref_id:
    print(f'*   **{name}**')
  if description:
    # Clean up description: strip HTML, limit length
    desc = description.replace('<p>','').replace('</p>','\n').replace('<br>','\n').replace('<br/>','\n')
    print(f'*   {desc[:500]}')
  print()
" 2>/dev/null

  echo "> **Synced from CISO Assistant Community on $(date -u +"%Y-%m-%dT%H:%M:%SZ")**"
  echo "> **Library ID:** ${library_id}"
}

# =============================================================================
# Provider self-description
# =============================================================================
grc_describe() {
  echo "${GRC_PROVIDER_DISPLAY_NAME}"
  echo "  ${GRC_PROVIDER_DESCRIPTION}"
  echo "  Provider: ${GRC_PROVIDER_NAME}"
  echo "  URL: ${GRC_BASE_URL}"
}
