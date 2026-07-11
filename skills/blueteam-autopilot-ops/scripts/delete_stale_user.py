#!/usr/bin/env python3
"""Delete stale RAM user (state-changing).

Replaces delete-stale-user.sh with Python equivalent.
Usage: python delete_stale_user.py <user_name> [--real]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript, DryRunMixin


class DeleteStaleUserScript(BaseScript, DryRunMixin):
    """Delete stale user script."""

    def execute(self, user_name: str, real: bool = False) -> str:
        """Delete stale RAM user.

        Args:
            user_name: The RAM user name to delete
            real: If True, execute for real; otherwise dry-run
        """
        if self.mode == "demo":
            if real:
                return json.dumps({
                    "status": "ok",
                    "user_name": user_name,
                    "message": "User deleted (demo mode)",
                }, indent=2)
            return self.dry_run_message(
                f"Delete stale user {user_name}",
                {"user_name": user_name}
            )

        # Real mode
        if not real:
            return self.dry_run_message(
                f"Delete stale user {user_name}",
                {"user_name": user_name}
            )

        # Execute for real
        cmd = ["ram", "delete-user", "--region", self.region, "--user-name", user_name]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python delete_stale_user.py <user_name> [--real]")
        sys.exit(1)

    user_name = sys.argv[1]
    real = "--real" in sys.argv
    print(DeleteStaleUserScript().execute(user_name, real))
