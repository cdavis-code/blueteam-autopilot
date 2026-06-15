#!/usr/bin/env bash
# Fetch knowledge document from local skill bundle
# Usage: ./fetch-knowledge.sh <document_type>
# document_type: nist-csf, soc2-cc6, runbook-waf-triage, trusted-networks, asset-inventory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOC_TYPE="${1:-}"

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

DOC_PATH="$SCRIPT_DIR/../documents/${DOC_TYPE}.md"

if [ ! -f "$DOC_PATH" ]; then
  echo "Error: Document '$DOC_TYPE' not found"
  echo ""
  echo "Available documents:"
  ls "$(dirname "$0")/../documents/" 2>/dev/null | sed 's/\.md$//' | sed 's/^/  /'
  exit 1
fi

cat "$DOC_PATH"
