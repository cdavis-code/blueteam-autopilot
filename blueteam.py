#!/usr/bin/env python3
"""BlueTeam Autopilot — SecOps Agent powered by Qwen Cloud + ConnectOnion.

Usage:
    python blueteam.py                          # Interactive TUI
    python blueteam.py --prompt "Show events"   # Single prompt (cron)
    python blueteam.py --daemon --interval 60   # Autonomous SOC daemon
    echo "Show events" | python blueteam.py     # Piped stdin
"""

from __future__ import annotations

import argparse
import signal
import sys
import time
from datetime import datetime, timezone

from rich.console import Console

from connectonion import Agent
from connectonion.tui import Chat, CommandItem

from connectonion_qwen.config import (
    DASHSCOPE_API_KEY,
    ENABLE_THINKING,
    MAX_TOOL_ROUNDS,
    QWEN_BASE_URL,
    QWEN_MODEL,
    SECURITY_CENTER_MODE,
    validate,
)
from connectonion_qwen.qwen_llm import QwenCloudLLM
from connectonion_qwen.tools import ALL_TOOLS, STATE_CHANGING_TOOLS
from connectonion_qwen.plugins import hitl_approval_plugin, compliance_logger_plugin
from connectonion_qwen.system_prompt import SYSTEM_PROMPT
from connectonion_qwen.mcp import load_mcp_tools, shutdown_mcp, get_mcp_status
from workflows._engine import list_workflows


def _build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser."""
    parser = argparse.ArgumentParser(
        description="BlueTeam Autopilot — SecOps Agent",
        prog="blueteam",
    )
    parser.add_argument(
        "--prompt", "-p",
        type=str,
        default=None,
        help="Run non-interactively with this prompt (for cron/automation)",
    )
    parser.add_argument(
        "--daemon", "-d",
        action="store_true",
        help="Run as autonomous SOC daemon (continuous monitoring)",
    )
    parser.add_argument(
        "--interval", "-i",
        type=int,
        default=60,
        help="Monitoring interval in seconds for daemon mode (default: 60)",
    )
    return parser


def _read_stdin_if_piped() -> str:
    """Read stdin if data is piped in (non-blocking), else return empty string."""
    if sys.stdin.isatty():
        return ""
    return sys.stdin.read().strip()


def _now() -> str:
    """Return current UTC time as a formatted string."""
    return datetime.now(timezone.utc).strftime("%H:%M:%S")


def _run_prompt(prompt: str) -> None:
    """Run the agent with a single prompt and exit (cron/automation mode)."""
    # Validate configuration
    warnings = validate()
    if warnings:
        for w in warnings:
            print(f"Warning: {w}", file=sys.stderr)
        if not DASHSCOPE_API_KEY:
            print(
                "Error: DASHSCOPE_API_KEY required. Add to .env file.",
                file=sys.stderr,
            )
            sys.exit(1)

    # Create Qwen Cloud LLM provider
    llm = QwenCloudLLM(
        api_key=DASHSCOPE_API_KEY,
        model=QWEN_MODEL,
        base_url=QWEN_BASE_URL,
        enable_thinking=ENABLE_THINKING,
    )

    # Load MCP tools (graceful degradation — skipped if unavailable)
    mcp_tools = load_mcp_tools()
    all_tools = list(ALL_TOOLS) + mcp_tools

    # Create agent with quiet=True (suppress banner/console output for cron)
    agent = Agent(
        name="BlueTeam Autopilot",
        llm=llm,
        tools=all_tools,
        system_prompt=SYSTEM_PROMPT,
        max_iterations=MAX_TOOL_ROUNDS,
        plugins=[hitl_approval_plugin, compliance_logger_plugin],
        quiet=True,
    )

    try:
        response = agent.input(prompt)
        print(response)
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
    finally:
        shutdown_mcp()


# Global shutdown flag for daemon mode
_shutdown_requested = False


def _run_daemon(interval: int) -> None:
    """Run as autonomous SOC daemon — continuous monitoring loop."""
    global _shutdown_requested

    # Validate configuration
    warnings = validate()
    if warnings:
        for w in warnings:
            print(f"Warning: {w}", file=sys.stderr)
        if not DASHSCOPE_API_KEY:
            print("Error: DASHSCOPE_API_KEY required. Add to .env file.", file=sys.stderr)
            sys.exit(1)

    # Create Qwen Cloud LLM provider
    llm = QwenCloudLLM(
        api_key=DASHSCOPE_API_KEY,
        model=QWEN_MODEL,
        base_url=QWEN_BASE_URL,
        enable_thinking=ENABLE_THINKING,
    )

    # Load MCP tools
    mcp_tools = load_mcp_tools()
    all_tools = list(ALL_TOOLS) + mcp_tools

    # Create agent (quiet mode for daemon)
    agent = Agent(
        name="BlueTeam Autopilot (SOC Daemon)",
        llm=llm,
        tools=all_tools,
        system_prompt=SYSTEM_PROMPT,
        max_iterations=MAX_TOOL_ROUNDS,
        plugins=[hitl_approval_plugin, compliance_logger_plugin],
        quiet=True,
    )

    # Register signal handlers for graceful shutdown
    def _handle_signal(signum, frame):
        global _shutdown_requested
        _shutdown_requested = True
        print(f"\n[{_now()}] Shutdown signal received. Finishing current tick...")

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    # Daemon startup banner
    console = Console()
    console.print(f"\n[bold cyan]BlueTeam Autopilot — Autonomous SOC Daemon[/bold cyan]")
    console.print(f"Mode: [bold]{SECURITY_CENTER_MODE}[/bold] | "
                  f"Interval: [bold]{interval}s[/bold] | "
                  f"Model: [bold]{QWEN_MODEL}[/bold]")
    console.print(f"Press Ctrl+C to stop.\n")

    # Import workflow runner
    from workflows._engine import run_workflow as exec_workflow

    start_time = time.time()
    tick_count = 0
    total_escalations = 0

    try:
        while not _shutdown_requested:
            tick_count += 1
            tick_time = _now()

            console.print(f"[dim][{tick_time}] Tick #{tick_count} — scanning...[/dim]")

            try:
                result = exec_workflow("continuous-monitor")
                # Extract escalation summary from result
                output = result.get("output", "")
                if isinstance(output, str) and output.strip():
                    # Check for escalation keywords
                    if any(kw in output.upper() for kw in ["CRITICAL", "HIGH", "ESCALAT", "ALERT"]):
                        console.print(f"[bold red][{tick_time}] ESCALATION:[/bold red]")
                        console.print(output)
                        total_escalations += 1
                    elif "all clear" in output.lower() or "no new" in output.lower():
                        console.print(f"[green][{tick_time}] All clear[/green]")
                    else:
                        console.print(f"[{tick_time}] {output[:200]}")
                else:
                    console.print(f"[green][{tick_time}] All clear[/green]")
            except Exception as exc:
                console.print(f"[bold red][{tick_time}] Error:[/bold red] {exc}")

            # Sleep with shutdown check
            for _ in range(interval):
                if _shutdown_requested:
                    break
                time.sleep(1)

    finally:
        # Shutdown summary
        uptime = time.time() - start_time
        console = Console()
        console.print(f"\n[bold cyan]Daemon stopped.[/bold cyan]")
        console.print(f"  Uptime: {uptime:.0f}s | Ticks: {tick_count} | "
                      f"Escalations: {total_escalations}")
        shutdown_mcp()


def main() -> None:
    """Launch the BlueTeam Autopilot TUI or run a single prompt."""
    parser = _build_parser()
    args = parser.parse_args()

    # Daemon mode: autonomous SOC continuous monitoring
    if args.daemon:
        _run_daemon(args.interval)
        return

    # Collect prompt from --prompt and/or stdin
    prompt_parts: list[str] = []
    if args.prompt:
        prompt_parts.append(args.prompt)
    stdin_data = _read_stdin_if_piped()
    if stdin_data:
        prompt_parts.append(stdin_data)

    if prompt_parts:
        # Cron/automation mode: run single prompt and exit
        combined_prompt = "\n".join(prompt_parts)
        _run_prompt(combined_prompt)
        return

    # --- Interactive TUI mode (unchanged below) ---

    # Validate configuration
    warnings = validate()
    if warnings:
        for w in warnings:
            print(f"Warning: {w}", file=sys.stderr)
        print(
            "\nThe agent cannot start without DASHSCOPE_API_KEY. "
            "Add it to your .env file.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Create Qwen Cloud LLM provider
    llm = QwenCloudLLM(
        api_key=DASHSCOPE_API_KEY,
        model=QWEN_MODEL,
        base_url=QWEN_BASE_URL,
        enable_thinking=ENABLE_THINKING,
    )

    # Load MCP tools (graceful degradation — skipped if unavailable)
    with Console(stderr=True).status("[bold cyan]Loading MCP servers…"):
        mcp_tools = load_mcp_tools()
    all_tools = list(ALL_TOOLS) + mcp_tools

    # Create the agent with all tools and plugins
    agent = Agent(
        name="BlueTeam Autopilot",
        llm=llm,
        tools=all_tools,
        system_prompt=SYSTEM_PROMPT,
        max_iterations=MAX_TOOL_ROUNDS,
        plugins=[hitl_approval_plugin, compliance_logger_plugin],
    )

    # Build welcome message
    thinking_label = "on" if ENABLE_THINKING else "off"
    welcome = (
        f"**BlueTeam Autopilot v3.0.0** — SecOps Agent\n\n"
        f"Model: `{QWEN_MODEL}` | "
        f"Thinking: `{thinking_label}` | "
        f"Mode: `{SECURITY_CENTER_MODE}`\n\n"
        f"Ask me to investigate security events, check vulnerabilities, "
        f"or propose response actions."
    )

    # Launch the Textual TUI
    chat = Chat(
        agent=agent,
        title="BlueTeam Autopilot",
        welcome=welcome,
        hints=["/ commands", "Enter send", "Ctrl+D quit"],
        triggers={
            "/": [
                CommandItem(main="/help", prefix="?", id="/help"),
                CommandItem(main="/clear", prefix="⌫", id="/clear"),
                CommandItem(main="/model", prefix="⚙", id="/model"),
                CommandItem(main="/mcp", prefix="🔌", id="/mcp"),
                CommandItem(main="/tool", prefix="🔧", id="/tool"),
                CommandItem(main="/quit", prefix="→", id="/quit"),
            ]
        },
    )

    # Register slash command handlers
    chat.command("/help", _cmd_help)
    chat.command("/clear", _cmd_clear(agent))
    chat.command("/model", _cmd_model)
    chat.command("/mcp", _cmd_mcp)
    chat.command("/tool", _cmd_tool)
    chat.command("/workflow", _cmd_workflow)

    try:
        chat.run()
    finally:
        shutdown_mcp()


# ---------------------------------------------------------------------------
# Slash command handlers
# ---------------------------------------------------------------------------

HELP_TEXT = """**Available Commands:**
- `/help` — Show this help message
- `/clear` — Clear conversation history
- `/model` — Show current model and configuration
- `/mcp` — Show MCP server connection status
- `/tool` — List all built-in agent tools
- `/workflow` — List available specialist workflows
- `/quit` — Exit the agent

**Example Prompts:**
- Show me recent security events
- Investigate event evt-demo-20260614-001
- What response policies are available?
- Propose a response for event evt-demo-20260614-001
- Generate an incident report for event evt-demo-20260614-001"""


def _cmd_help(text: str) -> str:
    return HELP_TEXT


def _cmd_clear(agent):
    def handler(text: str) -> str:
        agent.reset_conversation()
        return "Conversation history cleared."
    return handler


def _cmd_model(text: str) -> str:
    thinking = "on" if ENABLE_THINKING else "off"
    return (
        f"**Model:** `{QWEN_MODEL}`\n"
        f"**Thinking:** `{thinking}`\n"
        f"**Mode:** `{SECURITY_CENTER_MODE}`\n"
        f"**Base URL:** `{QWEN_BASE_URL}`"
    )


def _cmd_mcp(text: str) -> str:
    status = get_mcp_status()
    if not status:
        return "**MCP Servers:** No servers configured or loaded."

    lines = ["**MCP Server Status:**\n"]
    total_tools = 0
    for name, info in status.items():
        state = info["status"]
        tools = info.get("tools", 0)
        total_tools += tools
        if state == "connected":
            icon = "✓"
            detail = f"{tools} tools ({info.get('transport', 'stdio')})"
        elif state == "failed":
            icon = "✗"
            detail = info.get("reason", "unknown error")
        elif state == "disabled":
            icon = "⊘"
            detail = "disabled in config"
        else:  # skipped
            icon = "⚠"
            detail = info.get("reason", "skipped")
        lines.append(f"- {icon} **{name}** — {detail}")

    connected = sum(1 for v in status.values() if v["status"] == "connected")
    lines.append(f"\n*{connected}/{len(status)} servers connected, {total_tools} total tools*")
    return "\n".join(lines)


# Tool category definitions (mirrors the section headers in tools.py)
_TOOL_CATEGORIES: list[tuple[str, list[str]]] = [
    ("Core", ["ping", "get_account_context"]),
    ("Security Events", ["list_security_events", "get_security_event_detail", "list_alerts_for_event"]),
    ("Vulnerabilities", ["list_vulnerabilities", "get_vulnerability_detail"]),
    ("Response Policies", ["list_response_policies", "execute_response_policy"]),
    ("WAF", ["get_waf_instance_info", "list_waf_security_events", "list_waf_top_rules", "list_waf_top_ips", "block_waf_ips"]),
    ("Assets", ["list_assets"]),
    ("Knowledge", ["list_knowledge_documents", "get_knowledge_document"]),
    ("Diagnostics", ["verify_log_delivery"]),
    ("Reporting", ["generate_incident_report"]),
    ("IAM Forensics", [
        "list_ram_users", "list_ram_roles", "list_ram_policies",
        "get_ram_credential_report", "get_role_trust_policy",
        "list_attached_policies_for", "analyze_trust_relationships",
        "score_risk_matrix", "detach_policy", "rotate_access_key",
        "delete_stale_user", "store_scan_snapshot", "diff_previous_scan",
    ]),
    ("Workflows", ["run_workflow"]),
    ("Vector Memory", ["search_similar_incidents", "store_incident_memory"]),
    ("Monitoring", ["get_monitor_state", "update_monitor_state"]),
]

# Build a lookup: tool function name → docstring first line
_TOOL_DOC: dict[str, str] = {}
for _t in ALL_TOOLS:
    _doc = (_t.__doc__ or "").strip().split("\n")[0].strip()
    _TOOL_DOC[_t.__name__] = _doc


def _cmd_tool(text: str) -> str:
    """List all built-in agent tools grouped by category."""
    lines = ["**Built-in Tools:**\n"]
    for category, tool_names in _TOOL_CATEGORIES:
        lines.append(f"**{category}**")
        for name in tool_names:
            doc = _TOOL_DOC.get(name, "")
            marker = " ⚠️" if name in STATE_CHANGING_TOOLS else ""
            lines.append(f"- `{name}`{marker} — {doc}")
        lines.append("")
    lines.append(f"*{len(ALL_TOOLS)} built-in tools | ⚠️️ = requires human approval*")
    return "\n".join(lines)


def _cmd_workflow(text: str) -> str:
    """List available specialist workflows."""
    workflows = list_workflows()
    if not workflows:
        return "**Workflows:** No workflows found. Add WORKFLOW.md files to the `workflows/` directory."

    lines = ["**Available Workflows:**\n"]
    for name, description in workflows.items():
        lines.append(f"- `{name}` — {description}")
    lines.append(f"\n*{len(workflows)} workflow(s) available*\n")
    lines.append("Run a workflow with: `run_workflow(\"<name>\")`")
    return "\n".join(lines)


if __name__ == "__main__":
    main()
