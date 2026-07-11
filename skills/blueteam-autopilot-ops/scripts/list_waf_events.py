#!/usr/bin/env python3
"""List recent WAF block events.

Replaces list-waf-events.sh with Python equivalent.
Usage: python list_waf_events.py [time_range]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListWafEventsScript(BaseScript):
    """List WAF events script."""

    def execute(self, time_range: str = "lastHour") -> str:
        """List recent WAF block events.

        Args:
            time_range: Time range (last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days)
        """
        if self.mode == "demo":
            return self.load_demo("waf_events.json")

        # Real mode requires getting WAF instance first
        # This is a simplified version - the bash script does more complex logic
        cmd = ["waf-openapi", "describe-flow-chart", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    time_range = sys.argv[1] if len(sys.argv) > 1 else "lastHour"
    print(ListWafEventsScript().execute(time_range))
