"""BlueTeam Autopilot tools — 17 SecOps tools as plain Python functions.

Each function is auto-converted to an OpenAI-compatible tool schema by
ConnectOnion's tool_factory using type hints and docstrings.

Under the hood, each tool dispatches to a bash script in
skills/blueteam-autopilot-ops/scripts/ via subprocess.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from connectonion_qwen.config import SCRIPTS_DIR, SECURITY_CENTER_MODE

# Tools that require HITL approval before real execution (state-changing)
STATE_CHANGING_TOOLS: set[str] = {"execute_response_policy", "block_waf_ips"}


# ---------------------------------------------------------------------------
# Shared script executor
# ---------------------------------------------------------------------------

def _run_script(script_name: str, args: list[str] | None = None) -> str:
    """Execute a bash script and return its stdout.

    Returns the script's stdout as a string (JSON or plain text).
    On error, returns a JSON error object.
    """
    script_path: Path = SCRIPTS_DIR / script_name
    if not script_path.exists():
        return json.dumps({"error": f"Script not found: {script_path}"})

    cmd: list[str] = ["bash", str(script_path)]
    if args:
        cmd.extend(args)

    env = os.environ.copy()
    env["SECURITY_CENTER_MODE"] = SECURITY_CENTER_MODE
    env["AGENT_MODE"] = "1"  # Suppress human-readable headers

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            env=env,
            cwd=str(SCRIPTS_DIR.parent.parent.parent),  # project root
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
        return json.dumps({"error": f"Tool timed out after 30s."})
    except FileNotFoundError:
        return json.dumps({"error": "bash not found. Ensure bash is installed and in PATH."})
    except Exception as exc:
        return json.dumps({"error": str(exc)})


# ===========================================================================
# Core Tools
# ===========================================================================

def ping() -> str:
    """Health check. Returns server status, region, and execution mode.
    Call at session start to verify connectivity."""
    return _run_script("ping.sh")


def get_account_context() -> str:
    """Returns region, Security Center edition, and Agentic SOC status.
    Call first to establish execution context."""
    return _run_script("get-account-context.sh")


# ===========================================================================
# Security Events
# ===========================================================================

def list_security_events(
    time_range: str = "",
    severity: str = "",
    status: str = "",
) -> str:
    """List Agentic SOC security events. Results sorted by severity
    (CRITICAL > HIGH > MEDIUM > LOW). Cross-reference affected assets
    against list_assets output."""
    args: list[str] = []
    if time_range:
        args.append(time_range)
    elif severity:
        args.append("")  # placeholder for time_range
    if severity:
        args.append(severity)
    return _run_script("list-events.sh", args)


def get_security_event_detail(event_id: str) -> str:
    """Full event detail: attack chain stages, attacker IPs, CVEs,
    raw data, and related alerts. Call during incident deep-dive."""
    return _run_script("get-event-detail.sh", [event_id])


def list_alerts_for_event(event_id: str) -> str:
    """Underlying alerts grouped by data source (WAF, CWPP, Cloud Firewall).
    Use to correlate multiple signals per NIST CSF DE.AE-2."""
    return _run_script("list-alerts.sh", [event_id])


# ===========================================================================
# Vulnerabilities
# ===========================================================================

def list_vulnerabilities(
    severity: str = "",
    asset_id: str = "",
    vul_type: str = "",
) -> str:
    """List vulnerabilities detected by Security Center.
    Prioritize by severity and asset criticality."""
    args: list[str] = []
    if severity:
        args.append(severity)
    elif asset_id or vul_type:
        args.append("")
    if asset_id:
        args.append(asset_id)
    elif vul_type:
        args.append("")
    if vul_type:
        args.append(vul_type)
    return _run_script("list-vulnerabilities.sh", args)


def get_vulnerability_detail(vuln_id: str) -> str:
    """Deep vulnerability info: CVE ID, description, fix suggestion,
    affected asset. Call after list_vulnerabilities."""
    return _run_script("get-vulnerability-detail.sh", [vuln_id])


# ===========================================================================
# Response Policies
# ===========================================================================

def list_response_policies(scope: str = "") -> str:
    """List Agentic SOC response/automation policies.
    Match incident profile to policy: WAF attacks map to IP blocking,
    host threats map to isolation policies."""
    args: list[str] = []
    if scope:
        args.append(scope)
    return _run_script("list-response-policies.sh", args)


def execute_response_policy(
    policy_id: str,
    dry_run: bool = True,
    event_id: str = "",
) -> str:
    """Execute or simulate a response policy.
    ALWAYS set dry_run=true first. NEVER call without human approval
    (SOC 2 CC6.8.3 mandate). Returns effects and simulation results."""
    args: list[str] = [policy_id]
    if event_id:
        args.append(event_id)
    if not dry_run:
        args.append("--real")
    return _run_script("execute-response-policy.sh", args)


# ===========================================================================
# WAF Tools
# ===========================================================================

def get_waf_instance_info() -> str:
    """Discover WAF instance in the configured region.
    Call before WAF-specific operations."""
    return _run_script("get-waf-instance.sh")


def list_waf_security_events(
    time_range: str = "",
    attack_type: str = "",
) -> str:
    """WAF attack logs from SLS. Use same time_range as list_security_events
    for a coherent investigation window."""
    args: list[str] = []
    if time_range:
        args.append(time_range)
    elif attack_type:
        args.append("")
    if attack_type:
        args.append(attack_type)
    return _run_script("list-waf-events.sh", args)


def list_waf_top_rules(time_range: str = "") -> str:
    """Top 10 most triggered WAF rules. Useful for identifying
    the most common attack patterns in the time window."""
    args: list[str] = []
    if time_range:
        args.append(time_range)
    return _run_script("list-waf-top-rules.sh", args)


def list_waf_top_ips(time_range: str = "") -> str:
    """Top 10 attacker IPs by WAF hit count.
    Cross-reference against trusted networks before proposing blocks."""
    args: list[str] = []
    if time_range:
        args.append(time_range)
    return _run_script("list-waf-top-ips.sh", args)


def block_waf_ips(ips: str, dry_run: bool = True) -> str:
    """Block attacker IPs in WAF via IP blacklist defense rule.
    Uses WAF 3.0 create-defense-rule API with ip_blacklist scene.

    ALWAYS set dry_run=true first to show what would be blocked.
    NEVER call with dry_run=false without explicit human approval
    (SOC 2 CC6.8.3 mandate).

    Args:
        ips: Comma-separated list of IPs or CIDRs to block (e.g. "1.2.3.4,5.6.7.8/24")
        dry_run: If true, show what would be blocked without making API calls.
    """
    ip_list = [ip.strip() for ip in ips.split(",") if ip.strip()]
    args: list[str] = ip_list
    if dry_run:
        args.append("--dry-run")
    return _run_script("block-waf-ips.sh", args)


# ===========================================================================
# Assets
# ===========================================================================

def list_assets(criteria: str = "") -> str:
    """List cloud assets (ECS instances) in Security Center.
    Call at start of investigation to build live asset context.
    Assets tagged SOC 2 scope or sensitive elevate events to HIGH+."""
    args: list[str] = []
    if criteria:
        args.append(criteria)
    return _run_script("list-assets.sh", args)


# ===========================================================================
# Knowledge
# ===========================================================================

def list_knowledge_documents() -> str:
    """List all available knowledge documents (compliance controls,
    runbooks, policies, infrastructure references)."""
    return _run_script("list-knowledge.sh")


def get_knowledge_document(type: str) -> str:
    """Fetch a specific knowledge document by type.
    Types: compliance_nist, compliance_soc2, runbook_waf_triage,
    policy_change_mgmt, trusted_networks, asset_inventory.
    Call ONLY for formal reports, compliance citations, or when
    the user explicitly asks for policy text."""
    return _run_script("get-knowledge.sh", [type])


# ===========================================================================
# Diagnostics
# ===========================================================================

def verify_log_delivery() -> str:
    """Verify WAF log delivery to SLS is working. Checks SLS project,
    logstore, and recent log presence. Call when WAF events appear
    empty or to confirm logging pipeline health."""
    return _run_script("verify-log-delivery.sh")


# ===========================================================================
# Tool list for convenient import
# ===========================================================================

ALL_TOOLS: list = [
    ping,
    get_account_context,
    list_security_events,
    get_security_event_detail,
    list_alerts_for_event,
    list_vulnerabilities,
    get_vulnerability_detail,
    list_response_policies,
    execute_response_policy,
    get_waf_instance_info,
    list_waf_security_events,
    list_waf_top_rules,
    list_waf_top_ips,
    block_waf_ips,
    list_assets,
    list_knowledge_documents,
    get_knowledge_document,
    verify_log_delivery,
]
