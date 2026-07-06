"""BlueTeam Autopilot tools — 19 SecOps tools as plain Python functions.

Each function is auto-converted to an OpenAI-compatible tool schema by
ConnectOnion's tool_factory using type hints and docstrings.

Under the hood, each tool dispatches to a bash script in
skills/blueteam-autopilot-ops/scripts/ via subprocess.
"""

from __future__ import annotations

import ipaddress
import json
import logging
import os
import subprocess
from pathlib import Path

from connectonion_qwen.config import SCRIPTS_DIR, SECURITY_CENTER_MODE

logger = logging.getLogger(__name__)

# Tools that require HITL approval before real execution (state-changing)
STATE_CHANGING_TOOLS: set[str] = {
    "execute_response_policy",
    "block_waf_ips",
    "detach_policy",
    "rotate_access_key",
    "delete_stale_user",
}


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
        return json.dumps({"error": "Tool timed out after 30s."})
    except FileNotFoundError:
        return json.dumps({"error": "bash not found. Ensure bash is installed and in PATH."})
    except Exception as exc:
        logger.error(f"Script execution failed ({script_name}): {exc}", exc_info=True)
        return json.dumps({"error": "Tool execution failed. Please retry."})


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


def _validate_ip_or_cidr(value: str) -> bool:
    """Check if a string is a valid IP address or CIDR range."""
    try:
        ipaddress.ip_address(value)
        return True
    except ValueError:
        try:
            ipaddress.ip_network(value, strict=False)
            return True
        except ValueError:
            return False


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
    invalid = [ip for ip in ip_list if not _validate_ip_or_cidr(ip)]
    if invalid:
        return json.dumps({"error": f"Invalid IP/CIDR: {', '.join(invalid)}"})
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
# Report Generation
# ===========================================================================

def generate_incident_report(event_id: str, additional_context: str = "") -> str:
    """Generate a comprehensive incident response report for a security event.

    Aggregates investigation data from multiple sources (event detail, alerts,
    assets, vulnerabilities, WAF, compliance controls) into a structured
    context package. Use this AFTER completing investigation (behaviors 1-4).

    Returns structured JSON with all data needed to produce a full IR report
    including attack chain, blast radius, compliance mapping (NIST CSF + SOC 2),
    recommended actions, and audit trail.

    Args:
        event_id: The security event ID to generate the report for.
        additional_context: Optional extra context from the current investigation
            (e.g., findings from prior tool calls, user observations).
    """
    from datetime import datetime, timezone

    report_timestamp = datetime.now(timezone.utc).isoformat()
    context: dict = {
        "reportType": "incident-response",
        "generatedAt": report_timestamp,
        "eventId": event_id,
        "additionalContext": additional_context,
        "sections": {},
    }

    # 1. Event detail — attack chain, CVEs, attacker IPs, geo-location
    event_detail = _run_script("get-event-detail.sh", [event_id])
    context["sections"]["eventDetail"] = _safe_parse(event_detail)

    # 2. Correlated alerts grouped by data source
    alerts = _run_script("list-alerts.sh", [event_id])
    context["sections"]["alerts"] = _safe_parse(alerts)

    # 3. Current asset inventory with SOC 2 scope tags
    assets = _run_script("list-assets.sh")
    context["sections"]["assets"] = _safe_parse(assets)

    # 4. Active vulnerabilities (filtered by severity if possible)
    vulnerabilities = _run_script("list-vulnerabilities.sh")
    context["sections"]["vulnerabilities"] = _safe_parse(vulnerabilities)

    # 5. Available response policies for remediation recommendations
    policies = _run_script("list-response-policies.sh")
    context["sections"]["responsePolicies"] = _safe_parse(policies)

    # 6. WAF context — instance info and recent attack logs
    waf_instance = _run_script("get-waf-instance.sh")
    context["sections"]["wafInstance"] = _safe_parse(waf_instance)

    waf_events = _run_script("list-waf-events.sh")
    context["sections"]["wafEvents"] = _safe_parse(waf_events)

    # 7. Compliance controls — NIST CSF and SOC 2
    nist_controls = _run_script("get-knowledge.sh", ["compliance_nist"])
    context["sections"]["nistControls"] = nist_controls

    soc2_controls = _run_script("get-knowledge.sh", ["compliance_soc2"])
    context["sections"]["soc2Controls"] = soc2_controls

    # 8. Account context for edition and region info
    account_ctx = _run_script("get-account-context.sh")
    context["sections"]["accountContext"] = _safe_parse(account_ctx)

    # Compliance mapping reference (embedded for LLM convenience)
    context["complianceMapping"] = {
        "WAF perimeter blocking": ["NIST CSF PR.PT-4", "SOC 2 CC6.1"],
        "Multi-signal correlation": ["NIST CSF DE.AE-2", "SOC 2 CC6.8"],
        "Response policy selection": ["NIST CSF RS.RP-1", "SOC 2 CC6.8"],
        "Human approval requirement": ["SOC 2 CC6.8.3"],
        "Audit trail documentation": ["NIST CSF DE.AE-2", "SOC 2 CC6.8"],
    }

    return json.dumps(context, indent=2)


def _safe_parse(raw: str) -> dict | list | str:
    """Try to parse JSON; return raw string on failure."""
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, TypeError):
        return raw


# ===========================================================================
# IAM Forensic Tools
# ===========================================================================


def list_ram_users() -> str:
    """List all RAM (Resource Access Management) users in the Alibaba Cloud account.

    Returns user details including UserName, DisplayName, CreateDate,
    and LastLoginDate. Use this to begin IAM inventory discovery.

    Returns:
        JSON object with Users array containing user details.
    """
    return _run_script("list-ram-users.sh")


def list_ram_roles() -> str:
    """List all RAM roles in the Alibaba Cloud account.

    Returns role details including RoleName, Arn, trust policy, and
    MaxSessionDuration. Roles represent trust relationships — entities
    that can be assumed by services or cross-account principals.

    Returns:
        JSON object with Roles array containing role details.
    """
    return _run_script("list-ram-roles.sh")


def list_ram_policies() -> str:
    """List all RAM policies in the Alibaba Cloud account.

    Returns policy details including PolicyName, PolicyType (System/Custom),
    and policy document. Look for overly permissive policies (wildcard actions,
    ram:PassRole, AdministratorAccess on non-admin entities).

    Returns:
        JSON object with Policies array containing policy details.
    """
    return _run_script("list-ram-policies.sh")


def get_ram_credential_report() -> str:
    """Get RAM credential report with access key ages and staleness analysis.

    Returns account-wide credential summary: total users, access key count,
    key ages, and a list of stale keys (unused for >90 days). Use this to
    identify credential rotation issues and abandoned service accounts.

    Returns:
        JSON object with Summary, AccessKeyAges, and StaleKeys arrays.
    """
    return _run_script("get-ram-credential-report.sh")


def get_role_trust_policy(role_name: str) -> str:
    """Get the trust policy and attached policies for a specific RAM role.

    The trust policy defines which principals can assume this role.
    Look for: cross-account root trust without ExternalId, overly
    permissive attached policies, excessive session durations.

    Args:
        role_name: The RAM role name to inspect.

    Returns:
        JSON object with TrustPolicy, AttachedPolicies, and RiskNotes.
    """
    return _run_script("get-role-trust-policy.sh", [role_name])


def list_attached_policies_for(entity_type: str, entity_name: str) -> str:
    """List policies attached to a specific RAM user or role.

    Args:
        entity_type: Either "user" or "role".
        entity_name: The name of the RAM user or role.

    Returns:
        JSON object with AttachedPolicies array.
    """
    return _run_script("list-attached-policies.sh", [entity_type, entity_name])


def analyze_trust_relationships() -> str:
    """Analyze trust relationships across all RAM roles.

    Evaluates each role's trust policy for risk indicators:
    cross-account root trust, missing ExternalId conditions,
    overly permissive attached policies. Returns a risk-scored
    inventory of all trust relationships.

    Returns:
        JSON object with TrustRelationships array (each scored by risk)
        and Summary with risk counts.
    """
    return _run_script("analyze-trust-relationships.sh")


def score_risk_matrix() -> str:
    """Generate a risk matrix scoring all IAM entities.

    Aggregates trust analysis, credential report, and policy analysis
    into a unified risk matrix. Each entity gets a risk score (0.0-1.0),
    severity (CRITICAL/HIGH/MEDIUM/LOW), and specific recommendations.

    Returns:
        JSON object with RiskMatrix array and Summary with overall scores.
    """
    return _run_script("score-risk-matrix.sh")


def detach_policy(entity_type: str, entity_name: str, policy_name: str) -> str:
    """Detach a policy from a RAM user or role (STATE-CHANGING — requires HITL approval).

    Removes the specified policy attachment. Use this to reduce
    over-privileged access (e.g., detach AdministratorAccess from
    a cross-account role).

    Args:
        entity_type: Either "user" or "role".
        entity_name: The name of the RAM user or role.
        policy_name: The policy name to detach.

    Returns:
        JSON confirmation of the detach action.
    """
    return _run_script("detach-policy.sh", [entity_type, entity_name, policy_name])


def rotate_access_key(user_name: str, access_key_id: str) -> str:
    """Rotate a RAM user's access key (STATE-CHANGING — requires HITL approval).

    Disables the specified access key and creates a new one. Use this
    to remediate stale or potentially compromised credentials.

    Args:
        user_name: The RAM user whose key should be rotated.
        access_key_id: The access key ID to disable and replace.

    Returns:
        JSON confirmation with old key disabled and new key details.
    """
    return _run_script("rotate-access-key.sh", [user_name, access_key_id])


def delete_stale_user(user_name: str) -> str:
    """Delete a stale RAM user after disabling their access keys (STATE-CHANGING — requires HITL approval).

    Disables all active access keys for the user, then deletes the user.
    Use this to clean up abandoned service accounts and expired temp accounts.

    Args:
        user_name: The RAM user to delete.

    Returns:
        JSON confirmation with count of disabled keys.
    """
    return _run_script("delete-stale-user.sh", [user_name])


def store_scan_snapshot(snapshot_data: str) -> str:
    """Store an IAM scan snapshot to the persistent memory database.

    Saves the current scan inventory and findings for future comparison.
    Called by the workflow engine's persist phase.

    Args:
        snapshot_data: JSON string containing inventory and findings.

    Returns:
        JSON with snapshot_id and confirmation.
    """
    from connectonion_qwen.memory import store_snapshot

    try:
        data = json.loads(snapshot_data) if isinstance(snapshot_data, str) else snapshot_data
    except (json.JSONDecodeError, TypeError):
        return json.dumps({"error": "Invalid JSON snapshot_data"})

    inventory = data.get("inventory", {})
    findings = data.get("findings", [])
    workflow_run_id = data.get("workflow_run_id", "manual")

    snapshot_id = store_snapshot(workflow_run_id, inventory, findings)
    return json.dumps({
        "status": "stored",
        "snapshot_id": snapshot_id,
        "findings_count": len(findings),
    })


def diff_previous_scan() -> str:
    """Compare current scan against the previous scan to detect IAM drift.

    Retrieves the two most recent snapshots and computes the diff:
    entities added, removed, or modified (risk score/status changes).

    Returns:
        JSON with added, removed, and modified entity lists.
        Returns "no previous scan" if fewer than 2 snapshots exist.
    """
    from connectonion_qwen.memory import get_latest_snapshot, diff_snapshots

    latest = get_latest_snapshot()
    if not latest:
        return json.dumps({"status": "no_previous_scan", "drift": None})

    # Get the second-to-latest snapshot for comparison
    from connectonion_qwen.memory import _connect
    conn = _connect()
    try:
        rows = conn.execute(
            "SELECT id FROM iam_scan_snapshots ORDER BY scan_timestamp DESC LIMIT 2"
        ).fetchall()
        if len(rows) < 2:
            return json.dumps({
                "status": "first_scan",
                "latest_snapshot_id": latest["id"],
                "drift": None,
                "message": "This is the first scan. Run again to detect drift.",
            })
        previous_id = rows[1]["id"]
    finally:
        conn.close()

    drift = diff_snapshots(previous_id, latest["id"])
    return json.dumps({
        "status": "drift_detected",
        "current_snapshot_id": latest["id"],
        "previous_snapshot_id": previous_id,
        "drift": drift,
    })


def run_workflow(workflow_name: str) -> str:
    """Execute a specialized security workflow by name.

    Available workflows:
    - iam-forensic: Full RAM/IAM security audit — enumerates users/roles/
      policies, analyzes trust relationships, scores risk matrix,
      proposes remediation (with HITL approval), and persists results
      for cross-incident drift detection.
    - incident-response: Full incident lifecycle — discovery, deep-dive,
      recommendation, action, and reporting.
    - threat-hunt: Proactive threat hunting — collect, analyze, correlate,
      and report on security patterns.
    - compliance-audit: Compliance gap analysis — inventory, map controls,
      collect evidence, produce audit report.

    The workflow engine handles multi-phase orchestration internally.
    Each phase uses a specialist persona with scoped tools.

    Args:
        workflow_name: Name of the workflow to execute (e.g., "iam-forensic").

    Returns:
        JSON with workflow execution results including phase outputs.
    """
    from workflows._engine import run_workflow as _exec_workflow
    result = _exec_workflow(workflow_name)
    return json.dumps(result, indent=2)


# ===========================================================================
# Vector Memory Tools
# ===========================================================================


def search_similar_incidents(description: str, top_k: int = 5) -> str:
    """Search for previously seen incidents similar to this description.

    Uses vector embeddings to find matching patterns across all workflow
    runs. Returns the top-k most similar incidents with similarity scores.
    Use this to answer "Have we seen this before?" during investigations.

    Args:
        description: Text description of the incident or pattern to search for.
        top_k: Number of similar incidents to return (default: 5).

    Returns:
        JSON array of similar incidents with similarity scores (0.0-1.0),
        source workflow, type, and description. Empty array if no matches.
    """
    from connectonion_qwen.embeddings import find_similar

    results = find_similar(description, top_k)
    if not results:
        return json.dumps({
            "status": "no_matches",
            "message": "No similar incidents found in memory. This appears to be a new pattern.",
            "results": [],
        })

    return json.dumps({
        "status": "found",
        "query": description[:100],
        "count": len(results),
        "results": results,
    }, indent=2)


def store_incident_memory(description: str, source_type: str = "incident", metadata_json: str = "{}") -> str:
    """Store an incident description in persistent memory for future similarity search.

    Called during investigations to build institutional memory of seen patterns.
    The description is embedded into a vector and stored for cross-incident
    correlation. Future investigations can query "Have we seen this before?"
    using search_similar_incidents.

    Args:
        description: Detailed description of the incident, finding, or pattern.
        source_type: Type of source — "incident", "alert", "finding", "vulnerability", "threat".
        metadata_json: Optional JSON string with extra context (severity, assets, attack type).

    Returns:
        JSON confirmation with the stored memory ID.
    """
    from connectonion_qwen.embeddings import store_incident_embedding

    try:
        metadata = json.loads(metadata_json) if metadata_json and metadata_json != "{}" else None
    except (json.JSONDecodeError, TypeError):
        metadata = None

    memory_id = store_incident_embedding(
        description=description,
        source_type=source_type,
        metadata=metadata,
    )
    return json.dumps({
        "status": "stored",
        "memory_id": memory_id,
        "source_type": source_type,
        "description_length": len(description),
    })


# ===========================================================================
# Autonomous Monitoring Tools
# ===========================================================================


def get_monitor_state() -> str:
    """Get the current continuous monitoring state.

    Returns the last check timestamp, total ticks, and total escalations.
    Used by the monitoring workflow to know when to scan from.
    On first run, last_check_timestamp is null (scan last hour by default).

    Returns:
        JSON with last_check_timestamp, total_ticks, total_escalations,
        and last_tick_timestamp.
    """
    from connectonion_qwen.memory import _connect, init_db

    init_db()
    conn = _connect()
    try:
        row = conn.execute("SELECT * FROM monitor_state WHERE id = 1").fetchone()
        if not row:
            return json.dumps({
                "last_check_timestamp": None,
                "total_ticks": 0,
                "total_escalations": 0,
                "last_tick_timestamp": None,
                "message": "First run — will scan last hour of events.",
            })
        return json.dumps({
            "last_check_timestamp": row["last_check_timestamp"],
            "total_ticks": row["total_ticks"],
            "total_escalations": row["total_escalations"],
            "last_tick_timestamp": row["last_tick_timestamp"],
        })
    finally:
        conn.close()


def update_monitor_state(escalations: int = 0) -> str:
    """Update the monitoring state after a scan tick.

    Advances the last_check_timestamp to now, increments tick count
    and escalation counter. Called at the end of each monitoring cycle.

    Args:
        escalations: Number of high-severity escalations this tick (default: 0).

    Returns:
        JSON confirmation with updated state.
    """
    from connectonion_qwen.memory import _connect, init_db
    from datetime import datetime, timezone

    init_db()
    now = datetime.now(timezone.utc).isoformat()
    conn = _connect()
    try:
        conn.execute(
            """UPDATE monitor_state
               SET last_check_timestamp = ?,
                   last_tick_timestamp = ?,
                   total_ticks = total_ticks + 1,
                   total_escalations = total_escalations + ?
               WHERE id = 1""",
            (now, now, escalations),
        )
        conn.commit()

        row = conn.execute("SELECT * FROM monitor_state WHERE id = 1").fetchone()
        return json.dumps({
            "status": "updated",
            "last_check_timestamp": row["last_check_timestamp"],
            "total_ticks": row["total_ticks"],
            "total_escalations": row["total_escalations"],
            "escalations_this_tick": escalations,
        })
    finally:
        conn.close()


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
    generate_incident_report,
    # IAM Forensic Tools
    list_ram_users,
    list_ram_roles,
    list_ram_policies,
    get_ram_credential_report,
    get_role_trust_policy,
    list_attached_policies_for,
    analyze_trust_relationships,
    score_risk_matrix,
    detach_policy,
    rotate_access_key,
    delete_stale_user,
    store_scan_snapshot,
    diff_previous_scan,
    # Workflow Engine
    run_workflow,
    # Vector Memory
    search_similar_incidents,
    store_incident_memory,
    # Autonomous Monitoring
    get_monitor_state,
    update_monitor_state,
]
