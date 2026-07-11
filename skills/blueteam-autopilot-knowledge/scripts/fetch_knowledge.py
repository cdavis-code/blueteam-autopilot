#!/usr/bin/env python3
"""Fetch knowledge document from local skill bundle.

Implements source-priority resolution:
  1. GRC-synced version (if source=grc and sync has been performed)
  2. Bundled/default version in documents/
  3. Logs a warning if GRC is enabled but document hasn't been synced

Usage: python fetch_knowledge.py <document_type>
  document_type: nist-csf, soc2-cc6, runbook-waf-triage, trusted-networks, asset-inventory
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent
SKILL_DIR = SCRIPT_DIR.parent
SKILLS_ROOT = SKILL_DIR.parent
POLICIES_FILE = SKILL_DIR / "policies.json"
DOCUMENTS_DIR = SKILL_DIR / "documents"


def list_available_documents() -> list[str]:
    """List available document types from the documents directory."""
    docs_dir = DOCUMENTS_DIR
    if not docs_dir.is_dir():
        return []
    return sorted(
        f.stem for f in docs_dir.iterdir()
        if f.suffix == ".md" and f.is_file()
    )


def get_policy_source(doc_type: str) -> str:
    """Get the source type for a document from policies.json."""
    if not POLICIES_FILE.exists():
        return "unknown"
    try:
        with open(POLICIES_FILE) as f:
            data = json.load(f)
        for p in data.get("policies", []):
            if p.get("id") == doc_type:
                return p.get("source", "manual")
    except (json.JSONDecodeError, KeyError):
        pass
    return "unknown"


def get_policy_last_sync(doc_type: str) -> str:
    """Get the last sync timestamp for a document from policies.json."""
    if not POLICIES_FILE.exists():
        return ""
    try:
        with open(POLICIES_FILE) as f:
            data = json.load(f)
        for p in data.get("policies", []):
            if p.get("id") == doc_type:
                return p.get("sync", {}).get("last_sync", "")
    except (json.JSONDecodeError, KeyError):
        pass
    return ""


def resolve_document_path(doc_type: str) -> Path | None:
    """Resolve document path with source priority."""
    default_path = DOCUMENTS_DIR / f"{doc_type}.md"
    grc_path = DOCUMENTS_DIR / "grc-synced" / f"{doc_type}.md"

    # Check if this document is GRC-sourced
    source = get_policy_source(doc_type)

    if source == "grc":
        last_sync = get_policy_last_sync(doc_type)
        if last_sync and grc_path.exists():
            # GRC synced version exists — use it
            return grc_path
        elif default_path.exists():
            # GRC enabled but not synced — warn and use default
            print(f"[WARN] GRC sync enabled for '{doc_type}' but document not yet synced.", file=sys.stderr)
            print(f"[WARN] Using bundled default. Run 'grc_sync.py {doc_type}' to sync.", file=sys.stderr)
            return default_path

    # Fall through: use default path
    if default_path.exists():
        return default_path

    return None


def main() -> int:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <document_type>")
        print()
        print("Available documents:")
        for doc in list_available_documents():
            print(f"  {doc}")
        print()
        print("Examples:")
        print(f"  {sys.argv[0]} nist-csf")
        print(f"  {sys.argv[0]} soc2-cc6")
        print(f"  {sys.argv[0]} runbook-waf-triage")
        return 1

    doc_type = sys.argv[1]
    doc_path = resolve_document_path(doc_type)

    if doc_path is None or not doc_path.exists():
        print(f"Error: Document '{doc_type}' not found", file=sys.stderr)
        print()
        print("Available documents:")
        for doc in list_available_documents():
            print(f"  {doc}")
        return 1

    print(doc_path.read_text())
    return 0


if __name__ == "__main__":
    sys.exit(main())
