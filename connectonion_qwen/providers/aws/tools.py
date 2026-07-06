"""AWS cloud provider tools — 13 SecOps tools for AWS services.

Each tool dispatches to a bash script via subprocess, following
the same pattern as the Aliyun provider.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
from pathlib import Path

from connectonion_qwen.providers.aws.config import (
    AWS_SCRIPTS_DIR,
    AWS_FIXTURES_DIR,
    SECURITY_CENTER_MODE,
)

logger = logging.getLogger(__name__)

# AWS state-changing tools (require HITL approval)
AWS_STATE_CHANGING_TOOLS: set[str] = {
    "aws_block_waf_ips",
    "aws_update_finding",
}


def _run_aws_script(script_name: str, args: list[str] | None = None) -> str:
    """Execute an AWS bash script and return its stdout."""
    script_path: Path = AWS_SCRIPTS_DIR / script_name
    if not script_path.exists():
        return json.dumps({"error": f"Script not found: {script_path}"})

    cmd: list[str] = ["bash", str(script_path)]
    if args:
        cmd.extend(args)

    env = os.environ.copy()
    env["SECURITY_CENTER_MODE"] = SECURITY_CENTER_MODE
    env["AGENT_MODE"] = "1"

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=60, env=env,
            cwd=str(AWS_SCRIPTS_DIR.parent.parent.parent),
        )
        output = result.stdout.strip()
        if result.returncode != 0:
            stderr = result.stderr.strip()
            return json.dumps({
                "error": stderr or output or f"Script exited with code {result.returncode}",
                "exit_code": result.returncode,
            })
        return output or json.dumps({"status": "ok", "message": "No output from script."})
    except subprocess.TimeoutExpired:
        return json.dumps({"error": f"Script timeout: {script_name}"})
    except FileNotFoundError:
        return json.dumps({"error": "bash not found."})
    except Exception as exc:
        logger.error(f"AWS script execution failed ({script_name}): {exc}", exc_info=True)
        return json.dumps({"error": "Tool execution failed. Please retry."})


# ---------------------------------------------------------------------------
# Diagnostic Tools
# ---------------------------------------------------------------------------

def aws_ping() -> str:
    """Verify AWS CLI connectivity and credentials.
    Returns account ID, region, and caller identity."""
    return _run_aws_script("aws-ping.sh")


# ---------------------------------------------------------------------------
# Security Hub / GuardDuty Events
# ---------------------------------------------------------------------------

def aws_list_findings(time_range: str = "lastHour") -> str:
    """List security findings from AWS Security Hub.
    Findings sorted by severity (CRITICAL > HIGH > MEDIUM > LOW).
    Cross-reference with aws_list_cloudtrail_events for timeline."""
    return _run_aws_script("aws-list-findings.sh", [time_range])


def aws_get_finding_detail(finding_id: str) -> str:
    """Get detailed information about a specific Security Hub finding.
    Includes full resource context, remediation guidance, and compliance
    mapping. Call during incident deep-dive."""
    return _run_aws_script("aws-get-finding-detail.sh", [finding_id])


# ---------------------------------------------------------------------------
# AWS WAF
# ---------------------------------------------------------------------------

def aws_list_waf_events(time_range: str = "lastHour") -> str:
    """List recent AWS WAF blocked/allowed requests.
    Use same time_range as aws_list_findings for coherent investigation."""
    return _run_aws_script("aws-list-waf-events.sh", [time_range])


def aws_list_guardduty_findings(time_range: str = "lastHour") -> str:
    """List GuardDuty threat detection findings.
    GuardDuty detects unauthorized access, crypto mining, recon activity."""
    return _run_aws_script("aws-list-guardduty-findings.sh", [time_range])


def aws_get_guardduty_finding(finding_id: str) -> str:
    """Get detailed information about a specific GuardDuty finding.
    Includes threat intelligence, attack chain, and affected resources."""
    return _run_aws_script("aws-get-guardduty-finding.sh", [finding_id])


# ---------------------------------------------------------------------------
# CloudTrail Audit
# ---------------------------------------------------------------------------

def aws_list_cloudtrail_events(time_range: str = "lastHour") -> str:
    """List recent CloudTrail API audit events.
    Shows who called what API, from where, and when.
    Critical for forensic timeline reconstruction."""
    return _run_aws_script("aws-list-cloudtrail-events.sh", [time_range])


# ---------------------------------------------------------------------------
# Assets (EC2)
# ---------------------------------------------------------------------------

def aws_list_assets() -> str:
    """List AWS EC2 instances and resources.
    Call at start of investigation to build asset context.
    Includes instance ID, type, state, tags, and security groups."""
    return _run_aws_script("aws-list-assets.sh")


# ---------------------------------------------------------------------------
# IAM Tools
# ---------------------------------------------------------------------------

def aws_list_iam_users() -> str:
    """List all IAM users in the AWS account.
    Returns user details including UserName, CreateDate, PasswordLastUsed.
    Use this to begin IAM inventory discovery."""
    return _run_aws_script("aws-list-iam-users.sh")


def aws_get_iam_mfa(user_name: str) -> str:
    """Get MFA device status for an IAM user.
    Check if MFA is enabled — users without MFA are a security risk.
    Returns MFA device serial number and type."""
    return _run_aws_script("aws-get-iam-mfa.sh", [user_name])


def aws_list_iam_access_keys(user_name: str) -> str:
    """List access keys for an IAM user.
    Returns key IDs, creation dates, last used dates, and status.
    Look for stale keys (unused >90 days) or active keys for inactive users."""
    return _run_aws_script("aws-list-iam-access-keys.sh", [user_name])


# ---------------------------------------------------------------------------
# Response Tools (state-changing — require HITL approval)
# ---------------------------------------------------------------------------

def aws_update_finding(finding_id: str, status: str = "NOTIFIED") -> str:
    """Update a Security Hub finding status (STATE-CHANGING — requires HITL approval).

    Valid statuses: NEW, NOTIFIED, SUPPRESSED, RESOLVED.
    Use to mark findings as acknowledged or resolved after investigation.

    Args:
        finding_id: The Security Hub finding ID to update.
        status: New workflow status (default: NOTIFIED).
    """
    return _run_aws_script("aws-update-finding.sh", [finding_id, status])


def aws_block_waf_ips(ips: str, dry_run: bool = True) -> str:
    """Block attacker IPs in AWS WAF via IP set update (STATE-CHANGING — requires HITL approval).

    ALWAYS set dry_run=true first to preview what would be blocked.
    NEVER call with dry_run=false without explicit human approval
    (SOC 2 CC6.8.3 mandate).

    Args:
        ips: Comma-separated list of IPs or CIDRs to block.
        dry_run: If true, show what would be blocked without making API calls.
    """
    args: list[str] = [ips]
    if not dry_run:
        args.append("--real")
    return _run_aws_script("aws-block-waf-ips.sh", args)


# ---------------------------------------------------------------------------
# Tool Registry
# ---------------------------------------------------------------------------

ALL_TOOLS: list = [
    # Diagnostics
    aws_ping,
    # Security Hub / GuardDuty
    aws_list_findings,
    aws_get_finding_detail,
    # WAF
    aws_list_waf_events,
    aws_list_guardduty_findings,
    aws_get_guardduty_finding,
    # CloudTrail
    aws_list_cloudtrail_events,
    # Assets
    aws_list_assets,
    # IAM
    aws_list_iam_users,
    aws_get_iam_mfa,
    aws_list_iam_access_keys,
    # Response
    aws_update_finding,
    aws_block_waf_ips,
]
