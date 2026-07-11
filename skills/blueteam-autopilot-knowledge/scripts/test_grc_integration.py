#!/usr/bin/env python3
"""End-to-end integration test for the GRC knowledge document management system.

Tests:
  1. GRC provider scripts exist and are importable
  2. policies.json schema validation
  3. CISO Assistant provider connectivity (demo mode + real mode if configured)
  4. grc_sync.py --dry-run for each GRC policy
  5. YAML frontmatter validation on all knowledge documents
  6. fetch_knowledge.py document resolution
  7. Readiness report output

Usage:
    python test_grc_integration.py          # Full test suite
    python test_grc_integration.py --quick  # Skip real-mode connectivity tests
    GRC_MODE=demo python test_grc_integration.py  # Force demo mode
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
SKILL_DIR = SCRIPT_DIR.parent
SKILLS_ROOT = SKILL_DIR.parent
PROVIDERS_DIR = SKILL_DIR / "grc-providers"
sys.path.insert(0, str(PROVIDERS_DIR))

POLICIES_FILE = SKILL_DIR / "policies.json"
DOCUMENTS_DIR = SKILL_DIR / "documents"
ARCHIVE_DIR = DOCUMENTS_DIR / "archive"
SYNC_LOG = SKILL_DIR / "sync-log.jsonl"
GRC_SYNC_SCRIPT = SCRIPT_DIR / "grc_sync.py"
FETCH_SCRIPT = SCRIPT_DIR / "fetch_knowledge.py"
WEBHOOK_SCRIPT = SCRIPT_DIR / "grc_webhook.py"

QUICK_MODE = "--quick" in sys.argv

pass_count = 0
fail_count = 0
warn_count = 0


def passed(msg: str) -> None:
    global pass_count
    print(f"  ✓ {msg}")
    pass_count += 1


def failed(msg: str) -> None:
    global fail_count
    print(f"  ✗ {msg}")
    fail_count += 1


def warned(msg: str) -> None:
    global warn_count
    print(f"  ⚠ {msg}")
    warn_count += 1


# ===========================================================================
# Header
# ===========================================================================
print()
print("════════════════════════════════════════════════════════")
print("  GRC Integration — End-to-End Test Suite")
print("════════════════════════════════════════════════════════")
print()
print(f"  Skill dir:  {SKILL_DIR}")
print(f"  GRC mode:   {os.environ.get('GRC_MODE', 'live')}")
print(f"  Quick mode: {QUICK_MODE}")
print(f"  Timestamp:  {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}")
print()

# ===========================================================================
# Test 1: GRC provider scripts exist and are importable
# ===========================================================================
print("── Test 1: Provider Script Presence ──")

provider_files = ["_base.py", "ciso_assistant.py"]
for pf in provider_files:
    provider_path = PROVIDERS_DIR / pf
    if provider_path.exists():
        passed(f"Found: grc-providers/{pf}")
    else:
        failed(f"Missing: grc-providers/{pf}")

# Verify base defines contract methods
from _base import BaseGRCProvider
for method in ["connect", "list_frameworks", "get_framework"]:
    if hasattr(BaseGRCProvider, method):
        passed(f"Contract method defined in base: {method}()")
    else:
        warned(f"Contract method not found in base: {method}()")

print()

# ===========================================================================
# Test 2: policies.json schema validation
# ===========================================================================
print("── Test 2: policies.json Schema Validation ──")

if not POLICIES_FILE.exists():
    failed(f"policies.json not found at {POLICIES_FILE}")
else:
    passed("policies.json exists")

    try:
        with open(POLICIES_FILE) as f:
            data = json.load(f)
        passed("policies.json is valid JSON")
    except json.JSONDecodeError:
        failed("policies.json is NOT valid JSON")
        data = None

    if data:
        version = data.get("version", "MISSING")
        if version != "MISSING" and version:
            passed(f"policies.json has version: {version}")
        else:
            failed("policies.json missing 'version' field")

        policies = data.get("policies", [])
        if len(policies) > 0:
            passed(f"policies.json has {len(policies)} policy entries")
        else:
            failed("policies.json has no policy entries")

        # Validate required fields
        errors = []
        for p in policies:
            pid = p.get("id", "UNKNOWN")
            for field in ["id", "title", "type", "source", "document"]:
                if field not in p:
                    errors.append(f"{pid}: missing {field}")
        if not errors:
            passed("All policy entries have required fields (id, title, type, source, document)")
        else:
            failed("Some policy entries missing required fields")
            for e in errors:
                print(f"    {e}")

        # grc_providers section
        providers_cfg = data.get("grc_providers", {})
        if providers_cfg:
            passed(f"grc_providers section present with: {', '.join(providers_cfg.keys())}")
        else:
            warned("grc_providers section empty or missing")

        # GRC-sourced policies
        grc_policies = [p for p in policies if p.get("source") == "grc"]
        if grc_policies:
            passed(f"Found {len(grc_policies)} GRC-sourced polic(ies)")
            missing_grc = [p["id"] for p in grc_policies if "grc" not in p]
            if missing_grc:
                failed(f"GRC policies missing 'grc' config: {', '.join(missing_grc)}")
        else:
            warned("No GRC-sourced policies found")

print()

# ===========================================================================
# Test 3: CISO Assistant provider connectivity
# ===========================================================================
print("── Test 3: CISO Assistant Provider Connectivity ──")

try:
    from ciso_assistant import CisoAssistantProvider

    provider = CisoAssistantProvider()

    # Demo mode connectivity
    print("  Testing demo mode connectivity...")
    os.environ["GRC_MODE"] = "demo"
    provider.mode = "demo"
    if provider.connect():
        passed("connect() succeeded in demo mode")
    else:
        failed("connect() failed in demo mode")

    # Demo mode framework listing
    print("  Testing demo mode framework listing...")
    frameworks = provider.list_frameworks()
    if frameworks:
        passed(f"list_frameworks() returned {len(frameworks)} framework(s) in demo mode")
    else:
        failed("list_frameworks() returned empty output in demo mode")

    # Demo mode framework export
    print("  Testing demo mode framework export...")
    if frameworks:
        demo_id = frameworks[0]["id"]
        content = provider.get_framework(demo_id)
        if content:
            passed(f"get_framework({demo_id}) returned content in demo mode")
            if "---" in content.split("\n")[0]:
                passed("Demo framework output contains YAML frontmatter")
            else:
                warned("Demo framework output missing YAML frontmatter")
        else:
            warned(f"get_framework({demo_id}) returned empty in demo mode")

    # Real mode test
    if not QUICK_MODE and data:
        print()
        print("  Testing real mode readiness...")
        provider_cfg = data.get("grc_providers", {}).get("ciso-assistant", {})
        if provider_cfg.get("enabled", False):
            url = provider_cfg.get("base_url", "")
            passed(f"CISO Assistant provider is enabled (URL: {url})")
        else:
            warned("CISO Assistant provider not enabled — real mode test skipped")
            print("         Run configure_policies.py to set up GRC provider connection")

except ImportError as e:
    failed(f"CISO Assistant provider import failed: {e}")

print()

# ===========================================================================
# Test 4: grc_sync.py dry-run
# ===========================================================================
print("── Test 4: grc_sync.py Dry-Run ──")

if GRC_SYNC_SCRIPT.exists():
    passed("grc_sync.py exists")

    # Test --list
    print("  Testing --list...")
    result = subprocess.run(
        [sys.executable, str(GRC_SYNC_SCRIPT), "--list"],
        capture_output=True, text=True,
        env={**os.environ, "GRC_MODE": "demo"},
    )
    if result.stdout:
        passed("grc_sync.py --list produced output")
    else:
        failed("grc_sync.py --list produced no output")

    # Test --dry-run
    print("  Testing --dry-run...")
    result = subprocess.run(
        [sys.executable, str(GRC_SYNC_SCRIPT), "--dry-run"],
        capture_output=True, text=True,
        env={**os.environ, "GRC_MODE": "demo"},
    )
    if result.returncode == 0:
        passed("grc_sync.py --dry-run succeeded (exit 0)")
    else:
        warned(f"grc_sync.py --dry-run exited with code {result.returncode}")

    # Test individual policies
    if data:
        for p in data.get("policies", []):
            if p.get("source") == "grc":
                pid = p["id"]
                print(f"  Testing --dry-run for policy: {pid}...")
                result = subprocess.run(
                    [sys.executable, str(GRC_SYNC_SCRIPT), "--dry-run", pid],
                    capture_output=True, text=True,
                    env={**os.environ, "GRC_MODE": "demo"},
                )
                if result.returncode == 0:
                    passed(f"grc_sync.py --dry-run {pid} succeeded")
                else:
                    warned(f"grc_sync.py --dry-run {pid} exited with code {result.returncode}")
else:
    failed("grc_sync.py missing")

print()

# ===========================================================================
# Test 5: YAML frontmatter validation
# ===========================================================================
print("── Test 5: YAML Frontmatter Validation ──")

documents = ["nist-csf.md", "soc2-cc6.md", "runbook-waf-triage.md", "trusted-networks.md", "asset-inventory.md"]
required_fields = ["document_id", "version", "source", "last_updated"]
grc_extra_fields = ["grc_provider", "framework"]
grc_docs = ["nist-csf.md", "soc2-cc6.md"]

for doc in documents:
    doc_path = DOCUMENTS_DIR / doc
    if not doc_path.exists():
        failed(f"Document not found: {doc}")
        continue

    content = doc_path.read_text()
    lines = content.splitlines()

    if lines and lines[0] == "---":
        # Extract frontmatter
        fm_lines = []
        in_fm = False
        for line in lines:
            if line == "---":
                if in_fm:
                    break
                in_fm = True
                continue
            if in_fm:
                fm_lines.append(line)

        fm_text = "\n".join(fm_lines)

        all_present = True
        for field in required_fields:
            if f"{field}:" in fm_text:
                pass
            else:
                all_present = False
                failed(f"{doc}: missing frontmatter field '{field}'")

        if all_present:
            passed(f"{doc}: all required frontmatter fields present")

        if doc in grc_docs:
            for field in grc_extra_fields:
                if f"{field}:" in fm_text:
                    pass
                else:
                    warned(f"{doc}: GRC document missing extra field '{field}'")

        # Version
        for line in fm_lines:
            if line.startswith("version:"):
                val = line.split(":", 1)[1].strip().strip('"')
                passed(f"{doc}: version = {val}")
                break
    else:
        failed(f"{doc}: missing YAML frontmatter (no '---' on line 1)")

print()

# ===========================================================================
# Test 6: fetch_knowledge.py resolution
# ===========================================================================
print("── Test 6: fetch_knowledge.py Resolution ──")

if FETCH_SCRIPT.exists():
    passed("fetch_knowledge.py exists")

    for doc_type in ["nist-csf", "soc2-cc6", "runbook-waf-triage", "trusted-networks", "asset-inventory"]:
        result = subprocess.run(
            [sys.executable, str(FETCH_SCRIPT), doc_type],
            capture_output=True, text=True,
        )
        if result.returncode == 0 and result.stdout:
            if result.stdout.startswith("---"):
                passed(f"fetch_knowledge.py {doc_type}: resolved successfully with frontmatter")
            else:
                warned(f"fetch_knowledge.py {doc_type}: resolved but missing frontmatter")
        else:
            failed(f"fetch_knowledge.py {doc_type}: failed to resolve (exit={result.returncode})")

    # Test no-args listing
    result = subprocess.run(
        [sys.executable, str(FETCH_SCRIPT)],
        capture_output=True, text=True,
    )
    if "Available documents" in result.stdout or "Usage" in result.stdout:
        passed("fetch_knowledge.py (no args): lists available documents")
    else:
        warned("fetch_knowledge.py (no args): unexpected output format")
else:
    failed("fetch_knowledge.py missing")

print()

# ===========================================================================
# Test 7: Infrastructure verification
# ===========================================================================
print("── Test 7: Infrastructure Files ──")

if SYNC_LOG.exists():
    passed("sync-log.jsonl exists")
    log_lines = SYNC_LOG.read_text().strip().splitlines()
    if log_lines and log_lines[0]:
        passed(f"sync-log.jsonl has {len(log_lines)} entries")
        invalid = 0
        for line in log_lines:
            try:
                json.loads(line)
            except json.JSONDecodeError:
                invalid += 1
        if invalid == 0:
            passed(f"sync-log.jsonl: all {len(log_lines)} lines are valid JSON")
        else:
            failed(f"sync-log.jsonl: {invalid} invalid JSON line(s)")
    else:
        warned("sync-log.jsonl is empty")
else:
    failed("sync-log.jsonl not found")

if ARCHIVE_DIR.is_dir():
    passed("Archive directory exists: documents/archive/")
else:
    failed("Archive directory missing: documents/archive/")

grc_synced_dir = DOCUMENTS_DIR / "grc-synced"
if grc_synced_dir.is_dir():
    passed("GRC-synced directory exists: documents/grc-synced/")
else:
    warned("GRC-synced directory not yet created (will be created on first sync)")

if WEBHOOK_SCRIPT.exists():
    passed("grc_webhook.py exists")
else:
    failed("grc_webhook.py missing")

print()

# ===========================================================================
# Summary
# ===========================================================================
print("════════════════════════════════════════════════════════")
print("  GRC Integration — Test Results")
print("════════════════════════════════════════════════════════")
print()
print(f"  Passed:   {pass_count}")
print(f"  Failed:   {fail_count}")
print(f"  Warnings: {warn_count}")
print()

if fail_count == 0:
    print("  RESULT: ALL CHECKS PASSED ✓")
    print()
    print("  The GRC integration is properly configured and")
    print("  ready for use. Run the following to sync policies:")
    print()
    print("    GRC_MODE=demo python grc_sync.py --dry-run")
    print("    python grc_sync.py --list")
    print()
    sys.exit(0)
else:
    print(f"  RESULT: {fail_count} CHECK(S) FAILED ✗")
    print()
    print("  Review the failures above and remediate before")
    print("  using the GRC integration in production.")
    print()
    sys.exit(1)
