"""ConnectOnion plugins for BlueTeam Autopilot.

Plugin 1: hitl_approval — SOC 2 CC6.8.3 human-in-the-loop gate
Plugin 2: compliance_logger — audit trail + tool output truncation
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
from datetime import datetime, timezone

from connectonion import before_each_tool, after_each_tool
from connectonion_qwen.config import SCRIPTS_DIR, SECURITY_CENTER_MODE

logger = logging.getLogger(__name__)

# Import merged state-changing tools from all active providers
from connectonion_qwen.tools import STATE_CHANGING_TOOLS as _STATE_CHANGING_TOOLS

# Maximum tool output length before truncation
_MAX_OUTPUT_LENGTH = 4000


# ---------------------------------------------------------------------------
# Plugin 1: HITL Approval Gate
# ---------------------------------------------------------------------------

def _run_dry_run(tool_name: str, arguments: dict) -> str:
    """Execute a tool in dry-run mode and return the result."""
    script_map = {
        # Aliyun tools
        "execute_response_policy": "execute-response-policy.sh",
        "block_waf_ips": "block-waf-ips.sh",
        "detach_policy": "detach-policy.sh",
        "rotate_access_key": "rotate-access-key.sh",
        "delete_stale_user": "delete-stale-user.sh",
        # AWS tools
        "aws_block_waf_ips": "aws-block-waf-ips.sh",
        "aws_update_finding": "aws-update-finding.sh",
    }
    script = script_map.get(tool_name)
    if not script:
        return json.dumps({"error": f"No dry-run mapping for {tool_name}"})

    script_path = SCRIPTS_DIR / script
    if not script_path.exists():
        return json.dumps({"error": f"Script not found: {script_path}"})

    # Build args with dry-run (no --real flag)
    args: list[str] = []
    if tool_name == "execute_response_policy":
        args.append(arguments.get("policy_id", arguments.get("policyId", "")))
        event_id = arguments.get("event_id", arguments.get("eventId", ""))
        if event_id:
            args.append(event_id)
        # Explicitly do NOT add --real (this is the dry run)
    elif tool_name == "block_waf_ips":
        args.append(arguments.get("ips", ""))
        args.append("--dry-run")
    elif tool_name == "detach_policy":
        args.append(arguments.get("entity_type", ""))
        args.append(arguments.get("entity_name", ""))
        args.append(arguments.get("policy_name", ""))
    elif tool_name == "rotate_access_key":
        args.append(arguments.get("user_name", ""))
        args.append(arguments.get("access_key_id", ""))
    elif tool_name == "delete_stale_user":
        args.append(arguments.get("user_name", ""))
    elif tool_name == "aws_block_waf_ips":
        args.append(arguments.get("ips", ""))
        if arguments.get("dry_run", True):
            pass  # no --real flag = dry-run
        else:
            args.append("--real")
    elif tool_name == "aws_update_finding":
        args.append(arguments.get("finding_id", ""))
        args.append(arguments.get("status", "NOTIFIED"))

    env = os.environ.copy()
    env["SECURITY_CENTER_MODE"] = SECURITY_CENTER_MODE

    try:
        result = subprocess.run(
            ["bash", str(script_path)] + args,
            capture_output=True,
            text=True,
            timeout=30,
            env=env,
            cwd=str(SCRIPTS_DIR.parent.parent.parent),
        )
        return result.stdout.strip() or json.dumps({"status": "ok", "message": "Dry run complete."})
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def _request_approval(tool_name: str, arguments: dict, dry_run_result: str) -> bool:
    """Display action details and request human approval via terminal."""
    separator = "=" * 64
    print()
    print(separator)
    print("  ACTION REQUIRES HUMAN APPROVAL (SOC 2 CC6.8.3)")
    print(separator)
    print(f"  Action:     {tool_name}")
    print(f"  Arguments:  {json.dumps(arguments, indent=4)}")
    # Truncate dry-run for display
    display = dry_run_result.strip()
    if len(display) > 500:
        display = display[:497] + "..."
    print(f"  Dry-run:    {display}")
    print(separator)

    try:
        response = input("  Approve this action? [y/N]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\n  Decision:   REJECTED (input interrupted)")
        print(separator)
        return False

    approved = response in ("y", "yes")
    decision = "APPROVED" if approved else "REJECTED"
    print(f"  Decision:   {decision}")
    print(separator)
    print()
    return approved


@before_each_tool
def hitl_approval(agent) -> None:
    """Intercept state-changing tools and require human approval.

    Uses ConnectOnion's before_each_tool hook. The pending tool info
    is available via agent.current_session['pending_tool'].

    If the user rejects, raises an exception to prevent tool execution.
    The error message is returned to the LLM as the tool result.
    """
    pending = agent.current_session.get("pending_tool", {})
    tool_name = pending.get("name", "")

    if tool_name not in _STATE_CHANGING_TOOLS:
        return

    arguments = pending.get("arguments", {})

    # Run dry-run first
    dry_result = _run_dry_run(tool_name, arguments)

    # Request approval
    approved = _request_approval(tool_name, arguments, dry_result)

    if not approved:
        raise ValueError(
            json.dumps({
                "rejected": True,
                "reason": "User denied approval. No action was taken.",
            })
        )


# ---------------------------------------------------------------------------
# Plugin 2: Compliance Logger
# ---------------------------------------------------------------------------

@after_each_tool
def compliance_logger(agent) -> None:
    """Log tool executions for SOC 2 audit trail and truncate large outputs.

    Fires after each tool execution. Performs two functions:
    1. Logs the tool call with timestamp for audit trail
    2. Truncates tool outputs > 4000 chars to prevent context bloat
    """
    # Find the most recent tool trace entry
    trace = agent.current_session.get("trace", [])
    if not trace:
        return

    last_entry = trace[-1]
    if last_entry.get("type") != "tool_result":
        return

    tool_name = last_entry.get("name", "unknown")
    tool_args = last_entry.get("args", {})
    status = last_entry.get("status", "unknown")
    timing = last_entry.get("timing_ms", 0)
    timestamp = datetime.now(timezone.utc).isoformat()

    # Log for audit trail
    logger.info(
        f"[AUDIT] {timestamp} | {tool_name}({json.dumps(tool_args)}) "
        f"| status={status} | {timing:.0f}ms"
    )

    # Truncate large tool outputs to prevent context bloat
    result = last_entry.get("result", "")
    if result and len(result) > _MAX_OUTPUT_LENGTH:
        last_entry["result"] = (
            result[:_MAX_OUTPUT_LENGTH]
            + "\n...[truncated for context window management]"
        )


# ---------------------------------------------------------------------------
# Plugin bundles (list of event handlers)
# ---------------------------------------------------------------------------

hitl_approval_plugin = [hitl_approval]
compliance_logger_plugin = [compliance_logger]
