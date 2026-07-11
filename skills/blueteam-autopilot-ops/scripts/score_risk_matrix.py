#!/usr/bin/env python3
"""Score risk matrix from events and vulnerabilities.

Replaces score-risk-matrix.sh with Python equivalent.
Usage: python score_risk_matrix.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class ScoreRiskMatrixScript(BaseScript):
    """Score risk matrix script."""

    def execute(self) -> str:
        """Score risk matrix from events and vulnerabilities."""
        if self.mode == "demo":
            return self.load_demo("risk_matrix.json")

        # Real mode: complex multi-step risk scoring
        # Step 1: Get recent events
        events_result = self.run_aliyun(["sas", "describe-susp-events", "--region", self.region,
                                        "--time-range", "last24Hours"])
        events_data = json.loads(events_result)

        if "error" in events_data:
            events = []
        else:
            events = events_data.get("SuspEvents", [])

        # Step 2: Get vulnerabilities
        vulns_result = self.run_aliyun(["sas", "describe-vul-list", "--region", self.region])
        vulns_data = json.loads(vulns_result)

        if "error" in vulns_data:
            vulns = []
        else:
            vulns = vulns_data.get("VulRecords", [])

        # Step 3: Calculate risk scores
        severity_weights = {"CRITICAL": 10, "HIGH": 7, "MEDIUM": 4, "LOW": 1}

        event_score = sum(severity_weights.get(e.get("Level", "LOW"), 1) for e in events)
        vuln_score = sum(severity_weights.get(v.get("Necessity", "LOW"), 1) for v in vulns)

        total_score = event_score + vuln_score

        if total_score >= 50:
            risk_level = "CRITICAL"
        elif total_score >= 30:
            risk_level = "HIGH"
        elif total_score >= 15:
            risk_level = "MEDIUM"
        else:
            risk_level = "LOW"

        return json.dumps({
            "risk_level": risk_level,
            "total_score": total_score,
            "event_score": event_score,
            "vuln_score": vuln_score,
            "event_count": len(events),
            "vuln_count": len(vulns),
        }, indent=2)


if __name__ == "__main__":
    print(ScoreRiskMatrixScript().execute())
