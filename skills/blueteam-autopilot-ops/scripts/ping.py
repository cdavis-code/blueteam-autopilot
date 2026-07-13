#!/usr/bin/env python3
"""Health check — verify CLI, credentials, and region configuration.

Replaces ping.sh with Python equivalent.
Usage: python ping.py

Security: This script reads the access KEY ID (not the secret) from env vars
or aliyun CLI config for diagnostic purposes only. The key ID is immediately
masked to show only first 4 and last 4 characters (e.g., 'LTAI****abcd').
No credential values are logged, stored, or transmitted. The access key secret
is NEVER read.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class PingScript(BaseScript):
    """Health check script."""

    def execute(self) -> str:
        """Run health check.

        In demo mode: return fixture data.
        In real mode: verify CLI, credentials, region, and API connectivity.
        """
        if self.mode == "demo":
            return self.load_demo("ping.json")

        # Real mode health check
        results = {
            "status": "ok",
            "mode": "real",
            "checks": {},
        }

        # Check 1: aliyun CLI installed
        try:
            result = subprocess.run(
                ["aliyun", "version"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            version = result.stdout.strip() if result.returncode == 0 else "unknown"
            results["checks"]["cli_installed"] = {
                "status": "ok",
                "version": version,
            }
        except (subprocess.TimeoutExpired, FileNotFoundError):
            results["checks"]["cli_installed"] = {
                "status": "error",
                "message": "aliyun CLI not found. Install from https://github.com/aliyun/aliyun-cli",
            }
            return json.dumps(results, indent=2)

        # Check 2: Credentials configured
        import os
        access_key_id = os.environ.get("ALIBABA_ACCESS_KEY_ID", "")
        if access_key_id:
            masked = f"{access_key_id[:4]}****{access_key_id[-4:]}"
            results["checks"]["credentials"] = {
                "status": "ok",
                "source": "environment",
                "key_id": masked,
            }
        else:
            # Check aliyun CLI config
            config_path = Path.home() / ".aliyun" / "config.json"
            if config_path.exists():
                try:
                    with open(config_path) as f:
                        config = json.load(f)
                    current = config.get("current", "")
                    for profile in config.get("profiles", []):
                        if profile.get("name") == current:
                            key_id = profile.get("access_key_id", "")
                            if key_id:
                                masked = f"{key_id[:4]}****{key_id[-4:]}"
                                results["checks"]["credentials"] = {
                                    "status": "ok",
                                    "source": "aliyun CLI config",
                                    "key_id": masked,
                                }
                                break
                except (json.JSONDecodeError, OSError):
                    pass

            if "credentials" not in results["checks"]:
                results["checks"]["credentials"] = {
                    "status": "error",
                    "message": "No credentials found. Run 'aliyun configure' or set ALIBABA_ACCESS_KEY_ID",
                }

        # Check 3: Region configured
        try:
            region = self.region
            results["checks"]["region"] = {
                "status": "ok",
                "region": region,
            }
        except RuntimeError as e:
            results["checks"]["region"] = {
                "status": "error",
                "message": str(e),
            }

        # Check 4: API connectivity
        try:
            result = self.run_aliyun(["sas", "describe-version-config", "--region", self.region])
            data = json.loads(result)
            if "error" not in data:
                version_config = data.get("VersionConfig", {})
                edition_code = version_config.get("Version", 0)
                edition_names = {
                    1: "Basic",
                    2: "Anti-virus",
                    3: "Advanced",
                    4: "Enterprise",
                    5: "Ultimate",
                }
                edition = edition_names.get(edition_code, f"Unknown (code: {edition_code})")
                results["checks"]["api_connectivity"] = {
                    "status": "ok",
                    "edition": edition,
                }
            else:
                results["checks"]["api_connectivity"] = {
                    "status": "warning",
                    "message": data.get("error", "API call failed"),
                }
        except Exception as e:
            results["checks"]["api_connectivity"] = {
                "status": "error",
                "message": str(e),
            }

        return json.dumps(results, indent=2)


if __name__ == "__main__":
    print(PingScript().execute())
