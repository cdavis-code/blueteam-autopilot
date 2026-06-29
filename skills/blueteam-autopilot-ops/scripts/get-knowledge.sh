#!/usr/bin/env bash
# Retrieve a knowledge document by type
# Usage: ./get-knowledge.sh <document_type>
#
# Document types:
#   asset_inventory     — Network topology and asset classification
#   trusted_networks    — IP whitelist & escalation rules
#   compliance_nist     — NIST CSF Detect & Respond controls
#   compliance_soc2     — SOC 2 Type II CC6.0 Logical Access Controls
#   runbook_waf_triage  — WAF perimeter threat triage (RUN-SEC-042)
#   policy_change_mgmt  — Change management guidelines

set -euo pipefail

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$PWD/.env" ]; then
  source "$PWD/.env" 2>/dev/null || true
elif [ -f "$(dirname "$SCRIPT_DIR")/../../../.env" ]; then
  source "$(dirname "$SCRIPT_DIR")/../../../.env" 2>/dev/null || true
fi

DOC_TYPE="${1:-}"
if [ -z "$DOC_TYPE" ]; then
  echo "Usage: $0 <document_type>"
  echo ""
  echo "Valid types:"
  echo "  asset_inventory     — Network topology"
  echo "  trusted_networks    — IP whitelist & escalation rules"
  echo "  compliance_nist     — NIST CSF controls"
  echo "  compliance_soc2     — SOC 2 CC6 controls"
  echo "  runbook_waf_triage  — WAF triage runbook"
  echo "  policy_change_mgmt  — Change management policy"
  exit 1
fi

# Map document type to filename
case "$DOC_TYPE" in
  asset_inventory)    FILENAME="asset-inventory.md" ;;
  trusted_networks)   FILENAME="trusted-networks.md" ;;
  compliance_nist)    FILENAME="nist-csf.md" ;;
  compliance_soc2)    FILENAME="soc2-cc6.md" ;;
  runbook_waf_triage) FILENAME="runbook-waf-triage.md" ;;
  policy_change_mgmt) FILENAME="policy_change_mgmt.md" ;;
  *)
    echo "Error: Unknown document type '$DOC_TYPE'"
    echo "Valid types: asset_inventory, trusted_networks, compliance_nist,"
    echo "  compliance_soc2, runbook_waf_triage, policy_change_mgmt"
    exit 1
    ;;
esac

# Knowledge directories (checked in order)
KNOWLEDGE_DIRS=(
  "${KNOWLEDGE_DIR:-}"
  "$(dirname "$SCRIPT_DIR")/../../../packages/alibaba_security_mcp/knowledge"
  "$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-knowledge/documents"
  "$(dirname "$SCRIPT_DIR")/../../../secops"
)

# Find the document
FOUND_FILE=""
for dir in "${KNOWLEDGE_DIRS[@]}"; do
  if [ -n "$dir" ] && [ -f "$dir/$FILENAME" ]; then
    FOUND_FILE="$dir/$FILENAME"
    break
  fi
done

if [ -n "$FOUND_FILE" ]; then
  LAST_MODIFIED=$(stat -f "%Sm" "$FOUND_FILE" 2>/dev/null || stat -c "%y" "$FOUND_FILE" 2>/dev/null || echo "unknown")
  
  echo "Document: $DOC_TYPE"
  echo "Source: $FOUND_FILE"
  echo "Modified: $LAST_MODIFIED"
  echo "---"
  echo ""
  cat "$FOUND_FILE"
else
  echo "Error: Document '$DOC_TYPE' not found ($FILENAME)"
  echo ""
  echo "Searched directories:"
  for dir in "${KNOWLEDGE_DIRS[@]}"; do
    [ -n "$dir" ] && echo "  - $dir"
  done
  echo ""
  echo "Set KNOWLEDGE_DIR to override the search path:"
  echo "  export KNOWLEDGE_DIR=/path/to/knowledge"
  exit 1
fi
