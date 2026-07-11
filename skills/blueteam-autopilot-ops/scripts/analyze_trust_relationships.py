#!/usr/bin/env python3
"""Analyze RAM role trust relationships for overprivileged access.

Replaces analyze-trust-relationships.sh with Python equivalent.
Usage: python analyze_trust_relationships.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from _base import BaseScript


class AnalyzeTrustRelationshipsScript(BaseScript):
    """Analyze trust relationships script."""

    def execute(self) -> str:
        """Analyze RAM role trust relationships for overprivileged access."""
        if self.mode == "demo":
            return self.load_demo("trust_analysis.json")

        # Real mode: complex multi-step analysis
        # Step 1: Get all roles
        roles_result = self.run_aliyun(["ram", "list-roles", "--region", self.region])
        roles_data = json.loads(roles_result)

        if "error" in roles_data:
            return roles_result

        roles = roles_data.get("Roles", {}).get("Role", [])
        analysis = []

        # Step 2: Analyze each role's trust policy
        for role in roles:
            role_name = role.get("RoleName", "")
            trust_policy_str = role.get("AssumeRolePolicyDocument", "{}")

            try:
                trust_policy = json.loads(trust_policy_str)
            except json.JSONDecodeError:
                trust_policy = {}

            # Check for overly permissive trust
            findings = []
            statements = trust_policy.get("Statement", [])

            for stmt in statements:
                principal = stmt.get("Principal", {})
                service = principal.get("Service", "")
                ram = principal.get("RAM", "")

                # Check for wildcard principals
                if principal.get("*") or ram == "*":
                    findings.append({
                        "severity": "HIGH",
                        "issue": "Wildcard principal allows any entity to assume role",
                        "principal": str(principal),
                    })

                # Check for overly broad service trust
                if service and "*" in service:
                    findings.append({
                        "severity": "MEDIUM",
                        "issue": "Broad service trust policy",
                        "service": service,
                    })

            analysis.append({
                "role_name": role_name,
                "findings": findings,
                "risk_level": "HIGH" if any(f["severity"] == "HIGH" for f in findings) else "LOW",
            })

        return json.dumps({"roles_analyzed": len(roles), "analysis": analysis}, indent=2)


if __name__ == "__main__":
    print(AnalyzeTrustRelationshipsScript().execute())
