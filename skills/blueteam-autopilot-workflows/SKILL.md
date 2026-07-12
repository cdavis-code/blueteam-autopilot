---
name: blueteam-autopilot-workflows
description: >
  Multi-phase security investigation workflows for Alibaba Cloud.
  Use when conducting incident response, IAM forensics, threat hunting,
  compliance audits, or continuous SOC monitoring. Each workflow is an
  executable playbook with concrete script invocations.
allowed-tools:
  - Bash
  - Read
---

# BlueTeam — Security Workflows

Five multi-phase investigation workflows for Alibaba Cloud security operations.
Each workflow chains phases together — every phase's output feeds the next.

## How to Execute a Workflow

1. **Read the WORKFLOW.md** for the chosen workflow in this skill's `workflows/` directory:
   - `workflows/incident-response/WORKFLOW.md`
   - `workflows/iam-forensic/WORKFLOW.md`
   - `workflows/threat-hunt/WORKFLOW.md`
   - `workflows/compliance-audit/WORKFLOW.md`
   - `workflows/continuous-monitor/WORKFLOW.md`
2. **Execute each phase in order** — run the bash code blocks shown in each phase
3. **Pass outputs between phases** — each phase produces structured output consumed by the next
4. **Enforce HITL** for phases marked `requires-hitl: true` — prompt the user before any state-changing action

## Script Invocation Convention

All security tools are Python scripts in `skills/blueteam-autopilot-ops/scripts/`:

```bash
python skills/blueteam-autopilot-ops/scripts/<script_name>.py [args...]
```

Scripts handle demo/real mode dispatch internally via `SECURITY_CENTER_MODE` in `.env`.
Output is JSON to stdout. Arguments in `[brackets]` are optional, `<angle brackets>` are required.

## Demo vs. Real Mode

| Mode | Behavior | Setup |
|------|----------|-------|
| `demo` (default) | Returns fixture JSON from `skills/blueteam-autopilot-core/fixtures/` | No credentials needed |
| `real` | Calls live Alibaba Cloud APIs via `aliyun` CLI | `SECURITY_CENTER_MODE=real` in `.env` + `aliyun configure` |

## Available Workflows

| Workflow | Phases | Trigger |
|----------|--------|---------|
| `incident-response` | discovery → deep_dive → recommendation → action → report | "Investigate this event", "Respond to incident" |
| `iam-forensic` | discovery → analysis → remediation → persist | "IAM audit", "Check RAM trust relationships" |
| `threat-hunt` | collect → analyze → correlate → report | "Hunt for threats", "Assess security posture" |
| `compliance-audit` | inventory → map → evidence → report | "Compliance assessment", "Audit controls" |
| `continuous-monitor` | scan → triage → escalate | Daemon mode, scheduled checks |

## Tool Categories

### Script-Based Tools (27 tools)
These map to Python scripts and return JSON:

```bash
# Core
python skills/blueteam-autopilot-ops/scripts/ping.py
python skills/blueteam-autopilot-ops/scripts/get_account_context.py
python skills/blueteam-autopilot-ops/scripts/list_assets.py

# Security Events
python skills/blueteam-autopilot-ops/scripts/list_events.py [time_range] [severity] [status]
python skills/blueteam-autopilot-ops/scripts/get_event_detail.py <event_id>
python skills/blueteam-autopilot-ops/scripts/list_alerts.py <event_id>

# Vulnerabilities
python skills/blueteam-autopilot-ops/scripts/list_vulnerabilities.py [time_range] [severity]
python skills/blueteam-autopilot-ops/scripts/get_vulnerability_detail.py <vuln_id>

# Response Policies
python skills/blueteam-autopilot-ops/scripts/list_response_policies.py [page_size]
python skills/blueteam-autopilot-ops/scripts/execute_response_policy.py <policy_id> <event_id> [--real]

# WAF
python skills/blueteam-autopilot-ops/scripts/get_waf_instance.py
python skills/blueteam-autopilot-ops/scripts/list_waf_events.py [time_range]
python skills/blueteam-autopilot-ops/scripts/list_waf_top_rules.py [time_range]
python skills/blueteam-autopilot-ops/scripts/list_waf_top_ips.py [time_range]
python skills/blueteam-autopilot-ops/scripts/block_waf_ips.py <ip1,ip2,...> [--real]

# RAM / IAM
python skills/blueteam-autopilot-ops/scripts/list_ram_users.py
python skills/blueteam-autopilot-ops/scripts/list_ram_roles.py
python skills/blueteam-autopilot-ops/scripts/list_ram_policies.py
python skills/blueteam-autopilot-ops/scripts/get_ram_credential_report.py
python skills/blueteam-autopilot-ops/scripts/get_role_trust_policy.py <role_name>
python skills/blueteam-autopilot-ops/scripts/list_attached_policies.py <entity_name>
python skills/blueteam-autopilot-ops/scripts/analyze_trust_relationships.py
python skills/blueteam-autopilot-ops/scripts/score_risk_matrix.py
python skills/blueteam-autopilot-ops/scripts/detach_policy.py <entity> <policy_name> [--real]
python skills/blueteam-autopilot-ops/scripts/rotate_access_key.py <user_name> [--real]
python skills/blueteam-autopilot-ops/scripts/delete_stale_user.py <user_name> [--real]

# Knowledge
python skills/blueteam-autopilot-ops/scripts/list_knowledge.py
python skills/blueteam-autopilot-ops/scripts/get_knowledge.py <type>

# Diagnostics
python skills/blueteam-autopilot-ops/scripts/verify_log_delivery.py
```

### Harness-Native Tools (13 tools)
These are handled directly by the harness — no script needed:

| Tool | How the Harness Handles It |
|------|---------------------------|
| `execute_local_script` | Use `Bash` tool with the script path |
| `run_command` | Use `Bash` tool with the command |
| `write_file` | Use the harness's file write capability |
| `generate_incident_report` | Aggregate data from prior script calls and synthesize a report |
| `store_incident_memory` | Save findings to a local JSON file or database |
| `search_similar_incidents` | Search saved incident records for pattern matches |
| `get_monitor_state` / `update_monitor_state` | Read/write monitor state from a local file |
| `store_scan_snapshot` / `diff_previous_scan` | Save and compare IAM scan snapshots |

## State-Changing Actions

These scripts require the `--real` flag and **must prompt the user before execution**:

- `execute_response_policy.py` — enables a response automation rule
- `block_waf_ips.py` — creates a WAF IP blacklist
- `detach_policy.py` — removes an IAM policy attachment
- `rotate_access_key.py` — rotates an access key
- `delete_stale_user.py` — deletes a RAM user

Show the user what will change, get explicit approval, then run with `--real`.

## Compliance Context

- NIST CSF: PR.PT-4 (Network Bounding), DE.AE-2 (Anomaly Detection), RS.RP-1 (Response Planning)
- SOC 2: CC6.1 (Boundary Protection), CC6.8 (Unauthorized Activity Triage), CC6.8.3 (HITL Approval)

## Basic/Advanced Edition Fallback

If `list_events.py` returns 0 events, this is EXPECTED on Basic/Advanced editions.
Immediately fall back to WAF-based investigation using `list_waf_events.py`,
`list_waf_top_ips.py`, and `list_waf_top_rules.py`.
Never report "no events found" without first checking WAF logs.
