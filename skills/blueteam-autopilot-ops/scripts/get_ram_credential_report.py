#!/usr/bin/env python3
"""Get RAM credential report.

Replaces get-ram-credential-report.sh with Python equivalent.
Usage: python get_ram_credential_report.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class GetRamCredentialReportScript(BaseScript):
    """Get RAM credential report script."""

    def execute(self) -> str:
        """Get RAM credential report."""
        if self.mode == "demo":
            return self.load_demo("ram_credential_report.json")

        # Real mode: generate credential report
        # Step 1: Request report generation
        result = self.run_aliyun(["ram", "generate-credential-report", "--region", self.region])
        data = json.loads(result)

        if "error" in data:
            return result

        # Step 2: Wait for report and get it
        import time
        for _ in range(10):
            time.sleep(2)
            result = self.run_aliyun(["ram", "get-credential-report", "--region", self.region])
            data = json.loads(result)
            if "error" not in data and data.get("Content"):
                return result

        return json.dumps({"error": "Timeout waiting for credential report"})


if __name__ == "__main__":
    print(GetRamCredentialReportScript().execute())
