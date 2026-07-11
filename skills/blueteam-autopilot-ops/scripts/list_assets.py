#!/usr/bin/env python3
"""List protected assets.

Replaces list-assets.sh with Python equivalent.
Usage: python list_assets.py [asset_type] [instance_id]
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ListAssetsScript(BaseScript):
    """List assets script."""

    def execute(self, asset_type: str = "", instance_id: str = "") -> str:
        """List protected assets.

        Args:
            asset_type: Filter by asset type (ecs, rds, slb, oss, etc.)
            instance_id: Filter by specific instance ID
        """
        if self.mode == "demo":
            return self.load_demo("assets.json")

        cmd = ["sas", "describe-cloud-center-status", "--region", self.region]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    args = sys.argv[1:]
    asset_type = args[0] if len(args) > 0 else ""
    instance_id = args[1] if len(args) > 1 else ""
    print(ListAssetsScript().execute(asset_type, instance_id))
