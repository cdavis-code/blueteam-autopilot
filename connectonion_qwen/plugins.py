"""ConnectOnion plugins for BlueTeam.

Plugin 1: hitl_approval — SOC 2 CC6.8.3 human-in-the-loop gate
Plugin 2: compliance_logger — audit trail + tool output truncation
Plugin 3: tui_result_capture — pushes tool results to TUI ProgressLog

All plugins share _get_last_tool_result() to avoid duplicate trace traversal.
"""

from __future__ import annotations

import json
import logging
import re
import subprocess
import threading
from collections.abc import Callable
from datetime import datetime, timezone
from pathlib import Path

from connectonion import before_each_tool, after_each_tool
from connectonion_qwen.config import SCRIPTS_DIR, FIXTURES_DIR, KNOWLEDGE_DIR, SECURITY_CENTER_MODE
from connectonion_qwen.config import _PROJECT_ROOT
from connectonion_qwen.tools import _build_script_env, _DEFAULT_TIMEOUT

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# TUI progress widget reference — set by blueteam.py when running in TUI mode.
# The after_each_tool handler uses this to push results to the ProgressLog.
# ---------------------------------------------------------------------------
_tui_app: object | None = None  # Textual App instance (for call_from_thread)


def set_tui_app(app: object) -> None:
    """Register the TUI app for progress log result capture."""
    global _tui_app
    _tui_app = app

# Tools that require HITL approval before real execution
_STATE_CHANGING_TOOLS = {
    "execute_response_policy",
    "block_waf_ips",
    "detach_policy",
    "rotate_access_key",
    "delete_stale_user",
    "execute_local_script",
    "run_command",
}

_MAX_OUTPUT_LENGTH = 4000
_MAX_DRY_RUN_DISPLAY = 500

# TUI-aware approval callback — set by blueteam.py when running in TUI mode.
# Signature: (tool_name, arguments, dry_run_result) -> bool
# When set, _request_approval uses this instead of terminal input().
_tui_approval_callback: Callable | None = None

# Auto-approved tools set — populated by CLI args (e.g. --auto-approve)
# Tools in this set skip HITL confirmation, even though they are state-changing.
_auto_approved_tools: set[str] = set()


def set_tui_approval_callback(callback: Callable | None) -> None:
    """Register a TUI-aware approval callback (or None to use terminal input)."""
    global _tui_approval_callback
    _tui_approval_callback = callback


def set_auto_approved_tools(tools: set[str]) -> None:
    """Set which state-changing tools skip HITL confirmation.

    Tools in this set are auto-approved and bypass the approval gate
    entirely. The approval callback (TUI modal or terminal prompt) is
    only triggered for state-changing tools NOT in this set.
    """
    global _auto_approved_tools
    _auto_approved_tools = tools or set()


# ---------------------------------------------------------------------------
# Shared: extract the last tool_result trace entry once per handler
# ---------------------------------------------------------------------------

def _get_last_tool_result(agent) -> dict | None:
    """Return the most recent tool_result trace entry, or None.

    Both compliance_logger and capture_tool_result need the same
    trace traversal logic. This helper eliminates the duplication.

    Returns a dict with keys: entry, tool_name, result, status,
    timing_ms, args — or None if no tool_result is found.
    """
    trace = agent.current_session.get("trace", [])
    if not trace:
        return None
    last = trace[-1]
    if last.get("type") != "tool_result":
        return None
    return {
        "entry": last,
        "tool_name": last.get("tool_name", last.get("name", "")),
        "result": last.get("result", ""),
        "status": last.get("status", "unknown"),
        "timing_ms": last.get("timing_ms", 0),
        "args": last.get("args", {}),
    }


# ---------------------------------------------------------------------------
# Plugin 1: HITL Approval Gate
# ---------------------------------------------------------------------------

def _run_dry_run(tool_name: str, arguments: dict) -> str:
    """Execute a tool in dry-run mode and return the result."""
    if tool_name == "execute_local_script":
        script_path = arguments.get("script_path", "")
        script_args = arguments.get("arguments", "")
        return json.dumps({
            "dry_run": True,
            "command": f"bash {script_path} {script_args}".strip(),
            "message": "This will execute the above command. Review the script path and arguments carefully.",
        })

    if tool_name == "run_command":
        command = arguments.get("command", "")
        return json.dumps({
            "dry_run": True,
            "command": f"bash -c '{command}'",
            "message": "This will execute the above bash command. Review carefully before approving.",
        })

    script_map = {
        "execute_response_policy": "execute-response-policy.sh",
        "block_waf_ips": "block-waf-ips.sh",
        "detach_policy": "detach-policy.sh",
        "rotate_access_key": "rotate-access-key.sh",
        "delete_stale_user": "delete-stale-user.sh",
    }
    script = script_map.get(tool_name)
    if not script:
        return json.dumps({"error": f"No dry-run mapping for {tool_name}"})

    script_path = SCRIPTS_DIR / script
    if not script_path.exists():
        return json.dumps({"error": f"Script not found: {script_path}"})

    args: list[str] = []
    if tool_name == "execute_response_policy":
        args.append(arguments.get("policy_id", arguments.get("policyId", "")))
        event_id = arguments.get("event_id", arguments.get("eventId", ""))
        if event_id:
            args.append(event_id)
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

    try:
        result = subprocess.run(
            ["bash", str(script_path)] + args,
            capture_output=True,
            text=True,
            timeout=_DEFAULT_TIMEOUT,
            env=_build_script_env(),
            cwd=str(_PROJECT_ROOT),
        )
        return result.stdout.strip() or json.dumps({"status": "ok", "message": "Dry run complete."})
    except Exception as exc:
        return json.dumps({"error": str(exc)})


def _request_approval(tool_name: str, arguments: dict, dry_run_result: str) -> bool:
    """Display action details and request human approval.

    Uses the TUI callback when available (TUI mode), otherwise falls
    back to terminal input() (CLI/daemon mode).
    """
    if _tui_approval_callback is not None:
        return _tui_approval_callback(tool_name, arguments, dry_run_result)

    separator = "=" * 64
    print()
    print(separator)
    print("  ACTION REQUIRES HUMAN APPROVAL (SOC 2 CC6.8.3)")
    print(separator)
    print(f"  Action:     {tool_name}")
    print(f"  Arguments:  {json.dumps(arguments, indent=4)}")
    display = dry_run_result.strip()
    if len(display) > _MAX_DRY_RUN_DISPLAY:
        display = display[:_MAX_DRY_RUN_DISPLAY - 3] + "..."
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

    # Skip HITL if this tool is in the CLI-configured auto-approved set
    if tool_name in _auto_approved_tools:
        return

    arguments = pending.get("arguments", {})

    dry_result = _run_dry_run(tool_name, arguments)
    approved = _request_approval(tool_name, arguments, dry_result)

    if not approved:
        raise ValueError(
            json.dumps({
                "rejected": True,
                "reason": "User denied approval. No action was taken.",
            })
        )


# ---------------------------------------------------------------------------
# Prompt Injection Filter — loads patterns from injection_patterns.json
# ---------------------------------------------------------------------------

_INJECTION_PATTERNS: list[dict] = []
_PATTERNS_LOADED = False


def _load_injection_patterns() -> list[dict]:
    """Load injection detection patterns from the JSON pattern file.

    Patterns are loaded once and cached. Each entry has:
    - id: unique pattern identifier
    - severity: critical | high | medium
    - description: human-readable label
    - regex: compiled re.Pattern
    """
    global _INJECTION_PATTERNS, _PATTERNS_LOADED
    if _PATTERNS_LOADED:
        return _INJECTION_PATTERNS

    pattern_file = Path(__file__).parent / "injection_patterns.json"
    if not pattern_file.exists():
        logger.warning(f"Injection pattern file not found: {pattern_file}")
        _PATTERNS_LOADED = True
        return _INJECTION_PATTERNS

    try:
        data = json.loads(pattern_file.read_text(encoding="utf-8"))
        for entry in data.get("patterns", []):
            try:
                compiled = re.compile(entry["regex"])
                _INJECTION_PATTERNS.append({
                    "id": entry["id"],
                    "severity": entry.get("severity", "medium"),
                    "description": entry.get("description", ""),
                    "regex": compiled,
                })
            except re.error as exc:
                logger.warning(f"Invalid regex in pattern '{entry.get('id')}': {exc}")
        logger.info(f"Loaded {len(_INJECTION_PATTERNS)} injection detection patterns")
    except (json.JSONDecodeError, KeyError) as exc:
        logger.error(f"Failed to parse injection patterns: {exc}")

    _PATTERNS_LOADED = True
    return _INJECTION_PATTERNS


def _scan_for_injections(text: str) -> list[dict]:
    """Scan text for prompt injection patterns.

    Returns a list of matches, each with:
    - id: pattern identifier
    - severity: critical | high | medium
    - description: human-readable label
    - match_text: the matched substring
    """
    patterns = _load_injection_patterns()
    if not patterns:
        return []

    matches: list[dict] = []
    for pat in patterns:
        found = pat["regex"].search(text)
        if found:
            matches.append({
                "id": pat["id"],
                "severity": pat["severity"],
                "description": pat["description"],
                "match_text": found.group(),
            })
    return matches


def _sanitize_injections(text: str, tool_name: str) -> str:
    """Screen tool output for prompt injection patterns.

    - critical: replace entire content with a rejection notice
    - high: redact the offending line(s) and log
    - medium: log warning but pass content through

    Returns the (possibly sanitized) text.
    """
    matches = _scan_for_injections(text)
    if not matches:
        return text

    timestamp = datetime.now(timezone.utc).isoformat()
    critical_hits = [m for m in matches if m["severity"] == "critical"]
    high_hits = [m for m in matches if m["severity"] == "high"]
    medium_hits = [m for m in matches if m["severity"] == "medium"]

    # Log all detections for audit
    for m in matches:
        logger.warning(
            f"[INJECTION DETECTED] {timestamp} | tool={tool_name} "
            f"| pattern={m['id']} | severity={m['severity']} "
            f"| match={m['match_text']!r}"
        )

    # Critical: reject entire content
    if critical_hits:
        pattern_ids = ", ".join(m["id"] for m in critical_hits)
        logger.error(
            f"[INJECTION BLOCKED] {timestamp} | tool={tool_name} "
            f"| patterns=[{pattern_ids}] — content rejected entirely"
        )
        return (
            "[PROMPT INJECTION DETECTED — CONTENT BLOCKED]\n"
            f"The tool output contained {len(critical_hits)} critical injection "
            f"pattern(s): {pattern_ids}.\n"
            "The original content has been replaced with this notice.\n"
            "Investigate the source of this data for potential adversarial input."
        )

    # High: redact offending lines
    if high_hits:
        pattern_ids = ", ".join(m["id"] for m in high_hits)
        match_texts = {m["match_text"] for m in high_hits}
        redacted = text
        for mt in match_texts:
            redacted = redacted.replace(mt, "[REDACTED — injection pattern]")
        logger.warning(
            f"[INJECTION REDACTED] {timestamp} | tool={tool_name} "
            f"| patterns=[{pattern_ids}] — offending content redacted"
        )
        text = redacted

    # Medium: logged above, content passes through
    if medium_hits and not high_hits:
        pattern_ids = ", ".join(m["id"] for m in medium_hits)
        logger.info(
            f"[INJECTION FLAG] {timestamp} | tool={tool_name} "
            f"| patterns=[{pattern_ids}] — content passed through (medium severity)"
        )

    return text


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
    info = _get_last_tool_result(agent)
    if info is None:
        return

    timestamp = datetime.now(timezone.utc).isoformat()
    logger.info(
        f"[AUDIT] {timestamp} | {info['tool_name']}({json.dumps(info['args'])}) "
        f"| status={info['status']} | {info['timing_ms']:.0f}ms"
    )

    result = info['result']
    if result and len(result) > _MAX_OUTPUT_LENGTH:
        result = (
            result[:_MAX_OUTPUT_LENGTH]
            + "\n...[truncated for context window management]"
        )

    # Screen for prompt injection patterns before boundary wrapping
    if result is not None:
        result = _sanitize_injections(result, info['tool_name'])

    # Wrap result in prompt-injection boundary delimiters so the LLM can
    # distinguish external untrusted data from trusted instruction content.
    if result is not None:
        info['entry']["result"] = (
            "[TOOL OUTPUT START]\n"
            + result
            + "\n[TOOL OUTPUT END]"
        )


# ---------------------------------------------------------------------------
# Plugin 3: TUI Result Capture
# ---------------------------------------------------------------------------

@after_each_tool
def capture_tool_result(agent) -> None:
    """Push tool results to the TUI ProgressLog widget.

    Runs in all modes but is a no-op when no TUI app is registered.
    Must run BEFORE compliance_logger so it sees the raw (unwrapped) result.
    """
    if _tui_app is None:
        return
    widget = getattr(_tui_app, '_thinking_widget', None)
    if widget is None or not hasattr(widget, 'set_result'):
        return

    info = _get_last_tool_result(agent)
    if info is None:
        return
    result = info['result']
    if not result:
        return

    # Truncate for display: use first non-empty line
    lines = [l.strip() for l in result.splitlines() if l.strip()]
    first_line = lines[0] if lines else result.strip()[:200]
    if not first_line or len(first_line) < 2:
        return
    if len(first_line) > 200:
        first_line = first_line[:200] + "..."

    tool_name = info['tool_name']
    if tool_name and first_line:
        display = f"{tool_name}: {first_line}"
    else:
        display = tool_name or first_line
    if display and display.strip():
        _tui_app.call_from_thread(widget.set_result, display)


# ---------------------------------------------------------------------------
# Plugin bundles (list of event handlers)
# ---------------------------------------------------------------------------

hitl_approval_plugin = [hitl_approval]
compliance_logger_plugin = [compliance_logger]
tui_result_capture_plugin = [capture_tool_result]
