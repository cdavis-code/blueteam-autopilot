#!/usr/bin/env python3
"""List policies attached to a RAM role.

Replaces list-attached-policies.sh with Python equivalent.
Usage: python list_attached_policies.py <role_name>
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListAttachedPoliciesScript(BaseScript):
    """List attached policies script."""

    def execute(self, role_name: str) -> str:
        """List policies attached to a RAM role.

        Args:
            role_name: The RAM role name
        """
        if self.mode == "demo":
            return self.load_demo("attached_policies.json")

        cmd = ["ram", "list-policies-for-role", "--region", self.region, "--role-name", role_name]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python list_attached_policies.py <role_name>")
        sys.exit(1)
    print(ListAttachedPoliciesScript().execute(sys.argv[1]))
