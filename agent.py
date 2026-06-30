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
from connectonion_qwen.tools import ALL_TOOLS
from connectonion_qwen.plugins import hitl_approval_plugin, compliance_logger_plugin
from connectonion_qwen.system_prompt import SYSTEM_PROMPT
from connectonion_qwen.mcp import load_mcp_tools, shutdown_mcp


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
        f"**BlueTeam Autopilot v2.3.0** — SecOps Agent\n\n"
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
                CommandItem(main="/quit", prefix="→", id="/quit"),
            ]
        },
    )

    # Register slash command handlers
    chat.command("/help", _cmd_help)
    chat.command("/clear", _cmd_clear(agent))
    chat.command("/model", _cmd_model)

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


if __name__ == "__main__":
    main()
