"""Interactive CLI for BlueTeam Autopilot.

Entry point: python -m agent.cli
"""

from __future__ import annotations

import json
import sys

from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.text import Text

from agent.config import ENABLE_THINKING, QWEN_MODEL, SECURITY_CENTER_MODE, validate
from agent.main import AgentCallbacks, AgentResult, create_client, run_agent

console = Console()
err_console = Console(stderr=True)


# ---------------------------------------------------------------------------
# Callbacks -- print agent activity to the terminal
# ---------------------------------------------------------------------------

def _on_thinking(text: str) -> None:
    """Display thinking-mode reasoning content."""
    if text.strip():
        console.print(Text(text.strip(), style="dim italic"), highlight=False)


def _on_tool_call(name: str, arguments: dict) -> None:
    """Display a tool call."""
    args_str = ", ".join(f'{k}="{v}"' for k, v in arguments.items())
    console.print(f"  [bold cyan]Tool call[/] {name}({args_str})")


def _on_tool_result(name: str, result: str) -> None:
    """Display a tool result (truncated for readability)."""
    display = result.strip()
    if len(display) > 400:
        display = display[:400] + "..."
    # Try to pretty-print JSON
    try:
        parsed = json.loads(display)
        display = json.dumps(parsed, indent=2)
        if len(display) > 600:
            display = display[:600] + "\n  ..."
    except (json.JSONDecodeError, TypeError):
        pass
    console.print(f"  [dim]Result:[/] {display}")


def _on_text(text: str) -> None:
    """Display the final agent response."""
    if text.strip():
        console.print()
        console.print(Markdown(text))


# ---------------------------------------------------------------------------
# Main CLI loop
# ---------------------------------------------------------------------------

def _print_banner() -> None:
    """Print the startup banner."""
    thinking_label = "on" if ENABLE_THINKING else "off"
    mode_label = SECURITY_CENTER_MODE
    console.print(
        Panel(
            f"[bold]BlueTeam Autopilot v2.0[/] -- Qwen Cloud Powered\n"
            f"Model: [cyan]{QWEN_MODEL}[/] | "
            f"Thinking: [cyan]{thinking_label}[/] | "
            f"Mode: [cyan]{mode_label}[/]\n"
            f"Type a message to begin, or /help for commands.",
            title="SecOps Agent",
            border_style="blue",
        )
    )


HELP_TEXT = """
[bold]Commands:[/]
  /help       Show this help message
  /clear      Clear conversation history
  /history    Show message count
  /model      Show current model and configuration
  /quit       Exit the agent

[bold]Examples:[/]
  Show me recent security events
  Investigate event evt-demo-20260614-001
  What response policies are available?
  Propose a response for event evt-demo-20260614-001
  Generate an incident report for event evt-demo-20260614-001
"""


def main() -> None:
    """Run the interactive CLI."""
    # Validate configuration
    warnings = validate()
    if warnings:
        for w in warnings:
            err_console.print(f"[bold red]Warning:[/] {w}")
        err_console.print(
            "\n[dim]The agent will not work without DASHSCOPE_API_KEY. "
            "Add it to your .env file.[/]"
        )
        sys.exit(1)

    _print_banner()

    client = create_client()
    callbacks = AgentCallbacks(
        on_thinking=_on_thinking,
        on_tool_call=_on_tool_call,
        on_tool_result=_on_tool_result,
        on_text=_on_text,
    )

    history: list[dict] = []  # multi-turn conversation history

    while True:
        try:
            user_input = console.input("\n[bold green]>[/] ").strip()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]Goodbye.[/]")
            break

        if not user_input:
            continue

        # Handle slash commands
        if user_input.startswith("/"):
            cmd = user_input.lower().split()[0]
            if cmd in ("/quit", "/exit", "/q"):
                console.print("[dim]Goodbye.[/]")
                break
            elif cmd == "/help":
                console.print(HELP_TEXT)
                continue
            elif cmd == "/clear":
                history.clear()
                console.print("[dim]History cleared.[/]")
                continue
            elif cmd == "/history":
                console.print(f"[dim]{len(history)} messages in history.[/]")
                continue
            elif cmd == "/model":
                thinking = "on" if ENABLE_THINKING else "off"
                console.print(
                    f"[dim]Model: {QWEN_MODEL} | "
                    f"Thinking: {thinking} | "
                    f"Mode: {SECURITY_CENTER_MODE}[/]"
                )
                continue
            else:
                console.print(f"[yellow]Unknown command: {cmd}. Type /help.[/]")
                continue

        # Run the agent
        console.print()  # blank line before agent activity
        try:
            result: AgentResult = run_agent(
                user_input,
                client=client,
                callbacks=callbacks,
                history=history,
            )
        except Exception as exc:
            err_console.print(f"[bold red]Error:[/] {exc}")
            continue

        # Update conversation history (exclude system prompt from stored history)
        # history stores everything after the system message
        for msg in result.messages:
            if msg.get("role") == "system":
                continue
            history.append(msg)

        # Print stats
        console.print(
            f"\n[dim]({result.tool_calls_made} tool calls, "
            f"{len(result.messages)} messages)[/]"
        )


if __name__ == "__main__":
    main()
