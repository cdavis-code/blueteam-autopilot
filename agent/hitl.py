"""Human-in-the-loop checkpoint handler.

Enforces SOC 2 CC6.8.3 approval gates in code, not just in the prompt.
Per Qwen Cloud function calling best practices:
  "Add human confirmation for write operations: The model can generate action
   requests, but irreversible actions should require user confirmation."
"""

import json
import sys


def request_approval(
    tool_name: str,
    arguments: dict,
    dry_run_result: str,
    *,
    auto_approve: bool = False,
) -> bool:
    """Pause for human approval before executing a state-changing action.

    Displays the proposed action, dry-run results, and waits for y/N input.
    Returns True if approved, False if rejected.

    Args:
        tool_name: Name of the tool being called.
        arguments: Tool arguments (will be shown to the user).
        dry_run_result: Output from the dry-run simulation.
        auto_approve: If True, skip the prompt and approve automatically.
                      Use only for testing or pre-approved action registries.
    """
    if auto_approve:
        return True

    separator = "=" * 64
    print()
    print(separator)
    print("  ACTION REQUIRES HUMAN APPROVAL (SOC 2 CC6.8.3)")
    print(separator)
    print(f"  Action:     {tool_name}")
    print(f"  Arguments:  {json.dumps(arguments, indent=4)}")
    print(f"  Dry-run:    {_truncate(dry_run_result, 500)}")
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


def request_confirmation(
    message: str,
    *,
    default_yes: bool = False,
) -> bool:
    """Generic confirmation prompt for non-action checkpoints.

    Used for trusted network IP matches, CRITICAL severity escalations,
    and other decision points that need human input.

    Args:
        message: The confirmation question to display.
        default_yes: If True, default to 'yes' on empty input.

    Returns:
        True if confirmed, False otherwise.
    """
    suffix = "[Y/n]" if default_yes else "[y/N]"
    try:
        response = input(f"  {message} {suffix}: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        return default_yes

    if not response:
        return default_yes
    return response in ("y", "yes")


def _truncate(text: str, max_len: int = 500) -> str:
    """Truncate text for display, preserving the start."""
    text = text.strip()
    if len(text) <= max_len:
        return text
    return text[: max_len - 3] + "..."
