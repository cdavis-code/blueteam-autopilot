#!/usr/bin/env python3
"""Verify SLS log delivery status.

Replaces verify-log-delivery.sh with Python equivalent.
Usage: python verify_log_delivery.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class VerifyLogDeliveryScript(BaseScript):
    """Verify log delivery script."""

    def execute(self) -> str:
        """Verify SLS log delivery status."""
        if self.mode == "demo":
            # Demo mode: return a sample response
            import json
            return json.dumps({
                "status": "ok",
                "log_delivery": "enabled",
                "project": "demo-security-log",
                "logstore": "security-events",
            }, indent=2)

        # Real mode: check SLS log delivery
        cmd = ["sas", "describe-log-meta", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    print(VerifyLogDeliveryScript().execute())
