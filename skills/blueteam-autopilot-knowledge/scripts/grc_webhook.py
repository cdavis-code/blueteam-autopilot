#!/usr/bin/env python3
"""Webhook receiver for event-driven GRC sync.

Accepts JSON on stdin or via --request-body, matches the event to
configured policies, and triggers grc_sync for matching policies.

Usage:
    echo '{"event":"framework_update","library":"NIST CSF v2.0"}' | python grc_webhook.py
    python grc_webhook.py --request-body '{"event":"framework_update","library":"SOC2"}'

Environment:
    GRC_MODE=demo                     Use fixture data, no network calls
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent
SKILL_DIR = SCRIPT_DIR.parent
POLICIES_FILE = SKILL_DIR / "policies.json"
GRC_SYNC_SCRIPT = SCRIPT_DIR / "grc_sync.py"


def main() -> int:
    args = sys.argv[1:]

    # Parse request body
    request_body = ""
    if len(args) >= 2 and args[0] == "--request-body":
        request_body = args[1]
    elif not sys.stdin.isatty():
        request_body = sys.stdin.read()
    else:
        print(f"Usage: {sys.argv[0]} --request-body '<json>'")
        print(f"   or: echo '<json>' | {sys.argv[0]}")
        print()
        print("Event format:")
        print('  {"event":"framework_update","library":"<library name>"}')
        print('  {"event":"sync_all"}')
        return 1

    print()
    print("=== GRC Webhook Receiver ===")
    print()

    # Parse event
    try:
        event_data = json.loads(request_body)
    except json.JSONDecodeError:
        print("ERROR: Invalid JSON input")
        return 1

    event = event_data.get("event", "unknown")
    library = event_data.get("library", "")

    print(f"  Event:   {event}")
    print(f"  Library: {library or '<none>'}")
    print()

    # Match event to policies
    if event == "framework_update":
        if not library:
            print("ERROR: 'framework_update' event requires a 'library' field")
            return 1

        # Find matching policy
        matched = ""
        try:
            with open(POLICIES_FILE) as f:
                data = json.load(f)
            for p in data["policies"]:
                if p.get("source") == "grc" and library in p.get("grc", {}).get("library_name", ""):
                    matched = p["id"]
                    break
        except (json.JSONDecodeError, KeyError, FileNotFoundError):
            pass

        if matched:
            print(f"  Matched policy: {matched}")
            print()
            print("  Triggering sync...")
            result = subprocess.run(
                [sys.executable, str(GRC_SYNC_SCRIPT), matched],
                cwd=str(SKILL_DIR.parent.parent),
            )
            return result.returncode
        else:
            print(f"  No matching policy found for library '{library}'.")
            print("  Check policies.json to ensure a GRC-sourced policy references this library.")
            return 0

    elif event == "sync_all":
        print("  Triggering full sync...")
        result = subprocess.run(
            [sys.executable, str(GRC_SYNC_SCRIPT)],
            cwd=str(SKILL_DIR.parent.parent),
        )
        return result.returncode

    else:
        print(f"  Unknown event type: {event}")
        print("  Supported events: framework_update, sync_all")
        return 1


if __name__ == "__main__":
    print()
    exit_code = main()
    if exit_code == 0:
        print("Webhook processing complete.")
    print()
    sys.exit(exit_code)
