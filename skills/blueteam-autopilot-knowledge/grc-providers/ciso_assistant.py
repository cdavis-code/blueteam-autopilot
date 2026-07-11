#!/usr/bin/env python3
"""CISO Assistant Community — GRC Provider.

Integrates with the CISO Assistant Community GRC platform by intuitem.
GitHub: https://github.com/intuitem/ciso-assistant-community

API:
    POST /api/iam/login/         — Authenticate (returns token)
    GET  /api/stored-libraries/  — List built-in framework libraries
    GET  /api/loaded-libraries/  — List user-loaded libraries
    GET  /api/requirement-nodes/?library=<id>  — Get control nodes for a library

Auth: Authorization: Token <token> header
"""

from __future__ import annotations

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# Add parent dir for base class import
sys.path.insert(0, str(Path(__file__).parent))
from _base import BaseGRCProvider


# --- Demo fixture data ---
DEMO_FRAMEWORKS = [
    {
        "id": "demo-nist-csf-v2",
        "name": "NIST Cyber Security Framework (CSF) v2.0",
        "type": "compliance",
        "description": "NIST Cybersecurity Framework version 2.0 — Govern, Identify, Protect, Detect, Respond, Recover",
    },
    {
        "id": "demo-soc2",
        "name": "SOC2",
        "type": "compliance",
        "description": "SOC 2 Type II Trust Services Criteria — Security, Availability, Confidentiality, Privacy, Processing Integrity",
    },
    {
        "id": "demo-iso27001",
        "name": "ISO 27001:2022",
        "type": "compliance",
        "description": "ISO/IEC 27001:2022 Information Security Management System requirements",
    },
]

DEMO_FRAMEWORK_CONTENT_NIST = """---
document_id: nist-csf
version: "2026.1"
source: grc
grc_provider: ciso-assistant
framework: NIST CSF v2.0
library_id: demo-nist-csf-v2
sync_date: "2026-06-16"
---

# NIST Cybersecurity Framework (CSF) v2.0
## Source: CISO Assistant Community (demo mode)

### PR.PT-4: Network Bounding and Communications Protection
*   **Control Objective:** Manage communication and control networks to protect information systems.
*   **Category:** Protect — Platform Security (PR.PT)
*   **Alibaba Cloud Mapping:** All public endpoints must tunnel inbound traffic through Web Application Firewall instances configured in strict disruption (Block) mode.

### DE.AE-2: Detection of Anomalous Events and Impact Analysis
*   **Control Objective:** Detected events are analyzed to understand potential impact and attack vectors.
*   **Category:** Detect — Anomalies and Events (DE.AE)
*   **Requirement:** Security tooling must correlate independent telemetry signals to establish a comprehensive attack chain profile.

### RS.RP-1: Response Planning Implementation
*   **Control Objective:** Response processes and procedures are executed and maintained to ensure timely response to detected cybersecurity events.
*   **Category:** Respond — Response Planning (RS.RP)
*   **Requirement:** Mitigation strategies must balance operational availability against data risk. Perimeter containment via IP ACL adjustments is authorized for known-malicious behavior profiles.

> **Demo notice:** This content is fixture data for testing. Run with GRC_MODE=real against a live CISO Assistant instance for real framework data.
"""

DEMO_FRAMEWORK_CONTENT_SOC2 = """---
document_id: soc2-cc6
version: "2026.1"
source: grc
grc_provider: ciso-assistant
framework: SOC2
library_id: demo-soc2
sync_date: "2026-06-16"
---

# SOC 2 Type II — CC6 Logical Access Controls
## Source: CISO Assistant Community (demo mode)

### CC6.1: Boundary Protection and Perimeter Defense
*   **Control Objective:** The organization protects points of entry to the infrastructure containing customer data from unauthorized access.
*   **Trust Services Criterion:** CC6.0 — Logical and Physical Access Controls
*   **Requirement:** All public-facing web applications must be fronted by an active WAF capable of inspecting and blocking layer 7 malicious traffic. Perimeter defenses must log all blocked access attempts. Security team must review perimeter security anomalies at least daily.

### CC6.8: Unauthorized Activity Triage and Mitigation
*   **Control Objective:** The organization prevents, detects, and acts upon unauthorized logical access to infrastructure assets.
*   **Trust Services Criterion:** CC6.0 — Logical and Physical Access Controls
*   **Requirement:** Threat detection mechanisms must be continuously active across all production nodes. Automated blocking mechanisms must be initiated for verified attack patterns. Every automated mitigation action must be traceable to an authoritative system event log and authenticated by an explicit administrative validation window.

> **Demo notice:** This content is fixture data for testing. Run with GRC_MODE=real against a live CISO Assistant instance for real framework data.
"""


class CisoAssistantProvider(BaseGRCProvider):
    """CISO Assistant Community GRC provider."""

    PROVIDER_NAME = "ciso-assistant"
    DISPLAY_NAME = "CISO Assistant Community"
    DESCRIPTION = "Open-source GRC platform by intuitem. Supports 150+ frameworks."

    DEMO_FRAMEWORKS = DEMO_FRAMEWORKS

    def _http_request(self, method: str, url: str, headers: dict | None = None, data: dict | None = None) -> str:
        """Make an HTTP request and return the response body."""
        if headers is None:
            headers = {}
        headers.setdefault("Content-Type", "application/json")

        body = None
        if data is not None:
            body = json.dumps(data).encode("utf-8")

        req = urllib.request.Request(url, data=body, headers=headers, method=method)

        import ssl
        ctx = None
        if not self.verify_ssl:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

        try:
            with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
                return resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            return e.read().decode("utf-8")
        except Exception as e:
            print(f"HTTP error: {e}", file=sys.stderr)
            return ""

    def connect(self) -> bool:
        """Authenticate with CISO Assistant."""
        if self.mode == "demo":
            print(f"[demo] Simulating connection to {self.DISPLAY_NAME}...", file=sys.stderr)
            print(f"[demo] URL: {self.base_url}", file=sys.stderr)
            return True

        print(f"Connecting to CISO Assistant at {self.base_url}...", file=sys.stderr)

        # If we already have a token, test it
        if self.api_token:
            print("  Testing existing token...", file=sys.stderr)
            resp = self._http_request(
                "GET",
                f"{self.base_url}/api/build/",
                headers={"Authorization": f"Token {self.api_token}"},
            )
            if resp and "error" not in resp.lower():
                print("  Token is valid.", file=sys.stderr)
                return True
            print("  Token expired or invalid. Re-authenticating...", file=sys.stderr)

        # Authenticate with email + password
        if not self.email:
            print("ERROR: GRC_EMAIL is not set", file=sys.stderr)
            print("  Set GRC_EMAIL and GRC_PASSWORD environment variables, or run configure_policies.py", file=sys.stderr)
            return False

        password = __import__("os").environ.get("GRC_PASSWORD", "")
        print(f"  Authenticating as {self.email}...", file=sys.stderr)

        resp = self._http_request(
            "POST",
            f"{self.base_url}/api/iam/login/",
            data={"email": self.email, "password": password},
        )

        try:
            data = json.loads(resp)
            self.api_token = data.get("token", "")
        except (json.JSONDecodeError, TypeError):
            self.api_token = ""

        if not self.api_token:
            print(f"ERROR: Authentication failed", file=sys.stderr)
            print(f"  Response: {resp}", file=sys.stderr)
            return False

        print("  Authenticated successfully.", file=sys.stderr)
        return True

    def list_frameworks(self) -> list[dict]:
        """List available compliance frameworks."""
        if self.mode == "demo":
            return self.DEMO_FRAMEWORKS

        if not self.api_token:
            print("ERROR: Not authenticated. Call connect() first.", file=sys.stderr)
            return []

        # Fetch stored libraries (built-in frameworks)
        stored_resp = self._http_request(
            "GET",
            f"{self.base_url}/api/stored-libraries/",
            headers={"Authorization": f"Token {self.api_token}"},
        )

        # Fetch loaded libraries (user-loaded frameworks)
        loaded_resp = self._http_request(
            "GET",
            f"{self.base_url}/api/loaded-libraries/",
            headers={"Authorization": f"Token {self.api_token}"},
        )

        stored = []
        loaded = []
        try:
            data = json.loads(stored_resp)
            stored = data.get("results", data) if isinstance(data, dict) else data
            if not isinstance(stored, list):
                stored = []
        except (json.JSONDecodeError, TypeError):
            pass

        try:
            data = json.loads(loaded_resp)
            loaded = data.get("results", data) if isinstance(data, dict) else data
            if not isinstance(loaded, list):
                loaded = []
        except (json.JSONDecodeError, TypeError):
            pass

        frameworks = []
        for lib in stored + loaded:
            frameworks.append({
                "id": lib.get("id", ""),
                "name": lib.get("name", "Unknown"),
                "type": lib.get("framework_type", lib.get("type", "compliance")),
                "description": lib.get("description", "")[:120],
            })

        return frameworks

    def get_framework(self, library_id: str) -> str:
        """Export a framework's controls as Markdown."""
        if not library_id:
            print("ERROR: get_framework requires a library_id argument", file=sys.stderr)
            return ""

        if self.mode == "demo":
            if library_id == "demo-nist-csf-v2":
                return DEMO_FRAMEWORK_CONTENT_NIST
            elif library_id == "demo-soc2":
                return DEMO_FRAMEWORK_CONTENT_SOC2
            else:
                print(f"ERROR: Unknown demo library_id: {library_id}", file=sys.stderr)
                return ""

        if not self.api_token:
            print("ERROR: Not authenticated. Call connect() first.", file=sys.stderr)
            return ""

        # Fetch library metadata
        lib_resp = self._http_request(
            "GET",
            f"{self.base_url}/api/stored-libraries/{library_id}/",
            headers={"Authorization": f"Token {self.api_token}"},
        )

        try:
            lib_data = json.loads(lib_resp)
            lib_name = lib_data.get("name", "Unknown Framework")
            lib_desc = lib_data.get("description", "")
        except (json.JSONDecodeError, TypeError):
            lib_name = "Unknown Framework"
            lib_desc = ""

        # Fetch requirement nodes (handle pagination)
        all_requirements: list[dict] = []
        page_url = f"{self.base_url}/api/requirement-nodes/?library={library_id}"

        while page_url:
            page_resp = self._http_request(
                "GET",
                page_url,
                headers={"Authorization": f"Token {self.api_token}"},
            )
            try:
                page_data = json.loads(page_resp)
                all_requirements.extend(page_data.get("results", []))
                page_url = page_data.get("next", "")
            except (json.JSONDecodeError, TypeError):
                break

        # Transform to Markdown
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        doc_id = lib_name.lower().replace(" ", "-")
        doc_id = "".join(c for c in doc_id if c.isalnum() or c == "-")

        lines = [
            "---",
            f"document_id: {doc_id}",
            'version: "2026.1"',
            "source: grc",
            f"grc_provider: {self.PROVIDER_NAME}",
            f"framework: {lib_name}",
            f"library_id: {library_id}",
            f'sync_date: "{today}"',
            "---",
            "",
            f"# {lib_name}",
            "## Source: CISO Assistant Community",
            "",
        ]

        if lib_desc:
            lines.append(lib_desc)
            lines.append("")

        for req in all_requirements:
            ref_id = (req.get("ref_id", "") or req.get("display_short", "")).strip()
            name = req.get("name", "")
            description = req.get("description", "")

            if not ref_id and not name:
                continue

            heading = ref_id if ref_id else name
            lines.append(f"### {heading}")
            if name and ref_id:
                lines.append(f"*   **{name}**")
            if description:
                desc = description.replace("<p>", "").replace("</p>", "\n").replace("<br>", "\n").replace("<br/>", "\n")
                lines.append(f"*   {desc[:500]}")
            lines.append("")

        lines.append(f"> **Synced from CISO Assistant Community on {now}**")
        lines.append(f"> **Library ID:** {library_id}")

        return "\n".join(lines)


# Module-level alias for get_provider() discovery
provider_class = CisoAssistantProvider
