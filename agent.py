#!/usr/bin/env python3
"""BlueTeam Autopilot — SecOps Agent powered by Qwen Cloud + ConnectOnion.

Entry point: python agent.py
"""

from __future__ import annotations

import sys

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


def main() -> None:
    """Launch the BlueTeam Autopilot TUI."""
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
        f"**BlueTeam Autopilot v2.1.4** — SecOps Agent\n\n"
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
    lines.append(f"*{len(ALL_TOOLS)} built-in tools | ⚠️ = requires human approval*")
    return "\n".join(lines)


if __name__ == "__main__":
    main()
