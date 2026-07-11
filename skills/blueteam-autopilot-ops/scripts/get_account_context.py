#!/usr/bin/env python3
"""Get account context: edition, quota, expiry, enabled features.

Replaces get-account-context.sh with Python equivalent.
Usage: python get_account_context.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class GetAccountContextScript(BaseScript):
    """Get account context script."""

    def execute(self) -> str:
        """Get account context."""
        if self.mode == "demo":
            return self.load_demo("account_context.json")

        cmd = ["sas", "describe-version-config", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    print(GetAccountContextScript().execute())
