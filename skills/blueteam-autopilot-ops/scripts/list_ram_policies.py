#!/usr/bin/env python3
"""List RAM policies.

Replaces list-ram-policies.sh with Python equivalent.
Usage: python list_ram_policies.py [policy_type]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListRamPoliciesScript(BaseScript):
    """List RAM policies script."""

    def execute(self, policy_type: str = "") -> str:
        """List RAM policies.

        Args:
            policy_type: Filter by type (System or Custom)
        """
        if self.mode == "demo":
            return self.load_demo("ram_policies.json")

        cmd = ["ram", "list-policies", "--region", self.region]
        if policy_type:
            cmd.extend(["--policy-type", policy_type])
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    policy_type = sys.argv[1] if len(sys.argv) > 1 else ""
    print(ListRamPoliciesScript().execute(policy_type))
