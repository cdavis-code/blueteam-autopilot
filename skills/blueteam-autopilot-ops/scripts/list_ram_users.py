#!/usr/bin/env python3
"""List RAM users.

Replaces list-ram-users.sh with Python equivalent.
Usage: python list_ram_users.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListRamUsersScript(BaseScript):
    """List RAM users script."""

    def execute(self) -> str:
        """List all RAM users."""
        if self.mode == "demo":
            return self.load_demo("ram_users.json")

        cmd = ["ram", "list-users", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    print(ListRamUsersScript().execute())
