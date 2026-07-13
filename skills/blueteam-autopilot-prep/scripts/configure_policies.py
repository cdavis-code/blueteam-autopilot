#!/usr/bin/env python3
"""Interactive configuration wizard for BlueTeam compliance policies.

Replaces configure-policies.sh with Python equivalent.
Usage: python configure_policies.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


# ANSI color codes
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
BOLD = "\033[1m"
NC = "\033[0m"


def read_json_field(data: dict, path: str) -> Any:
    """Read a value from nested dict using dot-separated path."""
    keys = path.split(".")
    val: Any = data
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k, "")
        else:
            val = ""
    if isinstance(val, bool):
        return "true" if val else "false"
    if val is None:
        return ""
    return str(val)


def write_json_field(data: dict, path: str, new_value: str) -> None:
    """Write a value to nested dict using dot-separated path."""
    keys = path.split(".")
    parent = data
    for k in keys[:-1]:
        if k not in parent:
            parent[k] = {}
        parent = parent[k]
    last_key = keys[-1]
    # Auto-detect type
    if new_value.lower() in ("true", "false"):
        parent[last_key] = new_value.lower() == "true"
    elif new_value.isdigit():
        parent[last_key] = int(new_value)
    else:
        parent[last_key] = new_value


def test_grc_connection(url: str, email: str, password: str) -> tuple[bool, str]:
    """Test connection to CISO Assistant and get auth token.

    Args:
        url: CISO Assistant base URL (HTTPS).
        email: Admin email for authentication.
        password: User-provided password via getpass (NEVER hardcoded).

    Returns:
        (success, token_or_error) tuple.
    """
    try:
        import urllib.request
        import urllib.error
        import ssl

        # Create SSL context that allows self-signed certs
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        data = json.dumps({"email": email, "password": password}).encode()
        req = urllib.request.Request(
            f"{url}/api/iam/login/",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(req, context=ctx, timeout=10) as response:
            result = json.loads(response.read().decode())
            token = result.get("token", "")
            if token:
                return True, token
            return False, "No token in response"
    except Exception as e:
        return False, str(e)


def main() -> int:
    """Run the policy configuration wizard."""
    script_dir = Path(__file__).parent
    skills_root = script_dir.parent.parent
    policies_file = skills_root / "blueteam-autopilot-knowledge" / "policies.json"

    print()
    print(f"{BOLD}=== BlueTeam: Policy Configuration Wizard ==={NC}")
    print()

    if not policies_file.exists():
        print(f"{RED}Error: policies.json not found at {policies_file}{NC}")
        print("Run this script from the skills root or ensure the knowledge skill is installed.")
        return 1

    # Load current policies
    with open(policies_file) as f:
        data = json.load(f)

    # Step 1: Show current configuration
    print(f"{BLUE}[Step 1/5] Current Policy Configuration{NC}")
    print("----------------------------------------")
    print()

    print(f'  {"POLICY":<24} {"TYPE":<14} {"SOURCE":<16} {"SYNC MODE":<12}')
    print(f'  {"-"*24} {"-"*14} {"-"*16} {"-"*12}')
    for p in data.get("policies", []):
        pid = p.get("id", "")
        ptype = p.get("type", "")
        source = p.get("source", "")
        sync_mode = p.get("sync", {}).get("mode", "") if source == "grc" else "N/A"
        last = p.get("sync", {}).get("last_sync", "") if source == "grc" else ""
        status = "synced" if last else "not synced"
        print(f"  {pid:<24} {ptype:<14} {source:<16} {status:<12}")
    print()

    # Show GRC provider status
    print(f"{BLUE}GRC Provider Status:{NC}")
    grc_enabled = read_json_field(data, "grc_providers.ciso-assistant.enabled")
    grc_url = read_json_field(data, "grc_providers.ciso-assistant.base_url")
    grc_email = read_json_field(data, "grc_providers.ciso-assistant.auth.email")

    print("  Provider:  ciso-assistant (CISO Assistant Community)")
    print(f"  Status:    {grc_enabled or 'disabled'}")
    print(f"  URL:       {grc_url or 'not configured'}")
    print(f"  Email:     {grc_email or 'not configured'}")
    print()

    # Step 2: Configure GRC provider connection
    print(f"{BLUE}[Step 2/5] GRC Provider Connection{NC}")
    print("----------------------------------------")
    print()
    print("Configure your CISO Assistant Community instance.")
    print("This is the GRC platform that will provide compliance framework data.")
    print()

    input_url = input(f"  CISO Assistant URL [{grc_url or 'https://localhost:8443'}]: ").strip()
    grc_url = input_url or grc_url or "https://localhost:8443"

    input_email = input("  Admin email (for API auth): ").strip()
    grc_email = input_email or grc_email

    import getpass
    input_password = getpass.getpass("  Password (input hidden): ")
    grc_password = input_password

    # Test connection
    print()
    print(f"  Testing connection to {grc_url}... ", end="", flush=True)

    connected, token_or_error = test_grc_connection(grc_url, grc_email, grc_password)

    if connected:
        print(f"{GREEN}Connected successfully!{NC}")
        grc_enabled = "true"
        grc_token = token_or_error
    else:
        print(f"{YELLOW}Connection failed. Response:{NC}")
        print(f"  {token_or_error}")
        print()
        print("  You can still save the configuration and fix the connection later.")
        print("  Set GRC_ENABLED=false until the connection is verified.")

        save_anyway = input("  Save connection config anyway? [Y/n]: ").strip()
        if save_anyway.lower() == "n":
            print("  Skipping GRC configuration. Policies will remain in manual mode.")
            grc_enabled = "false"
            grc_token = ""
        else:
            grc_enabled = "false"
            grc_token = ""

    # Write provider config
    write_json_field(data, "grc_providers.ciso-assistant.enabled", grc_enabled)
    write_json_field(data, "grc_providers.ciso-assistant.base_url", grc_url)
    write_json_field(data, "grc_providers.ciso-assistant.auth.email", grc_email)
    write_json_field(data, "grc_providers.ciso-assistant.auth.api_token", grc_token if connected else "")

    with open(policies_file, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")

    print()

    # Step 3: Framework Discovery (if connected)
    if grc_enabled == "true" and grc_token:
        print(f"{BLUE}[Step 3/5] Framework Discovery{NC}")
        print("----------------------------------------")
        print()
        print("  Fetching available frameworks from CISO Assistant...")
        print()

        # Fetch stored libraries
        try:
            import urllib.request
            import ssl

            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            req = urllib.request.Request(
                f"{grc_url}/api/stored-libraries/",
                headers={
                    "Authorization": f"Token {grc_token}",
                    "Content-Type": "application/json",
                },
            )

            with urllib.request.urlopen(req, context=ctx, timeout=10) as response:
                libs_json = json.loads(response.read().decode())
                results = libs_json.get("results", libs_JSON) if isinstance(libs_JSON, dict) else libs_JSON
                if isinstance(results, list):
                    frameworks = [l for l in results if l.get("is_published", False)]
                    if frameworks:
                        print("  Available compliance frameworks:")
                        for fw in frameworks:
                            name = fw.get("name", "Unknown")
                            desc = fw.get("description", "")[:60]
                            print(f"    - {name}")
                            if desc:
                                print(f"      {desc}")
                    else:
                        print("  No published libraries found.")
                else:
                    print("  Unexpected response format.")
        except Exception as e:
            print(f"  Could not parse response: {e}")

        print()
    else:
        print(f"{YELLOW}[Step 3/5] Framework Discovery — SKIPPED (GRC not connected){NC}")
        print()

    # Step 4: Policy sync configuration
    print(f"{BLUE}[Step 4/5] Policy Sync Configuration{NC}")
    print("----------------------------------------")
    print()
    print("For each GRC-sourced policy, specify whether to enable syncing.")
    print()

    for p in data.get("policies", []):
        if p.get("source") == "grc":
            print(f'  Policy: {p["id"]} ({p.get("title", "")})')
            print(f'    Framework: {p.get("grc", {}).get("library_name", "")}')
            print(f'    Controls:  {", ".join(p.get("controls", []))}')
            print()

    enable_sync = input("  Enable GRC sync for compliance policies? [Y/n]: ").strip()
    if enable_sync.lower() == "n":
        print()
        print("  GRC sync disabled. Policies will use bundled documents.")
        print("  Run this wizard again to enable syncing later.")
    else:
        print()
        print("  GRC sync enabled for compliance policies.")
        print("  Run 'grc_sync.py' to perform the initial sync.")

    print()

    # Step 5: Review and save
    print(f"{BLUE}[Step 5/5] Review Configuration{NC}")
    print("----------------------------------------")
    print()

    print("  Configuration summary:")
    print(f"    GRC Provider:  {grc_url}")
    print(f"    GRC Enabled:   {grc_enabled}")
    print(f"    Auth Email:    {grc_email or 'not set'}")
    print(f"    Config saved:  {policies_file}")
    print()

    # Next steps
    print(f"{GREEN}=== Configuration Complete ==={NC}")
    print()
    print("Next steps:")
    print()

    if grc_enabled == "true":
        print("  1. Test the connection:")
        print("     cd skills/blueteam-autopilot-knowledge")
        print("     python scripts/grc_sync.py --list")
        print()
        print("  2. Perform initial sync:")
        print("     cd skills/blueteam-autopilot-knowledge")
        print("     python scripts/grc_sync.py")
        print()
    else:
        print("  1. Verify your CISO Assistant instance is running:")
        print("     docker compose up -d")
        print("     (in the ciso-assistant-community directory)")
        print()
        print("  2. Re-run this wizard to configure the connection:")
        print("     python scripts/configure_policies.py")
        print()

    print("  3. Validate the full configuration:")
    print("     python scripts/validate_configuration.py")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
