#!/usr/bin/env python3
"""Validate BlueTeam skills for hardcoded environment-specific values.

Replaces validate-configuration.sh with Python equivalent.
Usage: python validate_configuration.py

Exit codes:
  0 = No hardcoded values found (or only in example/template sections)
  1 = Hardcoded values found that need remediation
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


# ANSI color codes
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
NC = "\033[0m"


def print_ok(msg: str) -> None:
    print(f"  {GREEN}✓{NC} {msg}")


def print_warn(msg: str) -> None:
    print(f"  {YELLOW}⚠{NC} {msg}")


def print_fail(msg: str) -> None:
    print(f"  {RED}✗{NC} {msg}")


def check_regions(skills_root: Path) -> int:
    """Check for hardcoded regions."""
    print("Checking for hardcoded regions...")
    found = 0

    region_pattern = re.compile(r'(ap-southeast-[0-9]+|cn-[a-z]+-[0-9]+|us-[a-z]+-[0-9]+|eu-[a-z]+-[0-9]+)')
    acceptable_patterns = re.compile(r'(example|template|\{\{ALIBABA_REGION\}\}|ALIBABA_REGION.*environment|get_account_context)')

    for md_file in skills_root.rglob("*.md"):
        try:
            with open(md_file) as f:
                for line_num, line in enumerate(f, 1):
                    if region_pattern.search(line):
                        if acceptable_patterns.search(line):
                            print_ok(f"{md_file}:{line_num} (acceptable - example/template context)")
                        elif "trusted-networks.md" in str(md_file):
                            print_ok(f"{md_file}:{line_num} (acceptable - auto-generated metadata)")
                        else:
                            print_fail(f"{md_file}:{line_num} (needs remediation)")
                            print(f"    {line.strip()}")
                            found = 1
        except OSError:
            pass

    if not found:
        print(f"{GREEN}✓ No hardcoded regions found{NC}")
    print()
    return found


def check_ips(skills_root: Path) -> int:
    """Check for hardcoded IP addresses."""
    print("Checking for hardcoded IP addresses...")
    found = 0

    ip_pattern = re.compile(r'\b([0-9]{1,3}\.){3}[0-9]{1,3}(/\d+)?\b')
    acceptable_patterns = re.compile(r'(example|EXAMPLE|RFC [0-9]+|\{\{|EXAMPLE VALUES|Corporate LAN|Corporate WLAN|Remote office|External health|APM and log)')
    acceptable_files = re.compile(r'(trusted-networks\.md|asset-inventory\.md)')

    for md_file in skills_root.rglob("*.md"):
        try:
            with open(md_file) as f:
                for line_num, line in enumerate(f, 1):
                    if ip_pattern.search(line) and "127.0.0.1" not in line:
                        if acceptable_patterns.search(line):
                            print_ok(f"{md_file}:{line_num} (acceptable - example/documentation)")
                        elif acceptable_files.search(str(md_file)):
                            print_ok(f"{md_file}:{line_num} (acceptable - auto-generated or example file)")
                        else:
                            print_fail(f"{md_file}:{line_num} (needs review)")
                            print(f"    {line.strip()}")
                            found = 1
        except OSError:
            pass

    if not found:
        print(f"{GREEN}✓ No hardcoded IP addresses found{NC}")
    print()
    return found


def check_instance_ids(skills_root: Path) -> int:
    """Check for hardcoded instance/resource IDs."""
    print("Checking for hardcoded instance/resource IDs...")
    found = 0

    # Alibaba Cloud resource ID patterns
    id_pattern = re.compile(r'(?<![a-z0-9])(i-[a-z0-9]{6,}|sg-[a-z0-9]{6,}|vpc-[a-z0-9]{6,}|waf-[a-z0-9]+-[a-z0-9]{6,}|rds-[a-z0-9]{6,})')
    acceptable_patterns = re.compile(r'(example|Example|EXAMPLE|template|i-prod-|i-demo-)')

    for md_file in skills_root.rglob("*.md"):
        try:
            with open(md_file) as f:
                for line_num, line in enumerate(f, 1):
                    if id_pattern.search(line):
                        if acceptable_patterns.search(line):
                            print_ok(f"{md_file}:{line_num} (acceptable - example)")
                        elif "trusted-networks.md" in str(md_file):
                            print_ok(f"{md_file}:{line_num} (acceptable - auto-generated VPC ID)")
                        else:
                            print_fail(f"{md_file}:{line_num} (needs review)")
                            print(f"    {line.strip()}")
                            found = 1
        except OSError:
            pass

    if not found:
        print(f"{GREEN}✓ No hardcoded instance IDs found{NC}")
    print()
    return found


def check_example_markers(skills_root: Path) -> int:
    """Check for missing example markers."""
    print("Checking for missing example markers...")
    found = 0

    # Check trusted-networks.md
    trusted_path = skills_root / "documents" / "trusted-networks.md"
    if trusted_path.exists():
        print_ok("trusted-networks.md present (auto-generated — no EXAMPLE markers required)")

    # Check asset-inventory.md
    asset_path = skills_root / "documents" / "asset-inventory.md"
    if asset_path.exists():
        try:
            with open(asset_path) as f:
                content = f.read()
            if "EXAMPLE" not in content:
                print_fail("asset-inventory.md missing EXAMPLE markers")
                found = 1
            else:
                print_ok("asset-inventory.md has example markers")
        except OSError:
            pass

    print()
    return found


def check_dynamic_instructions(skills_root: Path) -> int:
    """Check for dynamic data instructions."""
    print("Checking for dynamic data instructions...")
    found = 0

    core_skill = skills_root.parent / "blueteam-autopilot-core" / "SKILL.md"
    if core_skill.exists():
        try:
            with open(core_skill) as f:
                content = f.read()
            if "get_account_context" in content:
                print_ok("Core SKILL.md references get_account_context")
            else:
                print_warn("Core SKILL.md should reference get_account_context for dynamic data")
        except OSError:
            pass

    print()
    return found


def main() -> int:
    """Run all validation checks."""
    script_dir = Path(__file__).parent
    skills_root = script_dir.parent.parent / "blueteam-autopilot-knowledge"

    print("==========================================")
    print("BlueTeam Configuration Validator")
    print("==========================================")
    print()

    if not skills_root.exists():
        print(f"{RED}Error: Knowledge directory not found at {skills_root}{NC}")
        print("Ensure blueteam-autopilot-knowledge skill is installed")
        return 1

    found_issues = 0
    found_issues |= check_regions(skills_root)
    found_issues |= check_ips(skills_root)
    found_issues |= check_instance_ids(skills_root)
    found_issues |= check_example_markers(skills_root)
    found_issues |= check_dynamic_instructions(skills_root)

    # Summary
    print("==========================================")
    if found_issues == 0:
        print(f"{GREEN}✓ All checks passed!{NC}")
        print("No hardcoded environment-specific values found.")
    else:
        print(f"{RED}✗ Validation failed{NC}")
        print("Please remediate the issues listed above.")
        print()
        print("Run './scripts/generate_trusted_networks.py' to auto-generate trusted networks")
        print("from your Alibaba Cloud configuration.")
    print("==========================================")

    return found_issues


if __name__ == "__main__":
    sys.exit(main())
