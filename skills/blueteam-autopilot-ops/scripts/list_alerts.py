#!/usr/bin/env python3
"""List active security alerts.

Replaces list-alerts.sh with Python equivalent.
Usage: python list_alerts.py [severity]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListAlertsScript(BaseScript):
    """List alerts script."""

    def execute(self, severity: str = "") -> str:
        """List security alerts.

        Args:
            severity: Filter by severity (CRITICAL, HIGH, MEDIUM, LOW)
        """
        if self.mode == "demo":
            return self.load_demo("alerts.json")

        cmd = ["sas", "describe-alerts", "--region", self.region]
        if severity:
            cmd.extend(["--severity", severity])
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    severity = sys.argv[1] if len(sys.argv) > 1 else ""
    print(ListAlertsScript().execute(severity))
