#!/usr/bin/env python3
"""Get full event detail: attack chain, attackers, CVEs, raw data.

Replaces get-event-detail.sh with Python equivalent.
Usage: python get_event_detail.py <event_id>
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class GetEventDetailScript(BaseScript):
    """Get event detail script."""

    def execute(self, event_id: str) -> str:
        """Get full event detail.

        Args:
            event_id: The security event ID
        """
        if self.mode == "demo":
            # Use specific fixture if available, otherwise generic
            fixture = f"event_detail_{event_id}.json"
            fixture_path = self.fixtures_dir / fixture
            if fixture_path.exists():
                return self.load_demo(fixture)
            return self.load_demo("event_detail.json")

        # Real mode
        cmd = ["sas", "describe-susp-event-detail", "--region", self.region, "--eventId", event_id]
        return self.run_aliyun(cmd)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python get_event_detail.py <event_id>")
        sys.exit(1)
    print(GetEventDetailScript().execute(sys.argv[1]))
