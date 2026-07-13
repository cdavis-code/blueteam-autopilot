---
name: blueteam-autopilot-ops
description: >
  Operational CLI workflows for Alibaba Cloud Security Center and WAF.
  Use when executing security event queries, deep-dive investigations,
  asset discovery, vulnerability scanning, WAF analytics, response policy
  management, knowledge retrieval, or verifying log delivery via aliyun CLI.
allowed-tools:
  - Bash
---

# BlueTeam - Operations

Operational CLI workflows wrapping `aliyun` commands for Security Center, WAF, and SecOps knowledge.

## Prerequisites

1. **aliyun CLI installed:** Verify with `aliyun version`
2. **Credentials configured:** Run `aliyun configure` to store your AccessKey
   credentials. They are kept in `~/.aliyun/config.json` (never in the repo) and
   scripts pick them up automatically.
   > Region is auto-discovered from your `aliyun configure` profile. Set the `ALIBABA_REGION` shell/env variable only to override it for a command; it is not stored in `.env`.
3. **Security Center edition:** Agentic SOC features require Enterprise (4) or Ultimate (5)
   - Check edition: `aliyun sas describe-version-config --region "$ALIBABA_REGION"`

---

## Mode Selection

**Demo mode is the default.** All scripts read from `../blueteam-autopilot-core/fixtures/*.json` instead of calling `aliyun` CLI. No `.env` file or credentials required.

To switch to real mode with live Alibaba Cloud API calls:

1. Store your AccessKey credentials with `aliyun configure` (written to
   `~/.aliyun/config.json`, never committed to the repo).
2. Enable real mode in `.env`:

```bash
cat > .env << 'EOF'
SECURITY_CENTER_MODE=real
EOF
```

Or export directly for temporary overrides:
```bash
export SECURITY_CENTER_MODE=real
```

When `.env` contains `SECURITY_CENTER_MODE=real`, all scripts call live `aliyun` CLI APIs instead of reading fixtures.

---

## CLI ↔ MCP Coverage Matrix

Every MCP tool has a CLI fallback. Use these scripts when the MCP server is unavailable or when direct CLI access is preferred.

| # | MCP Tool | CLI Script | Demo Fixture | Alibaba API | Category |
|---|----------|------------|-------------|-------------|----------|
| 1 | `ping` | `ping.py` | `../blueteam-autopilot-core/fixtures/ping.json` | `aliyun version` + credential check | Health |
| 2 | `get_account_context` | `get_account_context.py` | `../blueteam-autopilot-core/fixtures/account_context.json` | `sas describe-version-config` | Context |
| 3 | `list_security_events` | `list_events.py` | `../blueteam-autopilot-core/fixtures/events_recent.json` | `sas describe-susp-events` | Events |
| 4 | `get_security_event_detail` | `get_event_detail.py` | `../blueteam-autopilot-core/fixtures/event_detail.json` | `sas describe-susp-event-detail` | Events |
| 5 | `list_alerts_for_event` | `list_alerts.py` | `../blueteam-autopilot-core/fixtures/alerts.json` | `sas describe-susp-event-detail` (extract AlertList) | Events |
| 6 | `list_vulnerabilities` | `list_vulnerabilities.py` | `../blueteam-autopilot-core/fixtures/vulnerabilities.json` | `sas describe-vul-list` | Vulnerabilities |
| 7 | `get_vulnerability_detail` | `get_vulnerability_detail.py` | `../blueteam-autopilot-core/fixtures/vulnerability_detail.json` | `sas describe-vul-details` | Vulnerabilities |
| 8 | `list_response_policies` | `list_response_policies.py` | `../blueteam-autopilot-core/fixtures/response_policies.json` | `cloud-siem ListAutomateResponseConfigs` | Response |
| 9 | `execute_response_policy` | `execute_response_policy.py` | `../blueteam-autopilot-core/fixtures/response_policies.json` (simulated) | `cloud-siem UpdateAutomateResponseConfigStatus` | Response |
| 10 | `get_waf_instance_info` | `get_waf_instance.py` | `../blueteam-autopilot-core/fixtures/waf_instance.json` | `waf-openapi describe-instance` | WAF |
| 11 | `list_waf_security_events` | `list_waf_events.py` | `../blueteam-autopilot-core/fixtures/waf_events.json` | `sls GetLogs` (WAF logstore) | WAF |
| 12 | `list_waf_top_rules` | `list_waf_top_rules.py` | `../blueteam-autopilot-core/fixtures/waf_top_rules.json` | `waf-openapi describe-rule-hits-top-rule-id` | WAF |
| 13 | `list_waf_top_ips` | `list_waf_top_ips.py` | `../blueteam-autopilot-core/fixtures/waf_top_ips.json` | `waf-openapi describe-rule-hits-top-client-ip` | WAF |
| 14 | `list_assets` | `list_assets.py` | `../blueteam-autopilot-core/fixtures/assets.json` | `sas describe-cloud-center-instances` | Assets |
| 15 | `list_knowledge_documents` | `list_knowledge.py` | `../blueteam-autopilot-core/fixtures/knowledge_list.json` | Local file discovery (no API) | Knowledge |
| 16 | `get_knowledge_document` | `get_knowledge.py` | No fixture needed — reads local markdown files | Local file read (no API) | Knowledge |

**Utility script** (not an MCP tool but used by behaviors):

| Script | Purpose | Alibaba API |
|--------|---------|-------------|
| `verify_log_delivery.py` | Verify SLS log delivery | `sls GetProject`, `sls ListLogStores`, `sls GetLogs` |

---

## Script Catalog

### Health & Context

| Script | Purpose | Usage |
|--------|---------|-------|
| `ping.py` | Health check — CLI, credentials, region, API connectivity | `python ping.py` |
| `get_account_context.py` | Region, Security Center edition, Agentic SOC status | `python get_account_context.py` |

### Security Events

| Script | Purpose | Usage |
|--------|---------|-------|
| `list_events.py` | List Security Center events | `python list_events.py [time_range] [severity]` |
| `get_event_detail.py` | Event deep-dive with attack chain | `python get_event_detail.py <event_id>` |
| `list_alerts.py` | Alerts grouped by source (WAF, CWPP, etc.) | `python list_alerts.py <event_id>` |

### Vulnerabilities

| Script | Purpose | Usage |
|--------|---------|-------|
| `list_vulnerabilities.py` | List detected vulnerabilities | `python list_vulnerabilities.py [severity] [asset_id] [vul_type] [page]` |
| `get_vulnerability_detail.py` | Deep vuln info: CVE, description, fix | `python get_vulnerability_detail.py <vul_id>` |

### Response Policies

> **Note:** Response policy APIs use `cloud-siem` product (API version `2022-06-16`) and require **Security Center Enterprise edition or higher**. On Basic/Standard editions, these commands will return `InvalidAction.NotFound`.

| Script | Purpose | Usage |
|--------|---------|-------|
| `list_response_policies.py` | List Agentic SOC response policies | `python list_response_policies.py [scope]` |
| `execute_response_policy.py` | Enable policy (dry-run by default) | `python execute_response_policy.py <policy_id> [event_id] [--real]` |

### WAF (Web Application Firewall)

| Script | Purpose | Usage |
|--------|---------|-------|
| `get_waf_instance.py` | Discover WAF instance in region | `python get_waf_instance.py` |
| `list_waf_events.py` | WAF attack logs from SLS | `python list_waf_events.py [time_range] [attack_type]` |
| `list_waf_top_rules.py` | Top 10 most triggered WAF rules | `python list_waf_top_rules.py [time_range]` |
| `list_waf_top_ips.py` | Top 10 attacker IPs by hit count | `python list_waf_top_ips.py [time_range]` |
| `verify_log_delivery.py` | Verify SLS log delivery | `python verify_log_delivery.py` |

### Assets

| Script | Purpose | Usage |
|--------|---------|-------|
| `list_assets.py` | List cloud assets (ECS) in Security Center | `python list_assets.py [criteria] [page]` |

### Knowledge

| Script | Purpose | Usage |
|--------|---------|-------|
| `list_knowledge.py` | List all available knowledge documents | `python list_knowledge.py` |
| `get_knowledge.py` | Fetch a specific knowledge document | `python get_knowledge.py <document_type>` |

---

### Time Range Options

All scripts accepting time ranges support:
- `last15Min`, `lastHour`, `last4Hours`, `last24Hours`, `last7Days`, `last30Days`
- Default: `lastHour` (events) / `last7Days` (WAF analytics)

### Severity Options

- `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`
- Default: all severities

### Knowledge Document Types

| Type | Content |
|------|---------|
| `asset_inventory` | Network topology, asset classification |
| `trusted_networks` | IP whitelist, escalation rules |
| `compliance_nist` | NIST CSF Detect & Respond controls |
| `compliance_soc2` | SOC 2 CC6.0 Logical Access Controls |
| `runbook_waf_triage` | WAF perimeter threat triage (RUN-SEC-042) |
| `policy_change_mgmt` | Change management guidelines |

---

## API Naming Conventions

**CRITICAL:** Alibaba Cloud CLI requires **lowercase API names with hyphens**, different from Dart SDK's PascalCase.

| CLI (lowercase with hyphens) | Dart SDK (PascalCase) |
|------------------------------|----------------------|
| `describe-susp-events` | `DescribeAlarmEventList` |
| `describe-susp-event-detail` | `DescribeSuspEventDetail` |
| `describe-version-config` | `DescribeVersionConfig` |
| `describe-cloud-center-instances` | `DescribeCloudCenterInstances` |
| `describe-vul-list` | `DescribeVulList` |
| `describe-vul-details` | `DescribeVulDetails` |
| `describe-instance` (WAF) | `DescribeInstance` |
| `describe-rule-hits-top-rule-id` | `DescribeRuleHitsTopRuleId` |
| `describe-rule-hits-top-client-ip` | `DescribeRuleHitsTopClientIp` |

For complete naming conventions, see [references/api-naming.md](references/api-naming.md).

---

## Security Center Edition Limitations

| Edition | Code | Agentic SOC | Event Listing API | Workaround |
|---------|------|-------------|-------------------|------------|
| Basic | 1 | ❌ | ❌ (timeout) | Use SLS direct queries |
| Anti-virus | 2 | ❌ | Limited | Use SLS direct queries |
| Advanced | 3 | ❌ | Limited | Use SLS direct queries |
| Enterprise | 4 | ✅ | ✅ Full access | N/A |
| Ultimate | 5 | ✅ | ✅ Full access | N/A |

**If scripts timeout or return 403:** Your account may be on Basic/Advanced edition.
See [references/edition-limits.md](references/edition-limits.md) for workarounds.

---

## Error Handling

### Common Errors

| Error | Cause | Remedy |
|-------|-------|--------|
| `aliyun: command not found` | CLI not installed | `brew install aliyun-cli` (macOS) |
| `InvalidAccessKeyId.NotFound` | Wrong AccessKey ID | Re-run `aliyun configure`, or regenerate the key in the RAM Console |
| `SignatureDoesNotMatch` | Wrong AccessKey Secret | Copy secret again, no trailing whitespace |
| `Forbidden.RAM` | Missing RAM policy | Attach `AliyunYundunSASReadOnlyAccess` policy |
| `Could not determine region automatically` | No `aliyun configure` profile | Run `aliyun configure` to set a default region |
| API timeout (10s) | Basic edition limitation | Use SLS direct queries or upgrade edition |
| `describe-susp-events: command not found` | Wrong API name format | Use lowercase with hyphens, not PascalCase |
| Document not found | Knowledge dir not configured | Set `KNOWLEDGE_DIR` or check directory paths |

### JSON Parsing

All scripts pipe output through `python3 -m json.tool` or inline Python for formatting. If JSON parsing fails:
1. Check API returned actual data (not error message)
2. Verify credentials are valid
3. Check Security Center edition supports the API

---

## Integration with Core Skill

These scripts are called from [blueteam-autopilot-core](../blueteam-autopilot-core/) behaviors:

- **Behavior 1 (Discovery):** `list_events.py`, `list_assets.py`
- **Behavior 2 (Deep-Dive):** `get_event_detail.py`, `list_alerts.py`
- **Behavior 3 (Recommendation):** `list_vulnerabilities.py`, `list_response_policies.py`
- **Behavior 4 (Action Proposal):** `execute_response_policy.py`, `list_waf_top_ips.py`
- **Behavior 5 (Reporting):** `list_waf_events.py`, `list_waf_top_rules.py`, `get_knowledge.py`

Alternatively, use MCP tools directly if available:
- `list_security_events` instead of `list_events.py`
- `get_security_event_detail` instead of `get_event_detail.py`
- `list_assets` instead of `list_assets.py`
- `get_knowledge_document` instead of `get_knowledge.py`

---

## Troubleshooting

### No Events Returned

1. Verify time range is correct (events may be outside window)
2. Check Security Center edition supports event listing
3. Try broader time range: `python list_events.py last24Hours`

### API Returns 403

1. Check RAM permissions: `AliyunYundunSASReadOnlyAccess` required
2. Verify credentials are active (not expired STS tokens)
3. Check if API is temporarily unavailable (retry after 2-3 minutes)

### WAF Events Not Found

1. Verify WAF instance exists: `python get_waf_instance.py`
2. Check log delivery is enabled: `python verify_log_delivery.py`
3. Ensure WAF logs are flowing to SLS

### Knowledge Documents Not Found

1. Run `python list_knowledge.py` to see search paths
2. Set the `KNOWLEDGE_DIR` environment variable to your knowledge directory to override the default search paths.
3. Check that document filenames match the registry (e.g., `compliance_nist.md`)
