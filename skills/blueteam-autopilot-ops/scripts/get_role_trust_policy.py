#!/usr/bin/env python3
"""Get role trust policy.

Replaces get-role-trust-policy.sh with Python equivalent.
Usage: python get_role_trust_policy.py <role_name>
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class GetRoleTrustPolicyScript(BaseScript):
    """Get role trust policy script."""

    def execute(self, role_name: str) -> str:
        """Get role trust policy.

        Args:
            role_name: The RAM role name
        """
        if self.mode == "demo":
            return self.load_demo("role_trust_policy.json")

        cmd = ["ram", "get-role", "--region", self.region, "--role-name", role_name]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get_role_trust_policy.py <role_name>")
        sys.exit(1)
    print(GetRoleTrustPolicyScript().execute(sys.argv[1]))
