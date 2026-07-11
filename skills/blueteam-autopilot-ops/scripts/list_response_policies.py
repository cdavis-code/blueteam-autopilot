#!/usr/bin/env python3
"""List automated response policies.

Replaces list-response-policies.sh with Python equivalent.
Usage: python list_response_policies.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListResponsePoliciesScript(BaseScript):
    """List response policies script."""

    def execute(self) -> str:
        """List all automated response policies."""
        if self.mode == "demo":
            return self.load_demo("response_policies.json")

        cmd = ["cloud-siem", "ListAutomateResponseConfigs", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    print(ListResponsePoliciesScript().execute())
