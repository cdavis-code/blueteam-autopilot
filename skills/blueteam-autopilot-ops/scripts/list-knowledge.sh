#!/usr/bin/env bash
# List all available knowledge documents
# Usage: ./list-knowledge.sh
#
# Knowledge documents include compliance controls (NIST CSF, SOC 2),
# runbooks, change management policies, asset inventory, and trusted networks.

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

# ----- Demo mode: return fixture data -----
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/knowledge_list.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  else
    echo "{\"error\": \"Fixture not found: $FIXTURE_FILE.\"}"
    exit 1
  fi
fi
# ----- End demo mode -----


# Knowledge directories (checked in order)
KNOWLEDGE_DIRS=(
  "${KNOWLEDGE_DIR:-}"
  "$(dirname "$SCRIPT_DIR")/../../../packages/alibaba_security_mcp/knowledge"
  "$(dirname "$SCRIPT_DIR")/../../blueteam-autopilot-knowledge/documents"
  "$(dirname "$SCRIPT_DIR")/../../../secops"
)

# Document registry (type → filename → title)
declare -A DOC_FILES=(
  [asset_inventory]="asset_inventory.md"
  [trusted_networks]="trusted_networks.md"
  [compliance_nist]="compliance_nist.md"
  [compliance_soc2]="compliance_soc2.md"
  [runbook_waf_triage]="runbook_waf_triage.md"
  [policy_change_mgmt]="policy_change_mgmt.md"
)

declare -A DOC_TITLES=(
  [asset_inventory]="Asset Inventory — Network Topology"
  [trusted_networks]="Trusted Networks / IP Whitelist"
  [compliance_nist]="NIST CSF Controls (Detect & Respond)"
  [compliance_soc2]="SOC 2 Type II — CC6.0 Logical Access Controls"
  [runbook_waf_triage]="Runbook: WAF Perimeter Threat Triage (RUN-SEC-042)"
  [policy_change_mgmt]="Change Management Guidelines"
)

echo "Available Knowledge Documents"
echo "=============================="
echo ""

# Find active knowledge directory
ACTIVE_DIR=""
for dir in "${KNOWLEDGE_DIRS[@]}"; do
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    ACTIVE_DIR="$dir"
    break
  fi
done

FOUND=0
for doc_type in $(echo "${!DOC_FILES[@]}" | tr ' ' '\n' | sort); do
  filename="${DOC_FILES[$doc_type]}"
  title="${DOC_TITLES[$doc_type]}"
  
  source="not found"
  if [ -n "$ACTIVE_DIR" ] && [ -f "$ACTIVE_DIR/$filename" ]; then
    source="file://$ACTIVE_DIR/$filename"
    FOUND=$((FOUND + 1))
  fi
  
  printf "  %-25s %s\n" "$doc_type" "$title"
  echo "    Source: $source"
  echo ""
done

echo "=============================="
echo "Found $FOUND document(s) in: ${ACTIVE_DIR:-none}"
echo ""
echo "To fetch a document:"
echo "  ./get-knowledge.sh <document_type>"
echo ""
echo "Example:"
echo "  ./get-knowledge.sh compliance_nist"
