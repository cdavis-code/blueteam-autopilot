# MCP Tools Reference

Complete catalog of available MCP tools for BlueTeam Autopilot.

---

## Time Range Shortcuts

All time-based tools accept these `timeRange` values:

| Shortcut | Duration | Use Case |
|----------|----------|----------|
| `last15Min` | 15 minutes | Real-time monitoring |
| `lastHour` | 1 hour | Default triage window |
| `last4Hours` | 4 hours | Short-term investigation |
| `last24Hours` | 24 hours | Daily review |
| `last7Days` | 7 days | Weekly analysis |
| `last30Days` | 30 days | Monthly trend analysis |
| `custom` | Variable | Forensic deep-dive (requires `startIso`/`endIso`) |

**Always use the same time range shortcut across all tools in a single investigation** to maintain coherent data windows.

---

## Core Tools

### `ping`

**Purpose:** Health check — returns server status, region, mode

**Parameters:** None

**Returns:**
```json
{
  "status": "ok",
  "region": "ap-southeast-1",
  "mode": "dry-run"
}
```

**Usage:**
```
Call at session start to verify connectivity and establish execution context.
```

---

### `get_account_context`

**Purpose:** Region, Security Center edition, Agentic SOC status

**Parameters:** None

**Returns:**
```json
{
  "region": "ap-southeast-1",
  "edition": "Enterprise",
  "editionCode": 4,
  "agenticSocEnabled": true,
  "mode": "dry-run"
}
```

**Usage:**
```
Call first in Incident Discovery (Behavior 1) to establish region and mode awareness.
```

---

### `list_security_events`

**Purpose:** List Agentic SOC events

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `timeRange` | string | No | Time range shortcut (default: `lastHour`) |
| `severity` | string | No | Filter by severity: CRITICAL, HIGH, MEDIUM, LOW |
| `status` | string | No | Filter by status: open, closed, ignored |

**Returns:** Array of security events with eventId, title, severity, affectedAssets, createdAt

**Usage:**
```
Primary event discovery tool. Sort results by severity (CRITICAL > HIGH > MEDIUM > LOW).
Cross-reference affectedAssets against live asset list from list_assets.

CLI Alternative: ../blueteam-autopilot-ops/scripts/list-events.sh [time_range] [severity]
```

---

### `get_security_event_detail`

**Purpose:** Full event detail: attack chain, attackers, CVEs, raw data

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventId` | string | Yes | Security Center event ID |

**Returns:**
```json
{
  "eventId": "evt-xxx",
  "title": "SQL Injection Attack",
  "severity": "HIGH",
  "attackChain": [...],
  "sourceProduct": "WAF",
  "attackerIps": ["1.2.3.4"],
  "relatedAlerts": [...],
  "cves": ["CVE-2024-1234"],
  "affectedAssets": ["i-xxx"]
}
```

**Usage:**
```
Call in Incident Deep-Dive (Behavior 2) for each selected event.
Extract attack chain stages, source IPs, exploit vectors.

CLI Alternative: ../blueteam-autopilot-ops/scripts/get-event-detail.sh <event_id>
```

---

### `list_alerts_for_event`

**Purpose:** Underlying alerts grouped by source (WAF, CWPP, etc.)

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `eventId` | string | Yes | Security Center event ID |

**Returns:** Array of alerts grouped by dataSource (WAF, CWPP, CloudFirewall, etc.)

**Usage:**
```
Call after get_security_event_detail to see underlying alert breakdown.
Use to correlate multiple signals per NIST CSF DE.AE-2.
```

---

### `list_vulnerabilities`

**Purpose:** Security Center vulnerabilities

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `severity` | string | No | Filter by severity: CRITICAL, HIGH, MEDIUM, LOW |
| `type` | string | No | Filter by type: system, application, emergency |
| `assetId` | string | No | Filter by asset ID |

**Returns:** Array of vulnerabilities with vulId, name, severity, cveId, assetId

**Usage:**
```
Call in Recommendation Synthesis (Behavior 3) for vulnerability-driven incidents.
Prioritize by severity and asset criticality.
```

---

### `get_vulnerability_detail`

**Purpose:** Deep vuln info: CVE, description, fix suggestion

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `vulnId` | string | Yes | Vulnerability ID |

**Returns:**
```json
{
  "vulnId": "vuln-xxx",
  "name": "OpenSSL Buffer Overflow",
  "severity": "CRITICAL",
  "cveId": "CVE-2024-5678",
  "description": "...",
  "fixSuggestion": "Upgrade to OpenSSL 3.0.12",
  "affectedAsset": "i-xxx"
}
```

**Usage:**
```
Call after list_vulnerabilities to get remediation details for prioritized vulns.
```

---

## Response Policy Tools

### `list_response_policies`

**Purpose:** Agentic SOC response/automation policies

**Parameters:** None

**Returns:** Array of policies with policyId, name, description, status, actions

**Usage:**
```
Call in Recommendation Synthesis (Behavior 3) to find matching policies.
Match incident profile to policy:
- WAF attacks → IP blocking policies
- Host threats → isolation policies
```

---

### `execute_response_policy`

**Purpose:** Execute a policy (supports dry-run simulation)

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `policyId` | string | Yes | Response policy ID |
| `dryRun` | boolean | No | Simulate execution (default: true) |
| `eventId` | string | No | Associated event ID |

**Returns:**
```json
{
  "success": true,
  "dryRun": true,
  "effects": ["IP 1.2.3.4 would be blocked for 24h"],
  "message": "Policy execution simulated (dry-run mode)"
}
```

**CRITICAL:** 
- **NEVER** call without explicit human approval (SOC 2 CC6.8.3 mandate)
- Always default to `dryRun: true` unless user explicitly opts into real execution
- Include rollback plan in action proposal before execution

---

## WAF Tools

### `get_waf_instance_info`

**Purpose:** Discover WAF instance in the configured region

**Parameters:** None

**Returns:**
```json
{
  "instanceId": "waf_v2intl_public_intl-sg-xxx",
  "edition": "Enterprise",
  "region": "ap-southeast-1",
  "status": "active"
}
```

**Usage:**
```
Call before WAF-specific operations to discover instance ID.
Required for list_waf_security_events and other WAF tools.
```

---

### `list_waf_security_events`

**Purpose:** WAF attack logs with time-range shortcuts

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `timeRange` | string | No | Time range shortcut (default: `lastHour`) |
| `attackType` | string | No | Filter by attack type: sqli, xss, lfi, scanner_behavior |

**Returns:** Array of WAF events with timestamp, sourceIp, attackType, url, action

**Usage:**
```
Call to correlate WAF logs with Security Center events.
Use same timeRange as list_security_events for coherent window.

CLI Alternative: ../blueteam-autopilot-ops/scripts/list-waf-events.sh [time_range] [attack_type]
```

---

### `list_waf_top_rules`

**Purpose:** Top 10 most triggered WAF rules

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `timeRange` | string | No | Time range shortcut (default: `lastHour`) |

**Returns:** Array of rules with ruleId, ruleName, hitCount, attackType

**Usage:**
```
Call to identify most common attack patterns in the time window.
Useful for trend analysis and security posture assessment.
```

---

### `list_waf_top_ips`

**Purpose:** Top 10 attacker IPs by WAF hit count

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `timeRange` | string | No | Time range shortcut (default: `lastHour`) |

**Returns:** Array of IPs with sourceIp, hitCount, attackTypes, geoLocation

**Usage:**
```
Call to identify most active attackers.
Cross-reference against trusted networks before proposing blocks.
```

---

## Asset & Knowledge Tools

### `list_assets`

**Purpose:** List cloud assets (ECS instances) registered in Security Center

**Parameters:** None

**Returns:** Array of assets with assetId, name, ip, region, type, tags

**Usage:**
```
Call at start of Incident Discovery (Behavior 1) to build live asset context.
Cross-reference event affectedAssets against this list.
Assets tagged SOC 2 scope or sensitive workloads → minimum HIGH severity.
```

---

### `list_knowledge_documents`

**Purpose:** List all available knowledge documents

**Parameters:** None

**Returns:** Array of documents with type, title, source

**Usage:**
```
Call to discover available knowledge document types before fetching.
Document types: compliance_nist, compliance_soc2, runbook_waf_triage,
policy_change_mgmt, trusted_networks, asset_inventory
```

---

### `get_knowledge_document`

**Purpose:** Fetch a specific knowledge document by type

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `type` | string | Yes | Document type (see list_knowledge_documents) |

**Returns:** Full document content as Markdown

**Usage:**
```
Call ONLY when explicitly needed (see Knowledge Fetching Policy in SKILL.md).
Do NOT call for every security event.

Available types:
- compliance_nist: Full NIST CSF controls
- compliance_soc2: Full SOC 2 CC6 controls
- runbook_waf_triage: RUN-SEC-042 full procedure
- policy_change_mgmt: Change Management Policy
- trusted_networks: Corporate VPN + monitoring IPs
- asset_inventory: Asset topology reference

CLI Alternative: ../blueteam-autopilot-knowledge/scripts/fetch-knowledge.sh <type>
```
