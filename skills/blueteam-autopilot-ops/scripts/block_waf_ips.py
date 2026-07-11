#!/usr/bin/env python3
"""Block IPs via WAF (state-changing).

Replaces block-waf-ips.sh with Python equivalent.
Usage: python block_waf_ips.py <ip_list> [--real]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript, DryRunMixin


class BlockWafIpsScript(BaseScript, DryRunMixin):
    """Block WAF IPs script."""

    def execute(self, ip_list: str, real: bool = False) -> str:
        """Block IPs via WAF.

        Args:
            ip_list: Comma-separated list of IPs to block
            real: If True, execute for real; otherwise dry-run
        """
        ips = [ip.strip() for ip in ip_list.split(",") if ip.strip()]

        if self.mode == "demo":
            if real:
                return json.dumps({
                    "status": "ok",
                    "blocked_ips": ips,
                    "message": f"Blocked {len(ips)} IPs (demo mode)",
                }, indent=2)
            return self.dry_run_message(
                f"Block {len(ips)} IPs via WAF",
                {"ips": ips}
            )

        # Real mode
        if not real:
            return self.dry_run_message(
                f"Block {len(ips)} IPs via WAF",
                {"ips": ips}
            )

        # Execute for real
        cmd = ["waf-openapi", "create-instance", "--region", self.region,
               "--ip-list", ",".join(ips)]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python block_waf_ips.py <ip_list> [--real]")
        sys.exit(1)

    ip_list = sys.argv[1]
    real = "--real" in sys.argv
    print(BlockWafIpsScript().execute(ip_list, real))
