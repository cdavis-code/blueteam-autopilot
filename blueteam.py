#!/usr/bin/env python3
"""BlueTeam — SecOps Agent powered by Qwen Cloud + ConnectOnion.

Usage:
    python blueteam.py                          # Interactive TUI
    python blueteam.py --prompt "Show events"   # Single prompt (cron)
    python blueteam.py --daemon --interval 60   # Autonomous SOC daemon
    echo "Show events" | python blueteam.py     # Piped stdin
"""

from __future__ import annotations

__version__ = "3.1.5"

import argparse
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path

from rich.console import Console

# ---------------------------------------------------------------------------
# Auto-sync skills on first run
# ---------------------------------------------------------------------------

REPO_URL = "https://github.com/cdavis-code/blueteam-autopilot.git"
SYNC_DIR = Path.home() / ".blueteam"


def _sync_skills() -> Path:
    """Clone or update the skills repo. Returns the project root.

    On first run, clones the repo to ~/.blueteam/. On subsequent runs,
    pulls updates. If skills/ exists locally (git clone), uses that instead.
    Falls back to the bundled blueteam_data/ in the installed package if
    git is unavailable (e.g., air-gapped or restricted environments).
    """
    # Check if skills exist locally (user cloned the repo)
    local_skills = Path.cwd() / "skills"
    if (local_skills / "blueteam-autopilot-core" / "fixtures").is_dir():
        return Path.cwd()

    # Check if already synced to ~/.blueteam/
    if (SYNC_DIR / "skills" / "blueteam-autopilot-core" / "fixtures").is_dir():
        # Pull updates (non-blocking, best-effort)
        try:
            subprocess.run(
                ["git", "pull", "--quiet"],
                cwd=SYNC_DIR,
                timeout=30,
                capture_output=True,
            )
        except Exception:
            pass  # Continue with existing version
        return SYNC_DIR

    # First run: clone repo. Preserve user's .env if they created it per setup docs.
    saved_env = None
    if SYNC_DIR.exists():
        env_file = SYNC_DIR / ".env"
        if env_file.is_file():
            saved_env = env_file.read_text()
        shutil.rmtree(SYNC_DIR, ignore_errors=True)
    print(f"First run detected. Downloading skills to {SYNC_DIR}...")
    try:
        subprocess.run(
            ["git", "clone", "--depth", "1", REPO_URL, str(SYNC_DIR)],
            timeout=120,
            check=True,
            capture_output=True,
        )
        if saved_env is not None:
            (SYNC_DIR / ".env").write_text(saved_env)
        print(f"Skills downloaded successfully.")
        return SYNC_DIR
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.decode(errors="replace").strip() if e.stderr else "unknown error"
        print(f"Git clone failed: {stderr}")
        print(f"Falling back to bundled skills in the installed package.")
        return _installed_package_root()
    except FileNotFoundError:
        print("git not found. Falling back to bundled skills in the installed package.")
        return _installed_package_root()


def _installed_package_root() -> Path:
    """Return the package installation directory (site-packages).

    Used as a fallback when git clone fails. blueteam_data/ is
    bundled in the pip package and serves as the skills source.
    """
    return Path(__file__).resolve().parent


# Sync skills before importing config (sets BLUETEAM_PROJECT_ROOT)
_project_root = _sync_skills()
os.environ["BLUETEAM_PROJECT_ROOT"] = str(_project_root)

from textual.widgets import Button, Input, Static
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual import on

from connectonion import Agent
from connectonion.tui import Chat, CommandItem
from connectonion.tui.chat import TriggerAutoComplete, UserMessage, UserMessageContainer, ThinkingIndicator

from connectonion_qwen.config import (
    DASHSCOPE_API_KEY,
    ENABLE_THINKING,
    MAX_TOOL_ROUNDS,
    QWEN_BASE_URL,
    QWEN_MODEL,
    SECURITY_CENTER_MODE,
    _PROJECT_ROOT,
    validate,
)
from connectonion_qwen.qwen_llm import QwenCloudLLM
from connectonion_qwen.tools import ALL_TOOLS, STATE_CHANGING_TOOLS
from connectonion_qwen.plugins import (
    hitl_approval_plugin,
    compliance_logger_plugin,
    tui_result_capture_plugin,
    set_tui_approval_callback,
    set_auto_approved_tools,
    set_tui_app,
)
from connectonion_qwen.system_prompt import SYSTEM_PROMPT
from connectonion_qwen.mcp import load_mcp_tools, shutdown_mcp, get_mcp_status
from workflows._engine import list_workflows


# ---------------------------------------------------------------------------
# HITL Approval Modal (TUI-aware)
# ---------------------------------------------------------------------------

# Shared state between the modal (Textual thread) and the HITL plugin (worker thread)
_approval_event = threading.Event()
_approval_result = False


class ApprovalScreen(ModalScreen[bool]):
    """Modal dialog for HITL approval of state-changing actions."""

    DEFAULT_CSS = """
    ApprovalScreen {
        align: center middle;
    }
    #approval-dialog {
        width: 80%;
        max-width: 100;
        height: auto;
        max-height: 80%;
        background: $surface;
        border: thick $primary;
        padding: 1 2;
    }
    #approval-body {
        width: 100%;
        height: auto;
        max-height: 60vh;
        overflow-y: auto;
        margin-bottom: 1;
    }
    #approval-buttons {
        height: auto;
        align: right middle;
    }
    #approval-buttons > Button {
        margin-left: 1;
    }
    """

    BINDINGS = [("y", "approve", "Approve"), ("n,escape", "reject", "Reject")]

    def __init__(self, tool_name: str, arguments: dict, dry_run: str) -> None:
        super().__init__()
        self._tool_name = tool_name
        self._arguments = arguments
        self._dry_run = dry_run

    def compose(self):
        args_display = json.dumps(self._arguments, indent=2)
        dry_display = self._dry_run[:500]
        if len(self._dry_run) > 500:
            dry_display += "\n...(truncated)"

        with Vertical(id="approval-dialog"):
            yield Static(
                f"[bold]Action requires approval (SOC 2 CC6.8.3)[/bold]\n\n"
                f"[bold]Action:[/bold]  {self._tool_name}\n"
                f"[bold]Arguments:[/bold]\n```\n{args_display}\n```\n"
                f"[bold]Dry-run:[/bold]\n```\n{dry_display}\n```",
                id="approval-body",
                markup=True,
            )
            with Horizontal(id="approval-buttons"):
                yield Button("Approve (y)", variant="success", id="approve")
                yield Button("Reject (n)", variant="error", id="reject")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        global _approval_result
        _approval_result = event.button.id == "approve"
        _approval_event.set()
        self.dismiss(_approval_result)

    def action_approve(self) -> None:
        global _approval_result
        _approval_result = True
        _approval_event.set()
        self.dismiss(True)

    def action_reject(self) -> None:
        global _approval_result
        _approval_result = False
        _approval_event.set()
        self.dismiss(False)


def _tui_approve(tool_name: str, arguments: dict, dry_run_result: str) -> bool:
    """Show approval modal and block until the user responds.

    Called from the agent worker thread. Uses a threading.Event to wait
    for the modal's button handler (Textual thread) to signal the result.
    """
    global _approval_result
    _approval_event.clear()
    _approval_result = False

    chat = _chat_instance
    if chat is None:
        return False

    chat.app.call_from_thread(
        chat.app.push_screen,
        ApprovalScreen(tool_name, arguments, dry_run_result),
    )

    if not _approval_event.wait(timeout=300):
        try:
            chat.app.call_from_thread(chat.app.pop_screen)
        except Exception:
            pass
        return False

    return _approval_result


_chat_instance: Chat | None = None


# ---------------------------------------------------------------------------
# Progress Log — accumulating step history for long-running agent tasks
# ---------------------------------------------------------------------------

class ProgressLog(ThinkingIndicator):
    """Thinking indicator that accumulates a scrollable history of steps.

    Extends ThinkingIndicator to append each completed step as a static
    line above the animated spinner. This gives the user visibility into
    the full sequence of actions taken, not just the current one.
    """

    DEFAULT_CSS = """
    ProgressLog {
        color: $success;
        text-style: italic;
        background: $success 10%;
        border-left: wide $success;
        margin: 1 2 1 1;
        padding: 0 2;
        height: auto;
    }
    """

    def __init__(self, message: str = "Thinking...", show_elapsed: bool = True):
        self._entries: list[str] = []
        self._last_logged: str | None = message
        self._pending_call: str | None = None
        self._pending_result: str | None = None
        super().__init__(message, show_elapsed)
        self._render_markup = False  # Plain text only — square brackets in tool results break Rich markup

    _ANSI_RE = re.compile('\x1b\\[[0-9;]*[a-zA-Z]|\x1b\\][^\x07]*\x07?')

    def set_result(self, result: str) -> None:
        """Append tool result after the command/description entry.

        Called from after_each_tool callback. Does NOT replace —
        appends so the command entry stays visible above the result.
        """
        if not result or not result.strip():
            return
        # Strip ANSI escape codes + all non-printable characters
        clean = self._ANSI_RE.sub('', result)
        clean = ''.join(c for c in clean if c.isprintable()).strip()
        if not clean:
            return
        # entry = f"  \u2514\u2500 {clean}"
        entry = f"  {clean}"
        self._entries.append(entry)

    def watch_message(self, old_value: str, new_value: str) -> None:
        """Capture previous message into history before it's overwritten."""
        super().watch_message(old_value, new_value) if hasattr(super(), "watch_message") else None
        if self._last_logged is not None and self._last_logged != new_value:
            display = self._last_logged.split("\n")[0].strip()
            # Only create entry for meaningful tool descriptions
            if (display
                    and display != "Thinking..."
                    and not display.startswith("run_command(")
                    and len(display) > 1):
                if len(display) > 200:
                    display = display[:200] + "..."
                entry = f"  \u2713 {display}"
                if not self._entries or self._entries[-1] != entry:
                    self._entries.append(entry)
        if old_value != new_value:
            self._last_logged = new_value
            self._pending_call = None

    def watch_function_call(self, new_value: str) -> None:
        """For run_command, show the actual command being executed."""
        if new_value and new_value.startswith("run_command("):
            # ConnectOnion truncates argument values to 30 chars, so
            # export ALIBABA_REGION="ap-southeast-1" && actual_command
            # becomes just export ALIBABA_REGION="ap-... (cut mid-value).
            # Skip these boilerplate entries entirely — _capture_tool_result
            # will show the actual result.
            if 'export ALIBABA_REGION=' in new_value:
                self._last_logged = new_value
            else:
                display = new_value
                if len(display) > 200:
                    display = display[:200] + "..."
                self._entries.append(f"  \u2713 {display}")
                self._last_logged = new_value
        super().watch_function_call(new_value) if hasattr(super(), "watch_function_call") else self.refresh(layout=True)

    def render(self) -> str:
        frame = self.frames[self.frame_no % len(self.frames)]
        if self.show_elapsed and self.elapsed > 0:
            hint = " (usually 5-20s)" if "Thinking" in self.message else ""
            main_line = f"{frame} {self.message} {self.elapsed}s{hint}"
        else:
            main_line = f"{frame} {self.message}"

        if self.function_call:
            main_line += f"\n  \u2514\u2500 {self.function_call}"

        if self._entries:
            return "\n".join(self._entries) + "\n\n" + main_line
        return main_line


# ---------------------------------------------------------------------------
# Skill-aware Chat subclass
# ---------------------------------------------------------------------------

def _make_chat_class(skills: dict[str, str]):
    """Create a Chat subclass that intercepts skill commands.

    Skill commands (e.g. /blueteam-autopilot-prep) are rewritten as agent
    prompts so they flow through process_message (not run_command). This
    gives full TUI integration: ThinkingIndicator, status bar updates,
    event callbacks, and HITL approval support.
    """

    class BlueTeamChat(Chat):
        @on(Input.Submitted)
        async def handle_input(self, event: Input.Submitted) -> None:
            text = event.value.strip()
            if not text or self._processing:
                return

            # Guard against mounting on a dismantling widget tree (e.g. after /exit)
            if self._closing or not self.is_attached:
                return

            # Handle exit commands directly — parent tries to mount after exit()
            if text.lower() in ("/quit", "/exit", "/q"):
                event.prevent_default()  # Prevent parent class handler from running
                self.exit()
                return

            # Check if this is a skill command
            skill_content = None
            for skill_name in skills:
                prefix = f"/{skill_name}"
                if text.lower() == prefix or text.lower().startswith(prefix + " "):
                    skill_content = _read_skill(skill_name, raw=True)
                    break

            # Not a skill command — delegate to parent
            if not skill_content:
                await super().handle_input(event)
                return

            # Skill command detected — handle with proper UX
            event.prevent_default()  # Prevent parent class handler from running
            event.input.clear()
            messages = self.query_one("#messages", VerticalScroll)

            # Show short command as user message (not full SKILL.md)
            user_container = UserMessageContainer(UserMessage(text))
            await messages.mount(user_container)
            self.call_later(self._scroll_to_bottom)

            # Set up processing state
            self._processing = True
            self._set_input_enabled(False)
            self._thinking_widget = ProgressLog()
            self._update_status("Thinking...")
            await messages.mount(self._thinking_widget)
            self.call_later(self._scroll_to_bottom)

            # Build full prompt with skill content
            full_prompt = (
                f"Execute the following skill: {skill_name}\n\n"
                f"{skill_content}"
            )

            # Route through process_message (agent.input with full TUI integration)
            self.process_message(full_prompt)

    return BlueTeamChat


# ---------------------------------------------------------------------------
# Monkey-patch: fix TriggerAutoComplete.apply_completion
# ---------------------------------------------------------------------------
# The TriggerAutoComplete override computes the correct completion string
# but only *returns* it — it never writes the value into the Input widget.
# The base class's apply_completion does `target.value = ""` then
# `target.insert_text_at_cursor(value)`, but the override replaces that
# with a return statement. Result: pressing Enter on a dropdown item
# does nothing visible in the input box.
#
# Fix: after computing the completion, actually update the target input.

def _fixed_apply_completion(self, value: str, target_state) -> None:
    text = target_state.text
    pos = self._find_trigger_position(text)
    if pos == -1:
        completion = value
    else:
        completion = value
        for item in self._candidates:
            if item.value == value and item.id:
                completion = item.id
                break
        completion = text[:pos] + completion

    target = self.target
    with self.prevent(Input.Changed):
        target.value = ""
        target.insert_text_at_cursor(completion)

    new_state = self._get_target_state()
    self._rebuild_options(new_state, self.get_search_string(new_state))


TriggerAutoComplete.apply_completion = _fixed_apply_completion


# ---------------------------------------------------------------------------
# Skill discovery
# ---------------------------------------------------------------------------

@lru_cache(maxsize=1)
def _discover_skills() -> dict[str, str]:
    """Scan skills/ directory for SKILL.md files.

    Returns a dict of {skill_name: description}.
    Each skill lives in skills/<name>/SKILL.md.
    Extracts description from YAML frontmatter if present,
    otherwise uses the first non-empty, non-heading line.
    """
    skills_dir = _PROJECT_ROOT / "skills"
    if not skills_dir.is_dir():
        return {}

    found: dict[str, str] = {}
    for entry in sorted(skills_dir.iterdir()):
        skill_md = entry / "SKILL.md"
        if not skill_md.is_file():
            continue
        name = entry.name
        desc = ""
        try:
            content = skill_md.read_text(errors="replace")
            lines = content.splitlines()
            # Check for YAML frontmatter
            if lines and lines[0].strip() == "---":
                # Parse description from frontmatter
                for line in lines[1:]:
                    if line.strip() == "---":
                        break  # End of frontmatter
                    if line.startswith("description:"):
                        desc = line[len("description:"):].strip().strip(">").strip()
                        # Multi-line YAML description (folded style)
                        if not desc:
                            # Collect continuation lines
                            desc_lines = []
                            idx = lines.index(line) + 1
                            while idx < len(lines):
                                next_line = lines[idx]
                                if next_line.startswith("  ") or next_line.startswith("\t"):
                                    desc_lines.append(next_line.strip())
                                    idx += 1
                                else:
                                    break
                            desc = " ".join(desc_lines)
                        break
            # Fallback: first non-empty, non-heading line
            if not desc:
                for line in lines:
                    stripped = line.strip()
                    if stripped and not stripped.startswith("#") and not stripped == "---":
                        desc = stripped[:80]
                        break
        except OSError:
            desc = "(could not read SKILL.md)"
        found[name] = desc[:80] if desc else "No description"
    return found


def _build_parser() -> argparse.ArgumentParser:
    """Build the CLI argument parser."""
    parser = argparse.ArgumentParser(
        description="BlueTeam — SecOps Agent",
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
    parser.add_argument(
        "--auto-approve",
        type=str,
        default="execute_local_script",
        help="Comma-delimited list of state-changing tools to auto-approve. "
        f"Available: {', '.join(sorted(STATE_CHANGING_TOOLS))}. "
        "Use 'none' to require HITL for all. Default: execute_local_script",
    )
    parser.add_argument(
        "--version", "-V",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    return parser


def _create_agent(*, name: str = "BlueTeam", quiet: bool = False) -> Agent:
    """Create a fully configured BlueTeam agent."""
    llm = QwenCloudLLM(
        api_key=DASHSCOPE_API_KEY,
        model=QWEN_MODEL,
        base_url=QWEN_BASE_URL,
        enable_thinking=ENABLE_THINKING,
    )
    mcp_tools = load_mcp_tools()
    all_tools = list(ALL_TOOLS) + mcp_tools
    return Agent(
        name=name,
        llm=llm,
        tools=all_tools,
        system_prompt=SYSTEM_PROMPT,
        max_iterations=MAX_TOOL_ROUNDS,
        plugins=[hitl_approval_plugin, tui_result_capture_plugin, compliance_logger_plugin],
        quiet=quiet,
    )


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

    agent = _create_agent(quiet=True)

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

    warnings = validate()
    if warnings:
        for w in warnings:
            print(f"Warning: {w}", file=sys.stderr)
        if not DASHSCOPE_API_KEY:
            print("Error: DASHSCOPE_API_KEY required. Add to .env file.", file=sys.stderr)
            sys.exit(1)

    agent = _create_agent(name="BlueTeam (SOC Daemon)", quiet=True)

    # Register signal handlers for graceful shutdown
    def _handle_signal(signum, frame):
        global _shutdown_requested
        _shutdown_requested = True
        print(f"\n[{_now()}] Shutdown signal received. Finishing current tick...")

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    # Daemon startup banner
    console = Console()
    console.print(f"\n[bold cyan]BlueTeam — Autonomous SOC Daemon[/bold cyan]")
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
    """Launch the BlueTeam TUI or run a single prompt."""
    parser = _build_parser()
    args = parser.parse_args()

    # Configure auto-approve tools (affects headless/daemon and TUI paths)
    auto_approved: set[str] = set()
    auto_approve_raw = args.auto_approve or ""
    if auto_approve_raw.lower() != "none":
        for tool in auto_approve_raw.split(","):
            tool = tool.strip()
            if tool in STATE_CHANGING_TOOLS:
                auto_approved.add(tool)
    set_auto_approved_tools(auto_approved)

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

    # Create the agent with all tools and plugins
    agent = _create_agent()

    # Build welcome message
    thinking_label = "on" if ENABLE_THINKING else "off"
    welcome = (
        f"**BlueTeam v{__version__}** — SecOps Agent\n\n"
        f"Model: `{QWEN_MODEL}` | "
        f"Thinking: `{thinking_label}` | "
        f"Mode: `{SECURITY_CENTER_MODE}`\n\n"
        f"Ask me to investigate security events, check vulnerabilities, "
        f"or propose response actions."
    )

    # Discover available skills for type-ahead
    skills = _discover_skills()
    skill_items = [
        CommandItem(main=f"/{name}", prefix="📄", id=f"/{name}")
        for name in skills
    ]

    # Use skill-aware Chat subclass
    BlueTeamChat = _make_chat_class(skills)

    # Launch the Textual TUI
    chat = BlueTeamChat(
        agent=agent,
        title="BlueTeam",
        welcome=welcome,
        hints=["/ commands", "Enter send", "Ctrl+D quit"],
        triggers={
            "/": [
                CommandItem(main="/help", prefix="?", id="/help"),
                CommandItem(main="/clear", prefix="⌫", id="/clear"),
                CommandItem(main="/model", prefix="⚙", id="/model"),
                CommandItem(main="/mcp", prefix="🔌", id="/mcp"),
                CommandItem(main="/tool", prefix="🔧", id="/tool"),
                CommandItem(main="/workflow", prefix="🔄", id="/workflow"),
                CommandItem(main="/skills", prefix="📚", id="/skills"),
                *skill_items,
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
    chat.command("/skills", _cmd_skills)

    # Wire up TUI-aware HITL approval (auto-approve scoping handled by plugins)
    global _chat_instance
    _chat_instance = chat
    set_tui_approval_callback(_tui_approve)

    # Register the TUI app for progress log result capture (Plugin 3 in plugins.py)
    set_tui_app(chat)

    try:
        chat.run()
    finally:
        set_tui_approval_callback(None)
        set_tui_app(None)
        _chat_instance = None
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
- `/skills` — List available agent skills
- `/quit` — Exit the agent

Type `/` to see a type-ahead dropdown of all commands and skills.

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


def _cmd_skills(text: str) -> str:
    """List available agent skills discovered from skills/ directory."""
    skills = _discover_skills()
    if not skills:
        return "**Skills:** No skills found. Add skill directories with SKILL.md files to the `skills/` directory."

    # Check if user requested a specific skill: /skills <name>
    parts = text.strip().split(maxsplit=1)
    if len(parts) > 1:
        skill_name = parts[1].strip().lstrip("/")
        if skill_name in skills:
            return _read_skill(skill_name)
        else:
            return f"**Skill not found:** `{skill_name}`\n\nUse `/skills` to list all available skills."

    lines = ["**Available Skills:**\n"]
    for name, desc in skills.items():
        lines.append(f"- `/{name}` — {desc}")
    lines.append(f"\n*{len(skills)} skill(s) available*")
    lines.append("\nType `/<skill-name>` to select from the type-ahead menu.")
    lines.append("Use `/skills <name>` to view a skill's full details.")
    return "\n".join(lines)


def _read_skill(skill_name: str, *, raw: bool = False) -> str | None:
    """Read SKILL.md content for a skill.

    Args:
        skill_name: The skill directory name.
        raw: If True, return raw content (or None if not found).
             If False, return formatted display string.
    """
    skill_md = _PROJECT_ROOT / "skills" / skill_name / "SKILL.md"
    try:
        content = skill_md.read_text(errors="replace").strip()
    except OSError:
        if raw:
            return None
        skills = _discover_skills()
        desc = skills.get(skill_name, "No description")
        return f"**Skill: {skill_name}**\n\n{desc}\n\n*(Could not read full SKILL.md)*"
    if raw:
        return content
    return f"**Skill: {skill_name}**\n\n{content}"


if __name__ == "__main__":
    main()
