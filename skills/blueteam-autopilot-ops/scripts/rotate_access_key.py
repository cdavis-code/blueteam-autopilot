#!/usr/bin/env python3
"""Rotate RAM access key (state-changing).

Replaces rotate-access-key.sh with Python equivalent.
Usage: python rotate_access_key.py <user_name> <access_key_id> [--real]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript, DryRunMixin


class RotateAccessKeyScript(BaseScript, DryRunMixin):
    """Rotate access key script."""

    def execute(self, user_name: str, access_key_id: str, real: bool = False) -> str:
        """Rotate RAM access key.

        Args:
            user_name: The RAM user name
            access_key_id: The access key ID to rotate
            real: If True, execute for real; otherwise dry-run
        """
        if self.mode == "demo":
            if real:
                return json.dumps({
                    "status": "ok",
                    "user_name": user_name,
                    "old_key_id": access_key_id,
                    "new_key_id": "DEMO-AK-123456789",
                    "message": "Access key rotated (demo mode)",
                }, indent=2)
            return self.dry_run_message(
                f"Rotate access key for user {user_name}",
                {"user_name": user_name, "access_key_id": access_key_id}
            )

        # Real mode
        if not real:
            return self.dry_run_message(
                f"Rotate access key for user {user_name}",
                {"user_name": user_name, "access_key_id": access_key_id}
            )

        # Execute for real - disable old key, create new one
        # Step 1: Disable old key
        self.run_aliyun(["ram", "update-access-key", "--region", self.region,
                        "--user-name", user_name, "--user-access-key-id", access_key_id,
                        "--status", "Inactive"])

        # Step 2: Create new key
        result = self.run_aliyun(["ram", "create-access-key", "--region", self.region,
                                 "--user-name", user_name])
        return result


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python rotate_access_key.py <user_name> <access_key_id> [--real]")
        sys.exit(1)

    user_name = sys.argv[1]
    access_key_id = sys.argv[2]
    real = "--real" in sys.argv
    print(RotateAccessKeyScript().execute(user_name, access_key_id, real))
