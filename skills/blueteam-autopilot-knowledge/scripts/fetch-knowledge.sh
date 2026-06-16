#!/usr/bin/env bash
# Fetch knowledge document from local skill bundle.
# Implements source-priority resolution:
#   1. GRC-synced version (if source=grc and sync has been performed)
#   2. Bundled/default version in documents/
#   3. Logs a warning if GRC is enabled but document hasn't been synced
#
# Usage: ./fetch-knowledge.sh <document_type>
# document_type: nist-csf, soc2-cc6, runbook-waf-triage, trusted-networks, asset-inventory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOC_TYPE="${1:-}"
SKILLS_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POLICIES_FILE="${SKILLS_ROOT}/blueteam-autopilot-knowledge/policies.json"

if [ -z "$DOC_TYPE" ]; then
  echo "Usage: $0 <document_type>"
  echo ""
  echo "Available documents:"
  ls "$(dirname "$0")/../documents/" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  /'
  echo ""
  echo "Examples:"
  echo "  $0 nist-csf"
  echo "  $0 soc2-cc6"
  echo "  $0 runbook-waf-triage"
  exit 1
fi

# ===========================================================================
# Resolve document path with source priority
# ===========================================================================

resolve_document_path() {
  local doc_type="$1"

  # Try: documents/<doc>.md (default location)
  local default_path="$SCRIPT_DIR/../documents/${doc_type}.md"

  # Try: documents/grc-synced/<doc>.md (GRC synced version)
  local grc_path="$SCRIPT_DIR/../documents/grc-synced/${doc_type}.md"

  # Check if policies.json exists and this document is GRC-sourced
  if [ -f "$POLICIES_FILE" ]; then
    local source
    source=$(python3 -c "
import json
try:
  with open('$POLICIES_FILE') as f:
    data = json.load(f)
  for p in data['policies']:
    if p['id'] == '$doc_type':
      print(p.get('source','manual'))
      break
except:
  print('unknown')
" 2>/dev/null || echo "unknown")

    if [ "$source" = "grc" ]; then
      local last_sync
      last_sync=$(python3 -c "
import json
try:
  with open('$POLICIES_FILE') as f:
    data = json.load(f)
  for p in data['policies']:
    if p['id'] == '$doc_type':
      print(p.get('sync',{}).get('last_sync',''))
      break
except:
  pass
" 2>/dev/null || echo "")

      if [ -n "$last_sync" ] && [ -f "$grc_path" ]; then
        # GRC synced version exists — use it
        echo "$grc_path"
        return 0
      elif [ -f "$default_path" ]; then
        # GRC enabled but not synced — warn and use default
        >&2 echo "[WARN] GRC sync enabled for '$doc_type' but document not yet synced."
        >&2 echo "[WARN] Using bundled default. Run 'grc-sync.sh $doc_type' to sync."
        echo "$default_path"
        return 0
      fi
    fi
  fi

  # Fall through: use default path
  if [ -f "$default_path" ]; then
    echo "$default_path"
    return 0
  fi

  return 1
}

DOC_PATH=$(resolve_document_path "$DOC_TYPE")

if [ -z "$DOC_PATH" ] || [ ! -f "$DOC_PATH" ]; then
  echo "Error: Document '$DOC_TYPE' not found"
  echo ""
  echo "Available documents:"
  ls "$(dirname "$0")/../documents/" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  /'
  exit 1
fi

cat "$DOC_PATH"
