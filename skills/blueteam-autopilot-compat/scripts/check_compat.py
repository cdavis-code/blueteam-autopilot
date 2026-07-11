#!/usr/bin/env python3
"""CLI Compatibility Checker for BlueTeam.

Validates that the installed aliyun CLI is compatible with project scripts.

Usage: python check_compat.py [--real]
  --real  Run live API tests (requires credentials and SECURITY_CENTER_MODE=real)
  Default: Demo mode — command existence checks only, no API calls

Exit codes:
  0 = All checks passed
  1 = One or more checks failed
  2 = CLI not installed or baseline not found
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).parent
BASELINE_FILE = SCRIPT_DIR.parent / "references" / "cli-baseline.json"
MODE = __import__("os").environ.get("SECURITY_CENTER_MODE", "demo")
LIVE_TEST = "--real" in sys.argv
if LIVE_TEST:
    MODE = "real"

pass_count = 0
fail_count = 0
warn_count = 0
skip_count = 0


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


def run_aliyun(*args: str) -> tuple[int, str]:
    """Run an aliyun CLI command and return (exit_code, combined_output)."""
    try:
        result = subprocess.run(
            ["aliyun", *args],
            capture_output=True, text=True, timeout=30,
        )
        return result.returncode, result.stdout + result.stderr
    except FileNotFoundError:
        return -1, ""
    except subprocess.TimeoutExpired:
        return -2, "timeout"


print("╔══════════════════════════════════════════════════════════╗")
print("║   BlueTeam — CLI Compatibility Checker                  ║")
print("╚══════════════════════════════════════════════════════════╝")
print()

# ── Check 1: aliyun CLI installed ──
print("Stage 1: CLI Installation")
exit_code, output = run_aliyun("version")
if exit_code == -1:
    print("  ✗ aliyun CLI not found")
    print("  Install: brew install aliyun-cli (macOS)")
    sys.exit(2)

cli_version = output.strip() or "unknown"
passed(f"aliyun CLI installed (version: {cli_version})")
print()

# ── Check 2: Baseline file ──
print("Stage 2: Baseline File")
if not BASELINE_FILE.exists():
    print(f"  ✗ Baseline not found: {BASELINE_FILE}")
    sys.exit(2)

try:
    with open(BASELINE_FILE) as f:
        baseline = json.load(f)
except (json.JSONDecodeError, IOError):
    print(f"  ✗ Baseline is not valid JSON: {BASELINE_FILE}")
    sys.exit(2)

baseline_version = baseline.get("meta", {}).get("cli_version_tested", "unknown")
baseline_date = baseline.get("meta", {}).get("last_validated", "unknown")
baseline_count = len(baseline.get("commands", []))
passed(f"Baseline loaded ({baseline_count} commands)")
print(f"    Tested with CLI version: {baseline_version}")
print(f"    Last validated: {baseline_date}")

if cli_version != baseline_version:
    warned(f"Version mismatch: installed={cli_version}, baseline={baseline_version}")
print()

# ── Check 3: Command existence ──
print("Stage 3: Command Existence Checks")
print("  Verifying each CLI command is recognized by the installed version...")
print()

# Extract unique product+command pairs
seen = set()
commands = []
for cmd in baseline.get("commands", []):
    key = f"{cmd['product']} {cmd['command']}"
    if key not in seen:
        seen.add(key)
        scripts = [c["script"] for c in baseline["commands"]
                   if c["product"] == cmd["product"] and c["command"] == cmd["command"]]
        commands.append({
            "product": cmd["product"],
            "command": cmd["command"],
            "scripts": scripts,
        })

current_product = ""
for cmd_entry in commands:
    product = cmd_entry["product"]
    command = cmd_entry["command"]
    scripts = cmd_entry["scripts"]

    if product != current_product:
        print(f"  ── {product} ──")
        current_product = product

    exit_code, output = run_aliyun(product, command, "--help")
    if exit_code != 0:
        print(f"  ✗ {command} — command not recognized")
        print(f"    Affected: {', '.join(scripts)}")
        fail_count += 1
    else:
        print(f"  ✓ {command} — recognized")
        pass_count += 1

print()

# ── Check 4: Parameter validation ──
print("Stage 4: Parameter Checks")
print("  Verifying required parameters are accepted by each command...")
print()

seen = set()
param_commands = []
for cmd in baseline.get("commands", []):
    key = f"{cmd['product']} {cmd['command']}"
    if key not in seen:
        seen.add(key)
        params = cmd.get("params", [])
        scripts = [c["script"] for c in baseline["commands"]
                   if c["product"] == cmd["product"] and c["command"] == cmd["command"]]
        param_commands.append({
            "product": cmd["product"],
            "command": cmd["command"],
            "params": params,
            "scripts": scripts,
        })

current_product = ""
for cmd_entry in param_commands:
    product = cmd_entry["product"]
    command = cmd_entry["command"]
    params = cmd_entry["params"]
    scripts = cmd_entry["scripts"]

    if product != current_product:
        print(f"  ── {product} ──")
        current_product = product

    if not params:
        print(f"  ✓ {command} — no required params")
        pass_count += 1
        continue

    # Get help output
    exit_code, help_output = run_aliyun(product, command, "--help")
    missing_params = []

    for param in params:
        if param == "--region":
            continue
        clean_param = param.lstrip("-")
        if clean_param.lower() not in help_output.lower():
            missing_params.append(param)

    if missing_params:
        print(f"  ⚠ {command} — params not found in help: {' '.join(missing_params)}")
        print(f"    Affected: {', '.join(scripts)}")
        warn_count += 1
    else:
        print(f"  ✓ {command} — all params accepted")
        pass_count += 1

print()

# ── Stage 5: Live API tests ──
if LIVE_TEST and MODE == "real":
    print("Stage 5: Live API Response Structure Tests")
    print("  Running smoke tests against live Alibaba Cloud APIs...")
    print()

    # Discover region
    region = __import__("os").environ.get("ALIBABA_REGION", "")
    if not region:
        try:
            result = subprocess.run(
                ["aliyun", "configure", "get", "region"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0:
                region = result.stdout.strip()
        except Exception:
            pass

    live_tests = [
        ("sas", "describe-version-config", f"--region {region}", "Version"),
        ("sts", "get-caller-identity", "", "AccountId"),
        ("cloud-siem", "list-automate-response-configs", f"--Version 2022-06-16 --region {region} --PageSize 10 --CurrentPage 1", "TotalCount"),
    ]

    for product, command, params, expected_field in live_tests:
        print(f"  Testing: {product} {command}")
        args = [product, command] + params.split() if params else [product, command]
        exit_code, output = run_aliyun(*args)

        if exit_code != 0 or "error" in output.lower() or "not found" in output.lower():
            print(f"  ✗ {product} {command} — API call failed")
            for line in output.splitlines()[:3]:
                print(f"    {line}")
            fail_count += 1
        elif expected_field and expected_field not in output:
            print(f"  ✗ {product} {command} — missing expected field: {expected_field}")
            fail_count += 1
        else:
            print(f"  ✓ {product} {command} — response structure OK")
            pass_count += 1

    print()
else:
    print("Stage 5: Live API Tests")
    print("  Skipped (demo mode). Run with --real or SECURITY_CENTER_MODE=real for live API tests.")
    skip_count += 1
    print()

# ── Summary ──
print("═══════════════════════════════════════════════════════════")
print("  Compatibility Report")
print("═══════════════════════════════════════════════════════════")
print()
print(f"  CLI Version:    {cli_version}")
print(f"  Baseline:       {baseline_version} (validated {baseline_date})")
print(f"  Mode:           {MODE}")
print()
print(f"  Passed:   {pass_count}")
print(f"  Failed:   {fail_count}")
print(f"  Warnings: {warn_count}")
print(f"  Skipped:  {skip_count}")
print()

if fail_count > 0:
    print("  ╔═══════════════════════════════════════════════════════╗")
    print("  ║  COMPATIBILITY ISSUES DETECTED                       ║")
    print("  ║  Some CLI commands may need updating.                ║")
    print("  ║  See blueteam-autopilot-compat SKILL.md for          ║")
    print("  ║  remediation guidance.                               ║")
    print("  ╚═══════════════════════════════════════════════════════╝")
    sys.exit(1)
else:
    print("  ╔═══════════════════════════════════════════════════════╗")
    print("  ║  ALL CHECKS PASSED                                   ║")
    print("  ║  CLI is compatible with BlueTeam scripts.            ║")
    print("  ╚═══════════════════════════════════════════════════════╝")
    sys.exit(0)
