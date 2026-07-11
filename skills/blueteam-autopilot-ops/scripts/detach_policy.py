#!/usr/bin/env python3
"""Detach policy from RAM role (state-changing).

Replaces detach-policy.sh with Python equivalent.
Usage: python detach_policy.py <role_name> <policy_name> [--real]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript, DryRunMixin


class DetachPolicyScript(BaseScript, DryRunMixin):
    """Detach policy script."""

    def execute(self, role_name: str, policy_name: str, real: bool = False) -> str:
        """Detach policy from RAM role.

        Args:
            role_name: The RAM role name
            policy_name: The policy name to detach
            real: If True, execute for real; otherwise dry-run
        """
        if self.mode == "demo":
            if real:
                return json.dumps({
                    "status": "ok",
                    "role_name": role_name,
                    "policy_name": policy_name,
                    "message": "Policy detached (demo mode)",
                }, indent=2)
            return self.dry_run_message(
                f"Detach policy {policy_name} from role {role_name}",
                {"role_name": role_name, "policy_name": policy_name}
            )

        # Real mode
        if not real:
            return self.dry_run_message(
                f"Detach policy {policy_name} from role {role_name}",
                {"role_name": role_name, "policy_name": policy_name}
            )

        # Execute for real
        cmd = ["ram", "detach-policy-from-role", "--region", self.region,
               "--role-name", role_name, "--policy-name", policy_name, "--policy-type", "System"]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python detach_policy.py <role_name> <policy_name> [--real]")
        sys.exit(1)

    role_name = sys.argv[1]
    policy_name = sys.argv[2]
    real = "--real" in sys.argv
    print(DetachPolicyScript().execute(role_name, policy_name, real))
