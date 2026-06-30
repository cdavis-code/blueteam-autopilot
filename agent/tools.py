"""Tool schemas and executor for BlueTeam Autopilot.

Converts the 17 MCP tools from mcp-tools.md into OpenAI function calling
JSON schemas (per Qwen Cloud docs). Each tool maps to a bash script in
skills/blueteam-autopilot-ops/scripts/.
"""

import json
import os
import subprocess
from pathlib import Path

from agent.config import SCRIPTS_DIR, SECURITY_CENTER_MODE

# ---------------------------------------------------------------------------
# Tool definitions -- OpenAI function calling schema
# Reference: https://docs.qwencloud.com/developer-guides/text-generation/function-calling
# ---------------------------------------------------------------------------

TOOL_DEFINITIONS: list[dict] = [
    # ── Core Tools ──────────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "ping",
            "description": (
                "Health check. Returns server status, region, and execution mode. "
                "Call at session start to verify connectivity."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_account_context",
            "description": (
                "Returns region, Security Center edition, and Agentic SOC status. "
                "Call first to establish execution context."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
    # ── Security Events ────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "list_security_events",
            "description": (
                "List Agentic SOC security events. Results sorted by severity "
                "(CRITICAL > HIGH > MEDIUM > LOW). Cross-reference affected "
                "assets against list_assets output."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "timeRange": {
                        "type": "string",
                        "description": (
                            "Time range shortcut: last15Min, lastHour, last4Hours, "
                            "last24Hours, last7Days, last30Days. Default: lastHour."
                        ),
                    },
                    "severity": {
                        "type": "string",
                        "description": "Filter by severity: CRITICAL, HIGH, MEDIUM, LOW.",
                    },
                    "status": {
                        "type": "string",
                        "description": "Filter by status: open, closed, ignored.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_security_event_detail",
            "description": (
                "Full event detail: attack chain stages, attacker IPs, CVEs, "
                "raw data, and related alerts. Call during incident deep-dive."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "eventId": {
                        "type": "string",
                        "description": "Security Center event ID (e.g. evt-demo-20260614-001).",
                    },
                },
                "required": ["eventId"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_alerts_for_event",
            "description": (
                "Underlying alerts grouped by data source (WAF, CWPP, Cloud Firewall). "
                "Use to correlate multiple signals per NIST CSF DE.AE-2."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "eventId": {
                        "type": "string",
                        "description": "Security Center event ID.",
                    },
                },
                "required": ["eventId"],
            },
        },
    },
    # ── Vulnerabilities ────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "list_vulnerabilities",
            "description": (
                "List vulnerabilities detected by Security Center. "
                "Prioritize by severity and asset criticality."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "severity": {
                        "type": "string",
                        "description": "Filter: CRITICAL, HIGH, MEDIUM, LOW.",
                    },
                    "assetId": {
                        "type": "string",
                        "description": "Filter by specific asset ID.",
                    },
                    "vulType": {
                        "type": "string",
                        "description": "Filter by type: CVE, WEB_CMS, APP, SYSTEM. Default: CVE.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_vulnerability_detail",
            "description": (
                "Deep vulnerability info: CVE ID, description, fix suggestion, "
                "affected asset. Call after list_vulnerabilities."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "vulnId": {
                        "type": "string",
                        "description": "Vulnerability ID.",
                    },
                },
                "required": ["vulnId"],
            },
        },
    },
    # ── Response Policies ──────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "list_response_policies",
            "description": (
                "List Agentic SOC response/automation policies. "
                "Match incident profile to policy: WAF attacks map to IP blocking, "
                "host threats map to isolation policies."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "scope": {
                        "type": "string",
                        "description": "Optional scope filter.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "execute_response_policy",
            "description": (
                "Execute or simulate a response policy. "
                "ALWAYS set dryRun=true first. NEVER call without human approval "
                "(SOC 2 CC6.8.3 mandate). Returns effects and simulation results."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "policyId": {
                        "type": "string",
                        "description": "Response policy ID (e.g. pol-waf-block-001).",
                    },
                    "dryRun": {
                        "type": "boolean",
                        "description": "Simulate execution without changes. Default: true.",
                    },
                    "eventId": {
                        "type": "string",
                        "description": "Associated event ID for audit trail.",
                    },
                },
                "required": ["policyId"],
            },
        },
    },
    # ── WAF Tools ──────────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "get_waf_instance_info",
            "description": (
                "Discover WAF instance in the configured region. "
                "Call before WAF-specific operations."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_waf_security_events",
            "description": (
                "WAF attack logs from SLS. Use same timeRange as list_security_events "
                "for a coherent investigation window."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "timeRange": {
                        "type": "string",
                        "description": "Time range shortcut. Default: lastHour.",
                    },
                    "attackType": {
                        "type": "string",
                        "description": "Filter: sqli, xss, lfi, scanner_behavior.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_waf_top_rules",
            "description": (
                "Top 10 most triggered WAF rules. Useful for identifying "
                "the most common attack patterns in the time window."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "timeRange": {
                        "type": "string",
                        "description": "Time range shortcut. Default: lastHour.",
                    },
                },
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_waf_top_ips",
            "description": (
                "Top 10 attacker IPs by WAF hit count. "
                "Cross-reference against trusted networks before proposing blocks."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "timeRange": {
                        "type": "string",
                        "description": "Time range shortcut. Default: lastHour.",
                    },
                },
                "required": [],
            },
        },
    },
    # ── Assets ─────────────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "list_assets",
            "description": (
                "List cloud assets (ECS instances) in Security Center. "
                "Call at start of investigation to build live asset context. "
                "Assets tagged SOC 2 scope or sensitive elevate events to HIGH+."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "criteria": {
                        "type": "string",
                        "description": "Optional filter criteria.",
                    },
                },
                "required": [],
            },
        },
    },
    # ── Knowledge ──────────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "list_knowledge_documents",
            "description": (
                "List all available knowledge documents (compliance controls, "
                "runbooks, policies, infrastructure references)."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_knowledge_document",
            "description": (
                "Fetch a specific knowledge document by type. "
                "Types: compliance_nist, compliance_soc2, runbook_waf_triage, "
                "policy_change_mgmt, trusted_networks, asset_inventory. "
                "Call ONLY for formal reports, compliance citations, or when "
                "the user explicitly asks for policy text."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "description": (
                            "Document type: compliance_nist, compliance_soc2, "
                            "runbook_waf_triage, policy_change_mgmt, "
                            "trusted_networks, asset_inventory."
                        ),
                    },
                },
                "required": ["type"],
            },
        },
    },
    # ── Diagnostics ────────────────────────────────────────────────────────
    {
        "type": "function",
        "function": {
            "name": "verify_log_delivery",
            "description": (
                "Verify WAF log delivery to SLS is working. Checks SLS project, "
                "logstore, and recent log presence. Call when WAF events appear "
                "empty or to confirm logging pipeline health."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
]

# ---------------------------------------------------------------------------
# Tool → script mapping
# ---------------------------------------------------------------------------

TOOL_SCRIPT_MAP: dict[str, str] = {
    "ping": "ping.sh",
    "get_account_context": "get-account-context.sh",
    "list_security_events": "list-events.sh",
    "get_security_event_detail": "get-event-detail.sh",
    "list_alerts_for_event": "list-alerts.sh",
    "list_vulnerabilities": "list-vulnerabilities.sh",
    "get_vulnerability_detail": "get-vulnerability-detail.sh",
    "list_response_policies": "list-response-policies.sh",
    "execute_response_policy": "execute-response-policy.sh",
    "get_waf_instance_info": "get-waf-instance.sh",
    "list_waf_security_events": "list-waf-events.sh",
    "list_waf_top_rules": "list-waf-top-rules.sh",
    "list_waf_top_ips": "list-waf-top-ips.sh",
    "list_assets": "list-assets.sh",
    "list_knowledge_documents": "list-knowledge.sh",
    "get_knowledge_document": "get-knowledge.sh",
    "verify_log_delivery": "verify-log-delivery.sh",
}

# Tools that require HITL approval before real execution (state-changing)
STATE_CHANGING_TOOLS: set[str] = {"execute_response_policy"}

# ---------------------------------------------------------------------------
# Argument builder -- converts JSON tool arguments to positional bash args
# ---------------------------------------------------------------------------

def _build_args(tool_name: str, arguments: dict) -> list[str]:
    """Convert tool JSON arguments to positional bash script arguments.

    Each bash script has its own positional arg convention (see script headers).
    This function maps the structured JSON arguments to the correct positional
    order for each script.
    """
    args: list[str] = []

    if tool_name == "list_security_events":
        # list-events.sh [time_range] [severity]
        if arguments.get("timeRange"):
            args.append(arguments["timeRange"])
        elif arguments.get("severity"):
            args.append("")  # placeholder for time_range
        if arguments.get("severity"):
            args.append(arguments["severity"])

    elif tool_name == "get_security_event_detail":
        # get-event-detail.sh <event_id>
        args.append(arguments.get("eventId", ""))

    elif tool_name == "list_alerts_for_event":
        # list-alerts.sh <event_id>
        args.append(arguments.get("eventId", ""))

    elif tool_name == "list_vulnerabilities":
        # list-vulnerabilities.sh [severity] [asset_id] [vul_type] [page]
        if arguments.get("severity"):
            args.append(arguments["severity"])
        elif arguments.get("assetId") or arguments.get("vulType"):
            args.append("")
        if arguments.get("assetId"):
            args.append(arguments["assetId"])
        elif arguments.get("vulType"):
            args.append("")
        if arguments.get("vulType"):
            args.append(arguments["vulType"])

    elif tool_name == "get_vulnerability_detail":
        # get-vulnerability-detail.sh <vul_id>
        args.append(arguments.get("vulnId", ""))

    elif tool_name == "list_response_policies":
        # list-response-policies.sh [scope]
        if arguments.get("scope"):
            args.append(arguments["scope"])

    elif tool_name == "execute_response_policy":
        # execute-response-policy.sh <policy_id> [event_id] [--real]
        args.append(arguments.get("policyId", ""))
        if arguments.get("eventId"):
            args.append(arguments["eventId"])
        if not arguments.get("dryRun", True):
            args.append("--real")

    elif tool_name in ("list_waf_security_events",):
        # list-waf-events.sh [time_range] [attack_type]
        if arguments.get("timeRange"):
            args.append(arguments["timeRange"])
        elif arguments.get("attackType"):
            args.append("")
        if arguments.get("attackType"):
            args.append(arguments["attackType"])

    elif tool_name in ("list_waf_top_rules", "list_waf_top_ips"):
        # list-waf-top-rules.sh [time_range]
        # list-waf-top-ips.sh [time_range]
        if arguments.get("timeRange"):
            args.append(arguments["timeRange"])

    elif tool_name == "list_assets":
        # list-assets.sh [criteria] [page]
        if arguments.get("criteria"):
            args.append(arguments["criteria"])

    elif tool_name == "get_knowledge_document":
        # get-knowledge.sh <document_type>
        args.append(arguments.get("type", ""))

    # ping, get_account_context, get_waf_instance_info, list_knowledge_documents
    # take no arguments
    return args


# ---------------------------------------------------------------------------
# Tool executor -- dispatches to bash scripts via subprocess
# ---------------------------------------------------------------------------

def execute_tool(name: str, arguments: dict) -> str:
    """Execute a tool by dispatching to the corresponding bash script.

    Returns the script's stdout as a string (JSON or plain text).
    On error, returns a JSON error object.

    Per Qwen Cloud function calling docs, the tool result is returned as a
    string in the 'tool' role message.
    """
    script = TOOL_SCRIPT_MAP.get(name)
    if not script:
        return json.dumps({"error": f"Unknown tool: {name}"})

    script_path: Path = SCRIPTS_DIR / script
    if not script_path.exists():
        return json.dumps({"error": f"Script not found: {script_path}"})

    # Build command
    cmd: list[str] = ["bash", str(script_path)]
    cmd.extend(_build_args(name, arguments))

    # Inherit environment and inject agent-specific vars
    env = os.environ.copy()
    env["SECURITY_CENTER_MODE"] = SECURITY_CENTER_MODE

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
        return json.dumps({"error": f"Tool '{name}' timed out after 30s."})
    except FileNotFoundError:
        return json.dumps({"error": f"bash not found. Ensure bash is installed and in PATH."})
    except Exception as exc:
        return json.dumps({"error": str(exc)})
