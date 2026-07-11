#!/usr/bin/env python3
"""Auto-generate trusted-networks.md from Alibaba Cloud VPC/VPN configuration.

Replaces generate-trusted-networks.sh with Python equivalent.
Usage: python generate_trusted_networks.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


# ANSI color codes
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"


def run_aliyun(args: list[str]) -> dict | str:
    """Run aliyun CLI and return parsed JSON or error string."""
    try:
        result = subprocess.run(
            ["aliyun"] + args,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            return result.stderr.strip() or result.stdout.strip()
        return json.loads(result.stdout)
    except subprocess.TimeoutExpired:
        return "Timeout"
    except FileNotFoundError:
        return "aliyun CLI not found"
    except json.JSONDecodeError:
        return result.stdout.strip()


def discover_vpcs(region: str, output_file: Path) -> int:
    """Discover VPCs and write to output file."""
    print(f"Discovering VPCs in {region}...")

    vpcs_data = run_aliyun(["vpc", "DescribeVpcs", "--region", region])
    if isinstance(vpcs_data, str):
        print(f"{RED}Failed to query VPCs{NC}")
        print(f"Error: {vpcs_data}")
        return 0

    vpcs = vpcs_data.get("Vpcs", {}).get("Vpc", [])
    vpc_count = len(vpcs)

    if vpc_count > 0:
        print(f"{GREEN}Found {vpc_count} VPC(s){NC}")

        for vpc in vpcs:
            vpc_id = vpc.get("VpcId", "")
            if vpc_id:
                # Get VPC attributes
                attr_data = run_aliyun(["vpc", "DescribeVpcAttribute", "--region", region, "--VpcId", vpc_id])
                if isinstance(attr_data, dict):
                    cidr = attr_data.get("CidrBlock", "")
                    vpc_name = attr_data.get("VpcName", "") or vpc_id
                    if cidr:
                        with open(output_file, "a") as f:
                            f.write(f"| {vpc_name} | {cidr} | VPC |\n")
                else:
                    print(f"{YELLOW}  Warning: Failed to get attributes for {vpc_id}{NC}")
    else:
        print(f"{YELLOW}No VPCs found in region {region}{NC}")
        with open(output_file, "a") as f:
            f.write("| No VPCs found | - | - |\n")

    return vpc_count


def discover_vpns(region: str, output_file: Path) -> int:
    """Discover VPN gateways and write to output file."""
    print("Discovering VPN Gateways...")

    vpns_data = run_aliyun(["vpc", "DescribeVpnGateways", "--region", region])
    if isinstance(vpns_data, str):
        print(f"{YELLOW}Warning: VPN Gateway query failed{NC}")
        print("Skipping VPN discovery.")
        with open(output_file, "a") as f:
            f.write("| No VPN gateways found | - | - |\n")
        return 0

    vpns = vpns_data.get("VpnGateways", {}).get("VpnGateway", [])
    vpn_count = len(vpns)

    if vpn_count > 0:
        print(f"{GREEN}Found {vpn_count} VPN Gateway(s){NC}")
        for vpn in vpns:
            vpn_id = vpn.get("VpnGatewayId", "")
            if vpn_id:
                with open(output_file, "a") as f:
                    f.write(f"| {vpn_id} | See VPN customer gateway | VPN Gateway |\n")
    else:
        print(f"{YELLOW}No VPN Gateways found{NC}")
        with open(output_file, "a") as f:
            f.write("| No VPN gateways found | - | - |\n")

    return vpn_count


def discover_waf_domains(region: str, output_file: Path) -> tuple[int, str]:
    """Discover WAF-protected domains and write to output file."""
    print("Discovering WAF-protected domains...")

    # Get WAF instance
    waf_data = run_aliyun(["waf-openapi", "DescribeInstance", "--region", region])
    if isinstance(waf_data, str):
        with open(output_file, "a") as f:
            f.write("### WAF-Protected Domains\n\n")
            f.write("| Domain | Access Mode | Purpose |\n")
            f.write("|--------|-------------|---------|\n")
            f.write("| No WAF instance found | - | Activate WAF 3.0 first |\n\n")
        return 0, ""

    instance_id = waf_data.get("InstanceId", "")
    if not instance_id:
        with open(output_file, "a") as f:
            f.write("### WAF-Protected Domains\n\n")
            f.write("| Domain | Access Mode | Purpose |\n")
            f.write("|--------|-------------|---------|\n")
            f.write("| No WAF instance found | - | Activate WAF 3.0 first |\n\n")
        return 0, ""

    # Get domains
    domains_data = run_aliyun(["waf-openapi", "DescribeDomains", "--region", region, "--InstanceId", instance_id])
    if isinstance(domains_data, str):
        with open(output_file, "a") as f:
            f.write("### WAF-Protected Domains\n\n")
            f.write("| Domain | Access Mode | Purpose |\n")
            f.write("|--------|-------------|---------|\n")
            f.write("| No WAF domains found | - | Add domain in WAF Console |\n\n")
        return 0, ""

    domains = domains_data.get("Domains", domains_data.get("DomainList", []))
    domain_count = len(domains)
    primary_domain = ""

    with open(output_file, "a") as f:
        f.write("### WAF-Protected Domains\n\n")
        f.write("| Domain | Access Mode | Purpose |\n")
        f.write("|--------|-------------|---------|\n")

        if domain_count > 0:
            for domain in domains:
                name = domain.get("Domain", domain.get("DomainName", ""))
                mode = domain.get("AccessMode", domain.get("AccessType", "CNAME"))
                if name:
                    f.write(f"| {name} | {mode} | WAF-protected test domain |\n")
                    if not primary_domain:
                        primary_domain = name

        if domain_count == 0 or not primary_domain:
            f.write("| No WAF domains found | - | Add domain in WAF Console |\n")

        f.write("\n")
        if primary_domain:
            f.write(f"**Primary Test Domain:** {primary_domain}\n\n")

    print(f"{GREEN}Found {domain_count} WAF-protected domain(s){NC}")
    if primary_domain:
        print(f"  Primary test domain: {GREEN}{primary_domain}{NC}")

    return domain_count, primary_domain


def main() -> int:
    """Generate trusted-networks.md from Alibaba Cloud configuration."""
    script_dir = Path(__file__).parent
    skills_root = script_dir.parent.parent
    output_file = skills_root / "blueteam-autopilot-knowledge" / "documents" / "trusted-networks.md"

    print("=== BlueTeam: Trusted Networks Generator ===")
    print()

    # Check aliyun CLI
    try:
        subprocess.run(["aliyun", "version"], capture_output=True, timeout=10)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print(f"{RED}Error: aliyun CLI not found{NC}")
        print("Install: https://www.alibabacloud.com/help/doc-detail/139506.htm")
        return 1

    # Region discovery
    from _helpers import discover_region
    try:
        region = discover_region()
    except RuntimeError:
        region = "ap-southeast-1"

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    print(f"Region: {region}")
    print(f"Output: {output_file}")
    print()

    # Ensure output directory exists
    output_file.parent.mkdir(parents=True, exist_ok=True)

    # Write header
    with open(output_file, "w") as f:
        f.write("""# Trusted Networks

> **CRITICAL:** This file is auto-generated. Do NOT edit manually.
> Run `skills/blueteam-autopilot-prep/scripts/generate_trusted_networks.py` to regenerate.

## Purpose

This file contains the authoritative list of trusted internal networks for
BlueTeam incident correlation and response.

## Auto-Discovered Networks

The following networks were discovered from the Alibaba Cloud environment
at generation time.

### VPCs

| Network | CIDR | Purpose |
|---------|------|---------|
""")

    # Discover VPCs
    vpc_count = discover_vpcs(region, output_file)

    with open(output_file, "a") as f:
        f.write("\n### VPN Gateways\n\n")
        f.write("| Network | CIDR | Purpose |\n")
        f.write("|---------|------|---------|\n")

    # Discover VPNs
    vpn_count = discover_vpns(region, output_file)

    with open(output_file, "a") as f:
        f.write("\n")

    # Discover WAF domains
    domain_count, primary_domain = discover_waf_domains(region, output_file)

    # Add static sections
    with open(output_file, "a") as f:
        f.write("""## Manual Additions

Add any monitoring service IPs, on-premise networks, or partner networks here:

| Network | CIDR | Purpose |
|---------|------|---------|
| CloudMonitor | 100.100.0.0/16 | Alibaba Cloud monitoring |
| Internal DNS | 100.64.0.0/16 | Alibaba Cloud internal DNS |

## Security Policy

All networks listed in this file are considered **trusted internal networks**
for the purposes of BlueTeam incident correlation.

### Incident Correlation Rules

When an attack is detected, BlueTeam MUST check the source IP
against this trusted network list:

1. **External Source (not in this file):**
   - Proceed with normal incident response
   - Propose perimeter blocking if warranted

2. **Internal Source (matches this file):**
   - **STOP** — do NOT propose immediate blocking
   - Flag as "Potentially Compromised Internal Asset"
   - Escalate to security team for investigation
   - Correlate with other internal security signals

## Rule

**CRITICAL:** Any attack originating from these IPs must be flagged as
**"Potentially Compromised Internal Asset"** — never blindly blocked.

### Escalation Procedure

1. **Do NOT** propose perimeter block (IP ACL)
2. **DO** escalate to security team for investigation
3. **Document** as potential insider threat or compromised asset
4. **Correlate** with other internal security signals
""")

    # Add generation metadata
    with open(output_file, "a") as f:
        f.write(f"\n**Last Generated:** {timestamp}\n")
        f.write(f"**Region:** {region}\n")
        f.write(f"**VPCs Discovered:** {vpc_count}\n")
        f.write(f"**VPN Gateways:** {vpn_count}\n")
        f.write(f"**WAF Domains:** {domain_count}\n")

    # Generate sample-attack-traffic.sh if we have a primary domain
    if primary_domain:
        project_root = script_dir.parent.parent.parent
        attack_script = project_root / "sample-attack-traffic.sh"
        generate_attack_script(attack_script, primary_domain, region, timestamp)
        print()
        print(f"{GREEN}✓ Generated {attack_script}{NC}")
        print("  Run: ./sample-attack-traffic.sh")

    print()
    print(f"{GREEN}✓ Generated {output_file}{NC}")
    print(f"  - VPCs discovered: {vpc_count}")
    print(f"  - VPN gateways: {vpn_count}")
    print(f"  - WAF domains: {domain_count}")
    print()
    print("Review the generated file and add any monitoring service IPs manually.")

    return 0


def generate_attack_script(path: Path, domain: str, region: str, timestamp: str) -> None:
    """Generate sample-attack-traffic.sh script."""
    content = f'''#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# sample-attack-traffic.sh
#
# Auto-generated by generate_trusted_networks.py — do not edit manually.
# Regenerate: skills/blueteam-autopilot-prep/scripts/generate_trusted_networks.py
#
# Sends sample WAF attack traffic to: {domain}
# Region: {region}
# Generated: {timestamp}
#
# Prerequisites:
#   - aliyun CLI installed and configured (credentials in .env or shell)
#   - WAF protection mode set to Block (not Observe)
# =============================================================================

TEST_DOMAIN="{domain}"
ALIBABA_REGION="{region}"
# Auto-discover account ID via STS if not already set
if [ -z "${{ACCOUNT_ID:-}}" ] || [ "${{ACCOUNT_ID}}" = "YOUR_ACCOUNT_ID" ]; then
  ACCOUNT_ID=$(aliyun sts GetCallerIdentity 2>/dev/null \\
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('AccountId',''))" 2>/dev/null || echo "")
  if [ -z "$ACCOUNT_ID" ]; then
    echo "Error: Could not discover ACCOUNT_ID via 'aliyun sts GetCallerIdentity'."
    echo "       Export it manually: export ACCOUNT_ID=<your-account-id>"
    exit 1
  fi
fi

echo "=== BlueTeam: Sample Attack Traffic ==="
echo ""
echo "Target domain: ${{TEST_DOMAIN}}"
echo "Region: ${{ALIBABA_REGION}}"
echo ""

echo "--- SQL Injection Probe ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{{http_code}}" -g \\
  "http://${{TEST_DOMAIN}}/?id=1%27%20OR%20%271%27%3D%271")
echo "HTTP ${{HTTP_CODE}} (expected: 405 — blocked by WAF)"
echo ""

echo "--- XSS Probe ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{{http_code}}" -g \\
  "http://${{TEST_DOMAIN}}/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E")
echo "HTTP ${{HTTP_CODE}} (expected: 405 — blocked by WAF)"
echo ""

echo "--- Path Traversal Probe ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{{http_code}}" -g \\
  "http://${{TEST_DOMAIN}}/download?file=..%2F..%2Fetc%2Fpasswd")
echo "HTTP ${{HTTP_CODE}} (expected: 405 — blocked by WAF)"
echo ""

echo "--- Normal Traffic (should pass) ---"
HTTP_CODE=$(curl -s -o /dev/null -w "%{{http_code}}" -g \\
  "http://${{TEST_DOMAIN}}/")
echo "HTTP ${{HTTP_CODE}} (expected: 200 — normal page served)"
echo ""

echo "=== Traffic sent. Waiting 30s for log propagation... ==="
sleep 30

echo ""
echo "=== Verify logs in SLS ==="
FROM_TS=$(date -u -v-10M +%s 2>/dev/null || date -u -d '10 minutes ago' +%s)
TO_TS=$(date -u +%s)
aliyun sls GetLogs \\
  --project "wafnew-project-${{ACCOUNT_ID}}-${{ALIBABA_REGION}}" \\
  --logstore "wafnew-logstore" \\
  --from "${{FROM_TS}}" \\
  --to "${{TO_TS}}" \\
  --query "matched_host: ${{TEST_DOMAIN}}-waf | SELECT final_action, final_plugin, final_rule_type LIMIT 5" \\
  --region "${{ALIBABA_REGION}}" 2>&1 | head -40
echo ""
echo "Expected: Log entries with final_action: block"
'''
    with open(path, "w") as f:
        f.write(content)
    path.chmod(0o755)


if __name__ == "__main__":
    sys.exit(main())
