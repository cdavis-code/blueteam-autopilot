#!/usr/bin/env python3
"""List top triggered rules (WAF).

Replaces list-waf-top-rules.sh with Python equivalent.
Usage: python list_waf_top_rules.py [time_range]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListWafTopRulesScript(BaseScript):
    """List WAF top rules script."""

    def execute(self, time_range: str = "lastHour") -> str:
        """List top triggered rules.

        Args:
            time_range: Time range (last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days)
        """
        if self.mode == "demo":
            return self.load_demo("waf_top_rules.json")

        cmd = ["waf-openapi", "describe-flow-top-rule", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    time_range = sys.argv[1] if len(sys.argv) > 1 else "lastHour"
    print(ListWafTopRulesScript().execute(time_range))
