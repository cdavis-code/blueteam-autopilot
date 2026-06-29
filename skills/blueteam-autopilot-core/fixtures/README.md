# Demo Fixtures

This directory contains realistic Alibaba Cloud Security Center fixture data for **demo mode** (the default). Every JSON file mirrors the exact output shape of an MCP tool or CLI script. The agent cannot tell the difference between a fixture and a live API response.

## Usage

Demo mode is the default. No `.env` file needed. All scripts in `../blueteam-autopilot-ops/scripts/` will read from these files instead of calling the `aliyun` CLI. No network, no credentials, no Alibaba Cloud account required.

To switch to real mode with live APIs, create a `.env` file with `SECURITY_CENTER_MODE=real`.

## Fixture Map

| Fixture File | Tool / Script | What It Simulates |
|---|---|---|
| `ping.json` | `ping` / `ping.sh` | Health check — returns region + mode |
| `account_context.json` | `get_account_context` / `get-account-context.sh` | Security Center edition + Agentic SOC status |
| `events_recent.json` | `list_security_events` / `list-events.sh` | 6 recent security events (all severities) |
| `event_detail.json` | `get_security_event_detail` / `get-event-detail.sh` | Full attack chain, CVEs, attacker IPs |
| `alerts.json` | `list_alerts_for_event` / `list-alerts.sh` | WAF + CWPP alerts for an event |
| `vulnerabilities.json` | `list_vulnerabilities` / `list-vulnerabilities.sh` | 5 CVEs across all severities |
| `vulnerability_detail.json` | `get_vulnerability_detail` / `get-vulnerability-detail.sh` | Deep-dive on a single CVE with fix |
| `response_policies.json` | `list_response_policies` / `list-response-policies.sh` | 5 response policies (block, isolate, fix, notify) |
| `assets.json` | `list_assets` / `list-assets.sh` | 5 ECS instances with SOC 2 scope tags |
| `waf_instance.json` | `get_waf_instance_info` / `get-waf-instance.sh` | WAF 3.0 instance metadata |
| `waf_events.json` | `list_waf_security_events` / `list-waf-events.sh` | 5 WAF attack events (SQLi, XSS, LFI, scanner) |
| `waf_top_rules.json` | `list_waf_top_rules` / `list-waf-top-rules.sh` | Top 10 triggered WAF rules |
| `waf_top_ips.json` | `list_waf_top_ips` / `list-waf-top-ips.sh` | Top 10 attacker IPs with geo |
| `knowledge_list.json` | `list_knowledge_documents` / `list-knowledge.sh` | 6 knowledge document types |

## Capturing New Fixtures (Real Mode Only)

To capture fresh fixture data from a live Alibaba Cloud environment:

### Using `aliyun` CLI

```bash
# Capture security events (run from skills/ directory)
aliyun sas describe-susp-events --region "$ALIBABA_REGION" > blueteam-autopilot-core/fixtures/events_recent.json

# Capture vulnerabilities
aliyun sas describe-vul-list --region "$ALIBABA_REGION" > blueteam-autopilot-core/fixtures/vulnerabilities.json

# Capture WAF events
aliyun sls GetLogs --project "wafnew-project-..." --logstore "wafnew-logstore" ... > blueteam-autopilot-core/fixtures/waf_events.json
```

### Sanitizing for Demo

- Replace real IPs with RFC 5737 TEST-NET ranges (`203.0.113.0/24`)
- Replace real domains with `example.com`
- Replace real instance IDs with `i-prod-web-01` style placeholders
- Remove account IDs, ARNs, and any identifying information
- Keep attack patterns, severity levels, and CVE references intact

## Design Notes

- **All IPs are RFC 5737 TEST-NET** — safe for demos and public repos
- **Region**: `ap-southeast-1` (marked EXAMPLE)
- **No real account data** — these are synthetic but realistic
- **Severity coverage**: At least one CRITICAL, HIGH, MEDIUM, LOW in events and vulns
- **Attack diversity**: SQLi, XSS, LFI, RCE, brute force, data exfiltration
