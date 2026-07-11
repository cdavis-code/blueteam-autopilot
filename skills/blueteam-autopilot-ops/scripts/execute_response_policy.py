#!/usr/bin/env python3
"""Activate an automated response policy (state-changing).

Replaces execute-response-policy.sh with Python equivalent.
Usage: python execute_response_policy.py <policy_id> [--real]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript, DryRunMixin


class ExecuteResponsePolicyScript(BaseScript, DryRunMixin):
    """Execute response policy script."""

    def execute(self, policy_id: str, real: bool = False) -> str:
        """Activate an automated response policy.

        Args:
            policy_id: The policy ID to activate
            real: If True, execute for real; otherwise dry-run
        """
        if self.mode == "demo":
            if real:
                return json.dumps({
                    "status": "ok",
                    "policy_id": policy_id,
                    "message": "Policy activated (demo mode)",
                }, indent=2)
            return self.dry_run_message(
                f"Activate response policy {policy_id}",
                {"policy_id": policy_id}
            )

        # Real mode
        if not real:
            return self.dry_run_message(
                f"Activate response policy {policy_id}",
                {"policy_id": policy_id}
            )

        # Execute for real
        cmd = ["cloud-siem", "UpdateAutomateResponseConfigStatus", "--region", self.region,
               "--Id", policy_id, "--Status", "100"]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python execute_response_policy.py <policy_id> [--real]")
        sys.exit(1)

    policy_id = sys.argv[1]
    real = "--real" in sys.argv
    print(ExecuteResponsePolicyScript().execute(policy_id, real))
