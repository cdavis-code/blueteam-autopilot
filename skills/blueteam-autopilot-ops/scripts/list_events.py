#!/usr/bin/env python3
"""List Security Center Agentic SOC events.

Replaces list-events.sh with Python equivalent.
Usage: python list_events.py [time_range] [severity]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListEventsScript(BaseScript):
    """List security events script."""

    def execute(self, time_range: str = "lastHour", severity: str = "") -> str:
        """List security events.

        Args:
            time_range: Time range shortcut (last15Min, lastHour, last4Hours, last24Hours, last7Days, last30Days)
            severity: Filter by severity (CRITICAL, HIGH, MEDIUM, LOW)
        """
        if self.mode == "demo":
            return self.load_demo("events_recent.json")

        # Real mode
        cmd = ["sas", "describe-susp-events", "--region", self.region, "--time-range", time_range]
        if severity:
            cmd.extend(["--severity", severity])

        return self.run_aliyun(cmd)


if __name__ == "__main__":
    args = sys.argv[1:]
    time_range = args[0] if len(args) > 0 else "lastHour"
    severity = args[1] if len(args) > 1 else ""
    print(ListEventsScript().execute(time_range, severity))
