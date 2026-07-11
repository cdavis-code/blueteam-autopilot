#!/usr/bin/env python3
"""List RAM roles.

Replaces list-ram-roles.sh with Python equivalent.
Usage: python list_ram_roles.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListRamRolesScript(BaseScript):
    """List RAM roles script."""

    def execute(self) -> str:
        """List all RAM roles."""
        if self.mode == "demo":
            return self.load_demo("ram_roles.json")

        cmd = ["ram", "list-roles", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    print(ListRamRolesScript().execute())
