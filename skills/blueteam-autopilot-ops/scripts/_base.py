#!/usr/bin/env python3
"""Base class for BlueTeam scripts.

Provides common functionality for demo/real mode dispatch, fixture loading,
and aliyun CLI execution.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
from pathlib import Path

from _helpers import discover_region, load_fixture, rewrite_timestamps

logger = logging.getLogger(__name__)

_DEFAULT_TIMEOUT = 30
_LONG_TIMEOUT = 60


class BaseScript:
    """Base class for all BlueTeam scripts.

    Handles mode detection, fixture loading, and aliyun CLI execution.
    Subclasses implement execute() to define script-specific behavior.
    """

    def __init__(self):
        self.mode = os.environ.get("SECURITY_CENTER_MODE", "demo")
        self.fixtures_dir = Path(os.environ.get("BLUETEAM_FIXTURES_DIR", ""))
        self.knowledge_dir = Path(os.environ.get("BLUETEAM_KNOWLEDGE_DIR", ""))
        self.project_root = Path(os.environ.get("BLUETEAM_PROJECT_ROOT", ""))
        self._region: str | None = None

    @property
    def region(self) -> str:
        """Lazy-loaded region discovery."""
        if self._region is None:
            self._region = discover_region()
        return self._region

    def load_demo(self, fixture_name: str) -> str:
        """Load fixture JSON with timestamp rewriting.

        Args:
            fixture_name: Name of fixture file (e.g., 'ping.json')

        Returns:
            JSON string with fresh timestamps
        """
        return load_fixture(fixture_name, self.fixtures_dir)

    def run_aliyun(self, args: list[str], timeout: int = _DEFAULT_TIMEOUT) -> str:
        """Execute aliyun CLI command.

        Args:
            args: Command arguments (e.g., ['sas', 'describe-susp-events', '--region', 'ap-southeast-1'])
            timeout: Timeout in seconds

        Returns:
            JSON string from aliyun CLI output, or error JSON
        """
        cmd = ["aliyun"] + args

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=str(self.project_root) if self.project_root else None,
            )

            output = result.stdout.strip()

            if result.returncode != 0:
                stderr = result.stderr.strip()
                return json.dumps({
                    "error": stderr or output or f"aliyun CLI exited with code {result.returncode}",
                    "exit_code": result.returncode,
                })

            # Pretty-print JSON if possible
            try:
                data = json.loads(output)
                return json.dumps(data, indent=2)
            except json.JSONDecodeError:
                return output

        except subprocess.TimeoutExpired:
            return json.dumps({"error": f"aliyun CLI timed out after {timeout}s."})
        except FileNotFoundError:
            return json.dumps({
                "error": "aliyun CLI not found. Install from https://github.com/aliyun/aliyun-cli"
            })
        except Exception as exc:
            logger.error(f"aliyun CLI execution failed: {exc}", exc_info=True)
            return json.dumps({"error": f"aliyun CLI execution failed: {exc}"})

    def log(self, message: str) -> None:
        """Log message only if not in agent mode (AGENT_MODE != 1)."""
        if os.environ.get("AGENT_MODE") != "1":
            print(message)

    def execute(self, *args, **kwargs) -> str:
        """Main execution method. Subclasses must override this.

        Returns:
            JSON string result
        """
        raise NotImplementedError("Subclasses must implement execute()")


class DryRunMixin:
    """Mixin for scripts that support dry-run mode.

    Provides --dry-run / --real flag handling for state-changing operations.
    """

    def check_dry_run(self, args: list[str]) -> tuple[bool, list[str]]:
        """Check if --real flag is present, return (is_real, remaining_args).

        Args:
            args: Command line arguments

        Returns:
            Tuple of (is_real_mode, args_without_flags)
        """
        is_real = "--real" in args
        clean_args = [a for a in args if a != "--real"]
        return is_real, clean_args

    def dry_run_message(self, action: str, details: dict | None = None) -> str:
        """Generate dry-run preview message.

        Args:
            action: Description of what would be executed
            details: Optional dict of details to include

        Returns:
            JSON string with dry-run info
        """
        result = {
            "dry_run": True,
            "action": action,
            "message": f"[DRY-RUN] Would execute: {action}",
        }
        if details:
            result["details"] = details
        return json.dumps(result, indent=2)

    def real_mode_warning(self, action: str) -> str:
        """Generate real mode execution warning.

        Args:
            action: Description of what will be executed

        Returns:
            Warning message string
        """
        return (
            f"⚠️  EXECUTING IN REAL MODE\n"
            f"   This will {action.lower()}.\n"
            f"   Requires explicit human approval (SOC 2 CC6.8.3)."
        )
