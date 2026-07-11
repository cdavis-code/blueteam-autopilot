#!/usr/bin/env python3
"""GRC sync orchestration script for BlueTeam.

Fetches compliance frameworks from configured GRC providers and writes
them as knowledge documents.

Usage:
    python grc_sync.py [policy_id]       Sync specific policy, or all GRC policies
    python grc_sync.py --list            List all policies and their sync status
    python grc_sync.py --dry-run         Show what would be synced without writing
    python grc_sync.py --providers       List available GRC providers

Environment:
    GRC_MODE=demo                   Use fixture data, no network calls
"""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Add grc-providers dir to path for imports
SCRIPT_DIR = Path(__file__).parent
SKILL_DIR = SCRIPT_DIR.parent
SKILLS_ROOT = SKILL_DIR.parent
PROVIDERS_DIR = SKILL_DIR / "grc-providers"
sys.path.insert(0, str(PROVIDERS_DIR))

from _base import BaseGRCProvider, get_provider, list_providers

POLICIES_FILE = SKILL_DIR / "policies.json"
DOCUMENTS_DIR = SKILL_DIR / "documents"
ARCHIVE_DIR = DOCUMENTS_DIR / "archive"
SYNC_LOG = SKILL_DIR / "sync-log.jsonl"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_policies() -> dict:
    with open(POLICIES_FILE) as f:
        return json.load(f)


def save_policies(data: dict) -> None:
    with open(POLICIES_FILE, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def file_hash(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def extract_yaml_version(path: Path) -> str:
    try:
        for line in path.read_text().splitlines():
            line = line.strip()
            if line.startswith("version:"):
                return line.split(":", 1)[1].strip().strip('"')
    except Exception:
        pass
    return "unknown"


def log_sync_event(policy_id: str, action: str, status: str,
                   grc_version: str = "", local_version: str = "",
                   hash_val: str = "") -> None:
    entry = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "policy_id": policy_id,
        "action": action,
        "status": status,
        "grc_version": grc_version,
        "local_version": local_version,
        "hash": hash_val,
    }
    with open(SYNC_LOG, "a") as f:
        f.write(json.dumps(entry) + "\n")


def validate_controls(content: str, expected_controls: list[str]) -> list[str]:
    missing = [c for c in expected_controls if c not in content]
    return missing


# ---------------------------------------------------------------------------
# --list mode
# ---------------------------------------------------------------------------

def cmd_list() -> None:
    data = load_policies()
    policies = data["policies"]

    max_pid = max(len(p["id"]) for p in policies)
    max_source = max(len(p.get("source", "")) for p in policies)
    max_doc = max(len(p.get("document", "")) for p in policies)
    max_pid = max(max_pid, 12)
    max_source = max(max_source, 8)
    max_doc = max(max_doc, 10)

    print()
    print("╔══════════════════════════════════════════════════════════╗")
    print("║  Policy Sync Status                                      ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print()

    header = f"{'Policy ID':<{max_pid}}  {'Source':<{max_source}}  {'Document':<{max_doc}}  Status"
    print(header)
    print("=" * (max_pid + max_source + max_doc + 45))

    grc_count = 0
    synced_count = 0

    for p in policies:
        pid = p["id"]
        source = p.get("source", "")
        doc = p.get("document", "")

        if source == "grc":
            grc_count += 1
            sync = p.get("sync", {})
            sync_mode = sync.get("mode", "manual")
            last = sync.get("last_sync", "")

            if last:
                synced_count += 1
                status = "✔ synced"
                last_sync_display = last
            else:
                status = "✖ not synced"
                last_sync_display = "never"

            print(f"{pid:<{max_pid}}  {source:<{max_source}}  {doc:<{max_doc}}  {status}")
            print(f"{'':<{max_pid}}  {'':<{max_source}}  │  provider:  {p['grc']['provider']}")
            print(f"{'':<{max_pid}}  {'':<{max_source}}  │  framework: {p['grc']['library_name']}")
            print(f"{'':<{max_pid}}  {'':<{max_source}}  │  sync_mode: {sync_mode}")
            print(f"{'':<{max_pid}}  {'':<{max_source}}  │  last_sync: {last_sync_display}")
            print()
        else:
            print(f"{pid:<{max_pid}}  {source:<{max_source}}  {doc:<{max_doc}}  -")

    print("=" * (max_pid + max_source + max_doc + 45))
    print()
    print(f"Summary: {grc_count} GRC policies, {synced_count} synced, {grc_count - synced_count} pending")
    print()

    # GRC Provider configuration
    provider_cfg = data.get("grc_providers", {}).get("ciso-assistant", {})
    enabled = provider_cfg.get("enabled", False)
    url = provider_cfg.get("base_url", "not configured")
    status_text = "Enabled" if enabled else "Disabled"

    print("GRC Provider Configuration:")
    print(f"  Provider:  ciso-assistant")
    print(f"  Status:    {status_text}")
    print(f"  URL:       {url}")


# ---------------------------------------------------------------------------
# --providers mode
# ---------------------------------------------------------------------------

def cmd_providers() -> None:
    print()
    print("Available GRC Providers")
    print("========================")
    print()
    for name in list_providers():
        try:
            provider = get_provider(name)
            print(provider.describe())
            print()
        except Exception as e:
            print(f"  {name} (error loading: {e})")
            print()


# ---------------------------------------------------------------------------
# Sync mode
# ---------------------------------------------------------------------------

def cmd_sync(policy_filter: str = "", dry_run: bool = False) -> int:
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)

    if dry_run:
        print()
        print("[DRY RUN] No files will be modified.")
        print()

    if policy_filter:
        print()
        print(f"Syncing policy: {policy_filter}")
        print()
    else:
        print()
        print("Syncing all GRC policies")
        print()

    data = load_policies()
    sync_count = 0
    fail_count = 0

    for p in data["policies"]:
        if p.get("source") != "grc":
            continue
        if policy_filter and p["id"] != policy_filter:
            continue

        policy_id = p["id"]
        provider_name = p["grc"]["provider"]
        library_name = p["grc"]["library_name"]
        framework_id = p["grc"].get("framework_id", "")
        doc_file = p["document"]
        controls = p.get("controls", [])
        doc_path = DOCUMENTS_DIR / Path(doc_file).name

        print(f"[{policy_id}] {library_name}")
        print(f"  Provider:  {provider_name}")
        print(f"  Document:  {doc_file}")
        print()

        # Load provider
        try:
            provider = get_provider(provider_name)
        except Exception as e:
            print(f"  ERROR: Cannot load provider '{provider_name}': {e}")
            fail_count += 1
            continue

        # Connect
        print(f"  Connecting to {provider.DISPLAY_NAME}... ", end="")
        if not provider.connect():
            print("FAILED")
            fail_count += 1
            continue
        print("OK")

        # Determine library ID
        if framework_id and framework_id != "null":
            use_library_id = framework_id
        else:
            print("  Looking up framework by name... ", end="")
            frameworks = provider.list_frameworks()
            use_library_id = ""
            for fw in frameworks:
                if fw.get("name", "") == library_name:
                    use_library_id = fw["id"]
                    break
            if not use_library_id:
                print("NOT FOUND")
                print(f"  WARNING: Could not find framework '{library_name}' in GRC platform.")
                print("  Available frameworks:")
                for fw in frameworks[:10]:
                    print(f"    - {fw['name']}")
                fail_count += 1
                continue
            print(f"Found ({use_library_id})")

        # Get framework content
        print("  Fetching framework content... ", end="")
        framework_content = provider.get_framework(use_library_id)
        if not framework_content:
            print("EMPTY RESPONSE")
            fail_count += 1
            log_sync_event(policy_id, "sync", "failed")
            continue

        line_count = len(framework_content.splitlines())
        print(f"OK ({line_count} lines)")

        # Extract version
        grc_version = "unknown"
        for line in framework_content.splitlines():
            line = line.strip()
            if line.startswith("version:"):
                grc_version = line.split(":", 1)[1].strip().strip('"')
                break

        # Validate controls
        if controls:
            print("  Validating expected controls... ", end="")
            missing = validate_controls(framework_content, controls)
            if not missing:
                print("ALL PRESENT")
            else:
                print(f"WARNING: Some expected controls may be missing: {', '.join(missing)}")

        # Write document
        if dry_run:
            print(f"  [DRY RUN] Would write to: {doc_path}")
        else:
            # Human review gate
            if doc_path.exists():
                current_version = extract_yaml_version(doc_path)
                current_hash = file_hash(doc_path)

                print(f"  Proposed changes to {doc_path}:")
                # Simple diff output
                current_lines = doc_path.read_text().splitlines()
                new_lines = framework_content.splitlines()
                if current_lines == new_lines:
                    print("  (no changes)")
                else:
                    print(f"  Current: {len(current_lines)} lines, New: {len(new_lines)} lines")

                try:
                    confirm = input("  Apply this update? [y/N] ")
                except EOFError:
                    confirm = "n"
                if not confirm.lower().startswith("y"):
                    print("  Skipped.")
                    fail_count += 1
                    continue
            else:
                current_version = "none"
                current_hash = ""
                print(f"  New document will be created at: {doc_path}")
                try:
                    confirm = input("  Create this document? [y/N] ")
                except EOFError:
                    confirm = "n"
                if not confirm.lower().startswith("y"):
                    print("  Skipped.")
                    fail_count += 1
                    continue

            # Archive current version
            if doc_path.exists():
                timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                archive_path = ARCHIVE_DIR / f"{doc_path.stem}-backup-{timestamp}.md"
                archive_path.write_text(doc_path.read_text())
                print(f"  Archived previous version to: {archive_path}")

            # Write new content
            doc_path.write_text(framework_content)
            new_hash = file_hash(doc_path)

            # Update policies.json
            for pol in data["policies"]:
                if pol["id"] == policy_id:
                    pol.setdefault("sync", {})["last_sync"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                    pol.setdefault("sync", {})["grc_version"] = grc_version
                    if use_library_id:
                        pol.setdefault("grc", {})["framework_id"] = use_library_id
                    break
            save_policies(data)

            log_sync_event(policy_id, "sync", "success", grc_version, current_version, new_hash)
            print(f"  Written to: {doc_path}")

        sync_count += 1
        print()

    # Summary
    print("----------------------------------------")
    if dry_run:
        print(f"[DRY RUN] Would sync {sync_count} policies ({fail_count} would fail)")
    else:
        if fail_count == 0:
            print(f"Sync complete: {sync_count} policies synced successfully.")
        else:
            print(f"Sync complete: {sync_count} successful, {fail_count} failed.")
    print()

    return 1 if fail_count > 0 else 0


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    args = sys.argv[1:]

    if "--list" in args:
        cmd_list()
        return 0

    if "--providers" in args:
        cmd_providers()
        return 0

    dry_run = "--dry-run" in args
    if dry_run:
        args.remove("--dry-run")

    policy_filter = args[0] if args else ""

    return cmd_sync(policy_filter=policy_filter, dry_run=dry_run)


if __name__ == "__main__":
    sys.exit(main())
