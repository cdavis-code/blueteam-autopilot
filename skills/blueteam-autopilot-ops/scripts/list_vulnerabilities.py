#!/usr/bin/env python3
"""List open vulnerabilities.

Replaces list-vulnerabilities.sh with Python equivalent.
Usage: python list_vulnerabilities.py [severity] [asset_id] [vul_type]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListVulnerabilitiesScript(BaseScript):
    """List vulnerabilities script."""

    def execute(self, severity: str = "", asset_id: str = "", vul_type: str = "") -> str:
        """List open vulnerabilities.

        Args:
            severity: Filter by severity (asap, later, nntf)
            asset_id: Filter by specific asset UUID
            vul_type: Filter by vulnerability type (cve, sys, app, emergency, cmm)
        """
        if self.mode == "demo":
            return self.load_demo("vulnerabilities.json")

        cmd = ["sas", "describe-vul-list", "--region", self.region]
        if severity:
            cmd.extend(["--necessity", severity])
        if asset_id:
            cmd.extend(["--uuids", asset_id])
        if vul_type:
            cmd.extend(["--type", vul_type])
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    args = sys.argv[1:]
    severity = args[0] if len(args) > 0 else ""
    asset_id = args[1] if len(args) > 1 else ""
    vul_type = args[2] if len(args) > 2 else ""
    print(ListVulnerabilitiesScript().execute(severity, asset_id, vul_type))
