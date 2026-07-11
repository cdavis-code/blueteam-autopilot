#!/usr/bin/env python3
"""Get WAF instance ID.

Replaces get-waf-instance.sh with Python equivalent.
Usage: python get_waf_instance.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class GetWafInstanceScript(BaseScript):
    """Get WAF instance script."""

    def execute(self) -> str:
        """Get WAF instance ID."""
        if self.mode == "demo":
            return self.load_demo("waf_instance.json")

        cmd = ["waf-openapi", "describe-instance", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    print(GetWafInstanceScript().execute())
