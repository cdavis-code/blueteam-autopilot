# BlueTeam Autopilot — End-to-End Testing Guide

Comprehensive guide for validating the full BlueTeam Autopilot lifecycle: environment readiness (autonomous) → skills validation → test data generation → unit/integration tests → CLI verification → MCP server validation → Qwen agent loop → Flutter UI walkthrough. Suitable for automated CI runs and live demo rehearsals.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Environment Preparation (Autonomous Setup)](#2-environment-preparation)
3. [Unit & Integration Tests (Offline)](#3-unit--integration-tests-offline)
4. [CLI Smoke Tests (Live)](#4-cli-smoke-tests-live)
5. [MCP Server Validation](#5-mcp-server-validation)
6. [Test Data Generation — WAF Attack Traffic](#6-test-data-generation--waf-attack-traffic)
7. [Agentic SOC Event Verification](#7-agentic-soc-event-verification)
8. [Qwen Agent End-to-End Loop](#8-qwen-agent-end-to-end-loop)
9. [Flutter UI Walkthrough (Demo Script)](#9-ui-walkthrough-demo-script)
10. [Fixture Capture for Demo Mode](#10-fixture-capture-for-demo-mode)
11. [Validation Checklist](#11-validation-checklist)
12. [Troubleshooting Reference](#12-troubleshooting-reference)

**Appendices:**
- [A: Environment Variable Quick Reference](#appendix-a-environment-variable-quick-reference)
- [B: Architecture Reference (Skills-Based)](#appendix-b-architecture-reference)
- [C: Flutter UI Testing](#appendix-c-flutter-ui-testing)
- [D: Quick Demo Commands](#appendix-d-quick-demo-commands-copy-paste)

**Related Guides:**
- [AUTONOMOUS_SETUP.md](../skills/AUTONOMOUS_SETUP.md) - Autonomous environment setup details
- [ENVIRONMENT_INDEPENDENCE.md](../skills/ENVIRONMENT_INDEPENDENCE.md) - Environment customization guide

---

## 1. Prerequisites

### 1.1 Alibaba Cloud Account & Services

| Requirement | How to Verify |
|---|---|
| Alibaba Cloud account with billing | Console → Account Management |
| Security Center (Enterprise or higher) | `aliyun sas DescribeVersionConfig --region $ALIBABA_REGION` |
| Agentic SOC enabled | Console → Security Center → Agentic SOC |
| WAF 3.0 instance active | `aliyun waf-openapi DescribeInstance --region $ALIBABA_REGION` |
| WAF-protected test domain (CNAME mode) | Validated by prep skill Stage 4d (exports `$TEST_DOMAIN`) |
| WAF domain-level log collection enabled | Console → WAF → Log Service → your domain-waf → Enabled |
| SLS project + logstore for WAF logs | `aliyun sls ListProject --region $ALIBABA_REGION` |
| RAM user with required policies | See §1.2 |

### 1.2 Required RAM Policies

| Policy | Purpose |
|---|---|
| `AliyunYundunSASReadOnlyAccess` | Read Security Center alerts, events, vulns |
| `AliyunYundunWAFFullAccess` | Read WAF logs, manage response policies |
| `AliyunLogFullAccess` | Read SLS logstores (WAF log delivery) |
| `AliyunRAMReadOnlyAccess` | Verify own permissions (optional but helpful) |

Verify attached policies:

```bash
aliyun ram ListPoliciesForUser --UserName <your-ram-user>
```

### 1.3 Local Tooling

| Tool | Verify |
|---|---|
| Dart SDK ≥ 3.4 | `dart --version` |
| `aliyun` CLI | `aliyun version` |
| `curl` | `curl --version` |
| `dig` (DNS utils) | `dig -v` |
| Python 3.10+ (for Qwen-Agent) | `python3 --version` |
| `qwen-agent[mcp]` pip package | `pip show qwen-agent` |

### 1.4 Skills Architecture (Agent-Based)

BlueTeam Autopilot uses an **agent skills architecture** instead of traditional Dart packages. The skills are Markdown files with YAML frontmatter that guide the AI agent through complex workflows.

```bash
cd /path/to/cyber
# Confirm skills structure
ls skills/
# Expected:
#   blueteam-autopilot-prep      - Environment validation (autonomous setup)
#   blueteam-autopilot-core      - Core behaviors, MCP tools reference
#   blueteam-autopilot-knowledge - Knowledge documents (assets, networks, compliance)
#   blueteam-autopilot-ops       - Operations scripts (events, WAF, logs)
#   blueteam-autopilot-reports   - Report templates and rendering scripts
#   alibaba-security-ops         - General security operations skill
```

> **Note:** The legacy Dart packages (`alibaba_security_api`, `alibaba_security_cli`, `alibaba_security_mcp`, `alibaba_security_agent`) are still present in `packages/` for backward compatibility, but the primary architecture is now skills-based with MCP tools for dynamic data retrieval.

### 1.5 Automated Readiness Check (Autonomous Mode)

Before proceeding through the manual steps below, run the **`blueteam-autopilot-prep`** skill to automatically validate all prerequisites and generate environment-specific configuration in a single pass. The skill walks through **eight validation stages** — credentials, service activation (Security Center, WAF, Agentic SOC, SLS), **WAF CNAME DNS verification**, RAM permissions (**including self-verification via `AliyunRAMReadOnlyAccess`**), log pipeline health, **WAF domain-level log collection validation**, local tooling (Dart SDK, Python, qwen-agent, dig, curl), **automated trusted networks generation**, and **automated configuration validation** — and reports a consolidated readiness verdict.

#### Installing Skills in Your Agent Harness

Before invoking any skill, the agent harness must be configured to discover the skills in this repository. The skill definitions live under `skills/` (each in its own `SKILL.md`), but harnesses do not auto-detect them — you must register the skills directory.

**Qoder (recommended harness):**

1. Open Qoder in the project root (`/path/to/cyber`).
2. Qoder auto-discovers skills from any `skills/*/SKILL.md` path within the workspace. No extra configuration is needed — simply open the workspace and the skills listed in §1.4 become available as slash commands (e.g. `/blueteam-autopilot-prep`).
3. Verify discovery: type `/` in the prompt and confirm `blueteam-autopilot-prep` appears in the completion list.

**Claude Code:**

1. Create or edit `CLAUDE.md` at the project root.
2. Add the skill path so Claude Code registers it as a slash command:
   ```
   ## Skills
   - skills/blueteam-autopilot-prep/SKILL.md
   ```
3. Restart the Claude Code session; the skill is now invocable via `/blueteam-autopilot-prep`.

**Other harnesses (Cursor, Cline, generic agent):**

Load the skill's `SKILL.md` content as part of the system prompt or context, or copy it into the harness's designated skills/rules directory. The exact mechanism varies by tool — consult your harness documentation for "custom skills" or "custom slash commands."

> **Troubleshooting:** If typing `/blueteam-autopilot-prep` does not resolve, confirm that (a) you opened the harness at the project root (not a parent directory), and (b) the `skills/blueteam-autopilot-prep/SKILL.md` file exists and has valid YAML frontmatter.

To run the check, open the agent harness in the project root and invoke the skill:

```
/blueteam-autopilot-prep
```

> The skill source is at `skills/blueteam-autopilot-prep/SKILL.md`.

**Autonomous Operation:**
- **Stages 1-3:** Validates CLI installation, credentials, and RAM permissions (including self-verification via `AliyunRAMReadOnlyAccess`)
- **Stage 4:** Validates service activation — Security Center, Agentic SOC, WAF 3.0, **WAF CNAME DNS verification** (`dig +short CNAME`), and SLS
- **Stage 5:** Validates infrastructure — WAF domains, log delivery to SLS, SLS project/logstore, **WAF domain-level log collection** (per-domain enablement), and Agentic SOC detection rules
- **Stage 6:** End-to-end connectivity test (WAF attack traffic → SLS log verification)
- **Stage 7:** Automatically generates `trusted-networks.md` from cloud infrastructure (VPCs, VPNs) and validates no hardcoded values remain
- **Stage 8:** Produces comprehensive readiness report with all validation stages and any manual steps needed

> **Tip:** Running the skill first catches most configuration issues (missing policies, wrong region, stale STS tokens, disabled log delivery, **DNS not pointing to WAF CNAME, per-domain log collection not enabled**) before you invest time in the manual steps that follow. The skill is designed to run automatically during environment setup — simply invoke it and the agent handles everything else. See [AUTONOMOUS_SETUP.md](../skills/AUTONOMOUS_SETUP.md) for details on autonomous operation.

---

## 2. Environment Preparation

### 2.1 Autonomous Setup (Recommended)

The BlueTeam Autopilot environment can now be set up **autonomously** through the agent skill system. Simply invoke:

```
/blueteam-autopilot-prep
```

The agent will automatically:
1. Validate credentials, services, and permissions (Stages 1-3, including RAM self-verification)
2. Validate service activation and **WAF CNAME DNS resolution** (Stage 4)
3. Validate infrastructure including **domain-level log collection** (Stage 5)
4. Run end-to-end connectivity test (Stage 6)
5. **Generate `trusted-networks.md`** from your cloud infrastructure (Stage 7a)
6. **Validate configuration** for hardcoded values (Stage 7b)
7. Produce a **comprehensive readiness report** (Stage 8)

This eliminates the need for manual script execution. See [AUTONOMOUS_SETUP.md](../skills/AUTONOMOUS_SETUP.md) for complete details.

### 2.2 Manual Setup (Alternative)

If you prefer manual control or need to troubleshoot autonomous setup:

#### Install Dart Dependencies

```bash
for pkg in alibaba_security_api alibaba_security_cli alibaba_security_mcp alibaba_security_agent; do
  echo "=== $pkg ==="
  (cd packages/$pkg && dart pub get)
done
```

**Expected:** Each package resolves dependencies without errors.

### 2.3 Configure Environment Variables

```bash
export ALIBABA_ACCESS_KEY_ID="<your-ram-user-access-key-id>"
export ALIBABA_ACCESS_KEY_SECRET="<your-ram-user-access-key-secret>"
export ALIBABA_REGION="ap-southeast-1"          # Must match your WAF/Security Center region
export SECURITY_CENTER_MODE="real"              # "dry-run" for safe first pass
```

> `$TEST_DOMAIN` is **not** set manually — the prep skill discovers and exports it during Stage 4d (WAF CNAME DNS validation). All downstream commands that reference `$TEST_DOMAIN` assume the prep skill has already run.

> **Region must be an ID** (e.g. `ap-southeast-1`), not a display name. Common mistake.

> **Environment Independence:** All skill files now use dynamic discovery instead of hardcoded values. The `ALIBABA_REGION` variable is used throughout, and documents like `trusted-networks.md` are auto-generated from your cloud infrastructure. See [ENVIRONMENT_INDEPENDENCE.md](../skills/ENVIRONMENT_INDEPENDENCE.md) for details.

### 2.4 Verify Credentials via STS

```bash
aliyun sts GetCallerIdentity \
  --access-key-id "$ALIBABA_ACCESS_KEY_ID" \
  --access-key-secret "$ALIBABA_ACCESS_KEY_SECRET" \
  --region "$ALIBABA_REGION"
```

**Expected output:** JSON with `AccountId`, `Arn` containing your RAM user name. If you get `InvalidAccessKeyId.NotFound`, the key is wrong. If you get `Forbidden.RAM`, a policy is missing.

---

## 3. Unit & Integration Tests (Offline)

These tests run without network access and validate model serialization, prompt construction, knowledge documents, and time window logic.

### 3.1 Run All Package Tests

```bash
for pkg in alibaba_security_api alibaba_security_cli alibaba_security_mcp alibaba_security_agent; do
  echo "=== Testing $pkg ==="
  (cd packages/$pkg && dart test)
done
```

### 3.2 Expected Results by Package

#### `alibaba_security_api` (≈360 lines of tests)

| Group | What It Validates |
|---|---|
| `TimeRange` | Shortcut parsing (`last15Min`, `1h`, `7d`, etc.), unknown → `lastHour` default |
| `TimeWindow` | Boundary computation, 30-day guardrail clamp, ISO fallback, JSON serialization |
| `SecurityEvent` | Round-trip JSON serialization, field mapping from Alibaba API response shape |
| `Alert` | Nested alert deserialization, attack chain entries |
| `Vulnerability` | CVE field parsing, severity enum mapping |
| `ErrorEnvelope` | Alibaba API error code extraction, `Forbidden.RAM` detection |
| `AlibabaSigner` | HMAC-SHA256 signing canonical request construction |

#### `alibaba_security_cli` (≈58 lines of tests)

| Group | What It Validates |
|---|---|
| `CliConfig` | Env var loading, YAML fallback, default region/mode |
| `JsonFormatter` | Consistent JSON output structure |
| `TableFormatter` | Column alignment, truncation |

#### `alibaba_security_mcp` (≈101 lines of tests)

| Group | What It Validates |
|---|---|
| `AlibabaSecurityServer` | `ping` return shape (`ok`, `region`, `mode`), dry-run execute format |
| `KnowledgeStore` | All 6 document types load (`asset_inventory`, `trusted_networks`, `compliance_nist`, `compliance_soc2`, `runbook_waf_triage`, `policy_change_mgmt`), embedded defaults, unknown type throws, no hardcoded hostnames |

#### `alibaba_security_agent` (≈427 lines of tests)

| Group | What It Validates |
|---|---|
| `SecOpsKnowledge` | `summary()` references dynamic discovery, no hardcoded hostnames |
| `SystemPrompt` | Role definition, all 15 MCP tools listed, 5 core behaviors, dry-run default, compliance controls (DE.AE-2, CC6.8, RS.RP-1), trusted network warning, knowledge fetching policy, execute-never-without-approval guardrail |
| `BehaviorPrompts` | Each of the 5 behaviors (Discovery, Deep-Dive, Recommendation, Action, Reporting) references correct knowledge tools conditionally |
| `IncidentReport` | Round-trip serialization, attack chain entries, compliance controls |
| `ActionProposal` | `requiresApproval` defaults to `true`, trusted network flag |
| `VulnerabilityPrioritization` | Ranked list, asset grouping, remediation steps |
| `ReportTemplates` | Markdown rendering: incident report sections, vuln triage table, action proposal approval block, runbook checklist (RUN-SEC-042) |
| `AgentConfig` | Default values, `toQwenCloudManifest` structure, HTTP vs stdio transport |

**Pass criteria:** All tests green, zero skipped, zero failures.

---

## 4. CLI Smoke Tests (Live)

These commands hit the real Alibaba Cloud APIs. Run with `SECURITY_CENTER_MODE=real`.

### 4.1 Ping (Healthcheck)

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart ping
```

**Expected:**
```json
{"ok": true, "region": "ap-southeast-1", "mode": "real"}
```

**If it fails:** Check credentials, region, and network connectivity. `Forbidden.RAM` = missing `AliyunYundunSASReadOnlyAccess`.

### 4.2 Account Context

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart context
```

**Expected:** JSON with `accountId`, `region`, Security Center edition info.

### 4.3 List Security Events

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart events list --time-range last24Hours
```

**Expected:** JSON array of security events. If you've generated WAF attack traffic (see §6), you'll see WAF-sourced events with severity and attack type.

**Empty result?** Events may take 2–5 minutes to appear after attack traffic. Wait and retry.

### 4.4 Inspect Event Detail

```bash
# Grab an eventId from the previous step
EVENT_ID="<paste-event-id-here>"

dart run packages/alibaba_security_cli/bin/alsec.dart events get --id "$EVENT_ID"
```

**Expected:** Full event detail including attack chain, affected assets, source IPs, severity.

### 4.5 List Alerts for Event

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart alerts --event-id "$EVENT_ID"
```

**Expected:** Array of alerts linked to the event, with plugin name, rule type, rule ID.

### 4.6 List WAF Events

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart events list --time-range last24Hours --source waf
```

**Expected:** WAF-specific security events with attack type (sqli, xss, etc.).

### 4.7 List Vulnerabilities

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart vulns list --severity HIGH
```

**Expected:** List of HIGH+ vulnerabilities if Security Center has scanned your ECS instance. May be empty if no vulns exist — that's valid.

### 4.8 List Response Policies

```bash
dart run packages/alibaba_security_cli/bin/alsec.dart policies list
```

**Expected:** Array of configured response policies (e.g., IP block, rate limit). May be empty if none configured yet.

---

## 5. MCP Server Validation

### 5.1 Start the MCP Server

```bash
dart run packages/alibaba_security_mcp/bin/server.dart
```

**Expected:** Server starts on stdio without errors. You should see initialization logs. Kill with Ctrl+C after confirming startup.

### 5.2 Verify Tool List

The MCP server exposes these 15 tools:

| Tool | Category | Read-Only |
|---|---|---|
| `ping` | Health | ✓ |
| `get_account_context` | Discovery | ✓ |
| `list_security_events` | Events | ✓ |
| `get_security_event_detail` | Events | ✓ |
| `list_alerts_for_event` | Events | ✓ |
| `list_vulnerabilities` | Vulns | ✓ |
| `get_vulnerability_detail` | Vulns | ✓ |
| `list_response_policies` | Response | ✓ |
| `execute_response_policy` | Response | ✗ (dry-run default) |
| `get_waf_instance_info` | WAF | ✓ |
| `list_waf_security_events` | WAF | ✓ |
| `list_waf_top_rules` | WAF | ✓ |
| `list_waf_top_ips` | WAF | ✓ |
| `list_assets` | Discovery | ✓ |
| `list_knowledge_documents` | Knowledge | ✓ |
| `get_knowledge_document` | Knowledge | ✓ |

### 5.3 Dry-Run Safety Check

Set `SECURITY_CENTER_MODE=dry-run` and verify that `execute_response_policy` returns a simulation:

```bash
SECURITY_CENTER_MODE=dry-run dart run packages/alibaba_security_mcp/bin/server.dart
# Then call execute_response_policy via MCP protocol
```

**Expected response shape:**
```json
{
  "policyId": "pol-123",
  "eventId": "evt-456",
  "mode": "dry-run",
  "result": "[DRY-RUN] Would execute response policy ...",
  "raw": {"simulated": true}
}
```

---

## 6. Test Data Generation — WAF Attack Traffic

Generate safe attack traffic against your own WAF-protected test domain to create real security events.

> **Prerequisite:** `$TEST_DOMAIN` is exported by the prep skill (Stage 4d). Run the prep skill before executing these commands.

> **Safety:** Only send traffic to YOUR test domain. Keep rates modest (1 req/sec). Backend is Nginx default page — no real risk.

### 6.1 SQL Injection Probes

```bash
# Basic SQLi (URL-encoded single quote + OR)
curl -s -o /dev/null -w "%{http_code}" \
  "http://$TEST_DOMAIN/?id=1%27%20OR%20%271%27%3D%271"
# Expected: 405 (blocked by WAF)

# UNION-based SQLi
curl -s -o /dev/null -w "%{http_code}" \
  "http://$TEST_DOMAIN/products?search=abc%27%20UNION%20SELECT%20username%2Cpassword%20FROM%20users--"
# Expected: 405
```

### 6.2 XSS Payloads

```bash
curl -s -o /dev/null -w "%{http_code}" \
  "http://$TEST_DOMAIN/search?q=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
# Expected: 405

curl -s -o /dev/null -w "%{http_code}" \
  "http://$TEST_DOMAIN/profile?name=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
# Expected: 405
```

### 6.3 Directory Traversal

```bash
curl -s -o /dev/null -w "%{http_code}" \
  "http://$TEST_DOMAIN/download?file=..%2F..%2Fetc%2Fpasswd"
# Expected: 405
```

### 6.4 Normal Traffic Baseline

Send a few clean requests to confirm WAF passes legitimate traffic:

```bash
curl -s -o /dev/null -w "%{http_code}" "http://$TEST_DOMAIN/"
# Expected: 200 (normal page served)
```

### 6.5 Batch Attack Generation

```bash
for i in $(seq 1 20); do
  curl -s -o /dev/null "http://$TEST_DOMAIN/?id=1%27%20OR%20%271%27%3D%271"
  sleep 1
done
```

### 6.6 Verify WAF Logs in SLS

Wait 30–60 seconds after generating traffic, then query SLS:

```bash
aliyun sls GetLogs \
  --project "wafnew-project-<ACCOUNT_ID>-$ALIBABA_REGION" \
  --logstore "wafnew-logstore" \
  --from $(date -v-1H +%s) --to $(date +%s) \
  --query "matched_host: $TEST_DOMAIN-waf | SELECT final_action, final_plugin, final_rule_type, final_rule_id, real_client_ip LIMIT 10" \
  --region "$ALIBABA_REGION"
```

**Expected:** Log entries showing:
- `final_action: block` for attack traffic
- `final_plugin: sema` (semantic analysis engine)
- `final_rule_type: sqli` or `xss` or `lfilei` (local file inclusion)
- `final_rule_id: 860020` (or similar WAF rule ID)

**If no logs appear:**
1. Verify domain has `-waf` suffix in WAF Log Service settings
2. Check log collection is enabled (not just the global toggle)
3. Wait up to 2 minutes — SLS has ingestion lag

---

## 7. Agentic SOC Event Verification

### 7.1 Console Check

Open the Alibaba Cloud Console:
1. Navigate to **Security Center → Agentic SOC → Security Events**
2. Filter by last 24 hours
3. Look for events with source = `WAF`, attack type matching your test traffic

### 7.2 CLI Verification

```bash
# List recent events
dart run packages/alibaba_security_cli/bin/alsec.dart events list --time-range last24Hours

# Filter to WAF source
dart run packages/alibaba_security_cli/bin/alsec.dart events list --time-range last24Hours --source waf
```

**Expected:** Events corresponding to your attack traffic, with:
- `source: WAF`
- `severity: HIGH` or `MEDIUM`
- Attack type matching your curl payloads

### 7.3 Cross-Reference

Compare what you see in the Agentic SOC console with what the CLI returns:
- Event IDs should match
- Timestamps should be within seconds
- Source IPs should match your laptop's public IP
- Attack chain stages should be consistent

---

## 8. Qwen Agent End-to-End Loop

### 8.1 Install Qwen-Agent

```bash
pip install -U "qwen-agent[mcp]"
```

### 8.2 Create Agent Script

Create `scripts/autopilot_agent.py`:

```python
from qwen_agent.agents import Assistant

llm_cfg = {
    "model": "qwen3-max",
    "model_type": "qwen_dashscope",
}

mcp_tools = [{
    "mcpServers": {
        "alibaba-security": {
            "command": "dart",
            "args": ["run", "packages/alibaba_security_mcp/bin/server.dart"],
            "env": {
                "ALIBABA_ACCESS_KEY_ID": "<from-env>",
                "ALIBABA_ACCESS_KEY_SECRET": "<from-env>",
                "ALIBABA_REGION": "ap-southeast-1",
                "SECURITY_CENTER_MODE": "real"
            }
        }
    }
}]

system_message = """
You are BlueTeam Autopilot, a SecOps assistant for Alibaba Cloud.
Use the Alibaba Security MCP tools to:
1) List recent security events;
2) Explain what happened;
3) Recommend a response policy, but do NOT execute it unless explicitly asked.
"""

agent = Assistant(
    llm=llm_cfg,
    system_message=system_message,
    function_list=mcp_tools,
)

while True:
    user = input("You: ")
    if not user:
        break
    resp = agent.run(user)
    print(resp["output_text"])
```

### 8.3 Test Prompts (Progressive Complexity)

Run these prompts in order and validate each response:

**Prompt 1 — Discovery:**
```
List high-severity security events from the last hour and summarize them.
```
**Expected:** Qwen calls `list_security_events` → returns formatted incident list with severity, attack type, affected assets.

**Prompt 2 — Deep Dive:**
```
For the most recent incident, explain what happened and which IPs should be blocked.
```
**Expected:** Qwen calls `get_security_event_detail` + `list_alerts_for_event` → produces root cause analysis, attack chain, source IPs.

**Prompt 3 — WAF Focus:**
```
Show me the top WAF attack rules triggered in the last 24 hours.
```
**Expected:** Qwen calls `list_waf_top_rules` → returns ranked rule list with hit counts.

**Prompt 4 — Knowledge Augmented:**
```
What NIST CSF controls apply to this incident?
```
**Expected:** Qwen calls `list_knowledge_documents` → `get_knowledge_document(compliance_nist)` → maps incident to DE.AE-2, RS.RP-1, etc.

**Prompt 5 — Response Recommendation:**
```
Propose a response policy I could apply to mitigate this attack.
```
**Expected:** Qwen calls `list_response_policies` → recommends specific policy with risk assessment. Does NOT execute.

### 8.4 Validation Criteria

| Check | Pass Criteria |
|---|---|
| Tool invocation | Qwen calls the correct MCP tool for each prompt |
| Data accuracy | Returned data matches CLI output from §4 |
| No hallucinated IDs | All event IDs, IPs, rule IDs are real values from your environment |
| Safety guardrail | `execute_response_policy` is never called without explicit request |
| Compliance mapping | NIST/SOC 2 controls are referenced from knowledge documents, not fabricated |

---

## 9. UI Walkthrough (Demo Script)

Use this script for live demonstrations. Assumes the Flutter app and backend are deployed.

### 9.1 Pre-Demo Checklist

- [ ] WAF attack traffic generated within last 2 hours (§6)
- [ ] Agentic SOC shows events in console (§7.1)
- [ ] CLI `events list` returns data (§4.3)
- [ ] MCP server starts without errors (§5.1)
- [ ] Qwen agent responds to test prompts (§8.3)
- [ ] Backend API is reachable
- [ ] **Flutter app** loads in browser (`flutter run -d chrome`)
- [ ] Environment validated via autonomous prep skill (Stages 1-8 pass)

### 9.2 Demo Flow

| Step | Action | Expected Result |
|---|---|---|
| 1 | Open **Flutter dashboard** | Incident list populates from `list_security_events` |
| 2 | Click most recent event | **Detail view** shows attack chain, source IPs, affected assets |
| 3 | Click "Run AI Analysis" | Agent produces incident summary with root cause |
| 4 | Review **compliance panel** | NIST CSF and SOC 2 controls mapped to the incident |
| 5 | Click "Recommend Action" | Agent suggests response policy with risk level |
| 6 | Toggle "Dry Run" → Execute | Shows dry-run simulation result (no state change) |
| 7 | Switch to real mode → Execute | Policy executes, IP blocked in WAF |
| 8 | Verify in WAF console | Blocked IP appears in WAF blacklist / response policy log |

### 9.3 Flutter App Architecture

The Flutter app uses **BLoC/Cubit** for state management:

```
┌─────────────────────┐
│  Flutter UI Views   │
│  ┌───────────────┐  │
│  │ Incident List │──┼──► IncidentListCubit
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ Incident      │──┼──► IncidentDetailCubit
│  │ Detail        │  │
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │ Action Panel  │──┼──► ActionPanelCubit
│  └───────────────┘  │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Backend API        │
│  (alibaba_security_ │
│   backend)          │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  MCP Server         │
│  (15 tools)         │
└─────────────────────┘
```

---

## 10. Fixture Capture for Demo Mode

While you have fresh events, capture fixtures for offline/demo use.

### 10.1 Capture Commands

```bash
mkdir -p fixtures

# Recent events
dart run packages/alibaba_security_cli/bin/alsec.dart events list \
  --time-range last24Hours > fixtures/events_recent.json

# Single event detail (use an eventId from above)
dart run packages/alibaba_security_cli/bin/alsec.dart events get \
  --id "$EVENT_ID" > fixtures/event_detail.json

# Alerts for that event
dart run packages/alibaba_security_cli/bin/alsec.dart alerts \
  --event-id "$EVENT_ID" > fixtures/alerts.json

# Vulnerabilities
dart run packages/alibaba_security_cli/bin/alsec.dart vulns list \
  --severity HIGH > fixtures/vulns_high.json

# Response policies
dart run packages/alibaba_security_cli/bin/alsec.dart policies list \
  > fixtures/policies.json
```

### 10.2 Wire Demo Mode

Set `SECURITY_CENTER_MODE=demo` in the API client to serve from fixture files instead of live APIs. Verify:

```bash
SECURITY_CENTER_MODE=demo dart run packages/alibaba_security_cli/bin/alsec.dart events list
```

**Expected:** Returns data from `fixtures/events_recent.json`, not from Alibaba Cloud.

---

## 11. Validation Checklist

Complete end-to-end validation matrix:

### Skills Architecture (Agent-Based)

- [ ] `blueteam-autopilot-prep` skill validates all 8 stages successfully
- [ ] Stage 3 self-verifies RAM permissions via `AliyunRAMReadOnlyAccess` (optional)
- [ ] Stage 4 validates WAF CNAME DNS resolution (`dig +short CNAME`)
- [ ] Stage 5 validates WAF domain-level log collection (per-domain, not just instance-level)
- [ ] Stage 7 autonomously generates `trusted-networks.md` from cloud infrastructure
- [ ] Stage 7 validates no hardcoded environment-specific values remain
- [ ] Stage 8 produces comprehensive readiness report with updated sub-stage numbering
- [ ] All knowledge documents use `{{ALIBABA_REGION}}` or dynamic MCP references
- [ ] No hardcoded hostnames (e.g., `ecs.yourdomain.com`) in prompts or knowledge docs
- [ ] Example values clearly marked with "EXAMPLE" or "AUTO-GENERATED" labels
- [ ] Prep skill Stage 7 generation and validation execute without errors

### Offline (No Network) - Legacy Packages

- [ ] All 4 packages: `dart test` passes with zero failures
- [ ] `SystemPrompt.build()` contains all 15 MCP tool names
- [ ] `SystemPrompt.build()` contains all 5 core behaviors
- [ ] `KnowledgeStore` loads all 6 document types from embedded defaults
- [ ] `ActionProposal.requiresApproval` defaults to `true`
- [ ] `ReportTemplates.renderRunbookChecklist` contains all 5 phases
- [ ] `AgentConfig.toQwenCloudManifest` produces valid structure
- [ ] Time window guardrails clamp to 30 days

### Live (With Network)

- [ ] STS `GetCallerIdentity` returns valid account info
- [ ] CLI `ping` returns `{ok: true, region: ..., mode: real}`
- [ ] CLI `events list` returns security events
- [ ] CLI `events get` returns full event detail with attack chain
- [ ] CLI `alerts` returns alerts for a given event
- [ ] WAF test traffic returns HTTP 405 (blocked)
- [ ] Normal traffic returns HTTP 200 (passed)
- [ ] SLS logs show WAF entries with `final_action: block`
- [ ] Agentic SOC console shows WAF-sourced events
- [ ] MCP server starts without errors
- [ ] MCP `execute_response_policy` in dry-run mode returns simulation
- [ ] Qwen agent calls correct tools for each prompt category
- [ ] Agent never executes response policy without explicit approval
- [ ] Flutter UI loads and displays incident list
- [ ] Flutter UI detail view shows attack chain and AI analysis
- [ ] Flutter UI action panel supports approve/reject workflow
- [ ] Demo mode serves from fixtures when `SECURITY_CENTER_MODE=demo`
- [ ] Autonomous setup completes all 8 stages without manual intervention

---

## 12. Troubleshooting Reference

### Autonomous Setup Issues

| Symptom | Root Cause | Fix |
|---|---|---|
| Prep skill skips Stage 7 | Stage 6 (end-to-end test) failed | Fix log pipeline issues, then re-run skill |
| `trusted-networks.md` not generated | `ALIBABA_REGION` not set | Set region in `.env` file or export it |
| Validation fails after generation | Prep skill Stage 7a didn't complete successfully | Re-invoke the prep skill to regenerate |
| Readiness report shows NEEDS ATTENTION | Manual steps required | Add monitoring IPs, enable detection rules |
| Stage 4d CNAME check fails | DNS not updated after adding domain to WAF | Copy CNAME target from WAF Console → Website Access, update DNS at registrar |
| Stage 5d domain-level logs OFF | Instance-level toggle is not sufficient | Console → WAF → Log Service → Protected Domains → toggle ON for `domain.com-waf` |

### General Issues

| Symptom | Root Cause | Fix |
|---|---|---|
| `InvalidAccessKeyId.NotFound` | Wrong key or key not activated | Verify key in RAM console, check env var has no trailing spaces |
| `Forbidden.RAM` | Missing read-only policy | Attach `AliyunYundunSASReadOnlyAccess` to RAM user |
| `events list` returns empty | No events yet, or wrong region | Confirm region matches Security Center, wait 5 min after attack traffic |
| WAF returns 200 for attack traffic | WAF not in block mode | Check WAF protection mode (should be Block, not Observe) |
| No WAF logs in SLS | Domain-level logging not enabled | Console → WAF → Log Service → enable for `domain-waf` (note the `-waf` suffix). Prep skill Stage 5d now checks this explicitly |
| CNAME not resolving to WAF | DNS not updated after adding domain to WAF | Copy CNAME from WAF Console, update DNS at registrar. Prep skill Stage 4d validates via `dig` |
| `CreateEtlMetaFailed` | SLS project/logstore not linked to WAF | Use console to enable, not API — API has known issues |
| `ModifyUserLogTooFrequent` | Toggling log settings too fast | Wait 5 minutes between changes |
| MCP server fails to start | Missing env vars or Dart pub deps | Run `dart pub get` in MCP package, verify all env vars set |
| Qwen agent hallucinates IDs | Tool not called, LLM fabricating | Check agent logs — should see MCP tool call before response |
| `execute_response_policy` makes real change in dry-run | Mode not set correctly | Verify `SECURITY_CENTER_MODE=dry-run` is exported before server start |
| `which aliyun` returns nothing | CLI not installed | `brew install aliyun-cli` (macOS) or see https://github.com/aliyun/aliyun-cli |
| SLS query returns empty | Wrong project/logstore name | Project: `wafnew-project-<ACCOUNT_ID>-<REGION>`, Logstore: `wafnew-logstore` |

---

## Appendix A: Environment Variable Quick Reference

```bash
# Required
export ALIBABA_ACCESS_KEY_ID="..."
export ALIBABA_ACCESS_KEY_SECRET="..."
export ALIBABA_REGION="ap-southeast-1"

# Mode control
export SECURITY_CENTER_MODE="real"        # or "dry-run" or "demo"

# Test infrastructure — discovered by prep skill
# TEST_DOMAIN is exported by prep skill Stage 4d (not set manually)

# Optional — override auto-discovery
export WAF_INSTANCE_ID="waf_v2intl_public_intl-sg-..."  # Discovered via prep skill Stage 4c
export SLS_PROJECT="wafnew-project-<ACCOUNT_ID>-<REGION>"  # Discovered via prep skill Stage 5c
export SLS_LOGSTORE="wafnew-logstore"
```

## Appendix B: Architecture Reference

### Skills-Based Architecture (Current)

```
┌─────────────────────────────────────────────────────┐
│  Agent Skills (Markdown + YAML)                     │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────┐ │
│  │ prep         │  │ core       │  │ knowledge   │ │
│  │ (validation) │  │(behaviors) │  │  (docs)     │ │
│  └──────────────┘  └────────────┘  └─────────────┘ │
│  ┌──────────────┐  ┌────────────┐                   │
│  │ ops          │  │ reports    │                   │
│  │ (scripts)    │  │(templates) │                   │
│  └──────────────┘  └────────────┘                   │
└────────────────────┬────────────────────────────────┘
                     │ Agent executes skills
┌────────────────────┼────────────────────────────────┐
│  MCP Server (Dart) │                                │
│  15 tools ─────────┘                                │
│  ┌─────────────────────────────────────────────────┐│
│  │ ping, list_security_events, get_event_detail,   ││
│  │ list_alerts, list_vulns, list_policies,         ││
│  │ execute_policy, waf_*, knowledge_*, assets      ││
│  └─────────────────────────────────────────────────┘│
└────────────────────┬────────────────────────────────┘
                     │ stdio / HTTP
┌────────────────────┼────────────────────────────────┐
│  Qwen Agent        │                                │
│  System prompt + MCP tools                          │
│  ┌─────────────────────────────────────────────────┐│
│  │ Behaviors: Discovery → Deep-Dive → Recommend    ││
│  │            → Action Proposal → Reporting         ││
│  └─────────────────────────────────────────────────┘│
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────┼────────────────────────────────┐
│  Flutter Web UI    │                                │
│  ┌─────────────────────────────────────────────────┐│
│  │ Incident list, detail view, AI analysis,        ││
│  │ action panel (approve/reject), compliance panel ││
│  └─────────────────────────────────────────────────┘│
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────┼────────────────────────────────┐
│  Alibaba Cloud     │                                │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │   WAF    │→ │     SLS      │→ │  Agentic SOC  │ │
│  │  3.0     │  │  (Log Store) │  │  (Events/     │ │
│  │          │  │              │  │   Alerts)     │ │
│  └──────────┘  └──────────────┘  └───────┬───────┘ │
│                                          │         │
│  ┌──────────────────┐  ┌────────────────┐│         │
│  │ Security Center  │  │ Response       ││         │
│  │ (Vulns, Assets)  │  │ Policies       │◄┘         │
│  └──────────────────┘  └────────────────┘           │
└─────────────────────────────────────────────────────┘
```

### Legacy Package Architecture (Deprecated)

```
┌─────────────────────────────────────────────────────┐
│  Alibaba Cloud                                      │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │   WAF    │→ │     SLS      │→ │  Agentic SOC  │ │
│  │  3.0     │  │  (Log Store) │  │  (Events/     │ │
│  │          │  │              │  │   Alerts)     │ │
│  └──────────┘  └──────────────┘  └───────┬───────┘ │
│                                          │         │
│  ┌──────────────────┐  ┌────────────────┐│         │
│  │ Security Center  │  │ Response       ││         │
│  │ (Vulns, Assets)  │  │ Policies       │◄┘         │
│  └──────────────────┘  └────────────────┘           │
└──────────────────────────────┬──────────────────────┘
                               │ OpenAPI
┌──────────────────────────────┼──────────────────────┐
│  MCP Server (Dart)           │                      │
│  15 tools ──────────────────┘                      │
│  ┌─────────────────────────────────────────────────┐│
│  │ ping, list_security_events, get_event_detail,   ││
│  │ list_alerts, list_vulns, list_policies,         ││
│  │ execute_policy, waf_*, knowledge_*, assets      ││
│  └─────────────────────────────────────────────────┘│
└──────────────────────────────┬──────────────────────┘
                               │ stdio / HTTP
┌──────────────────────────────┼──────────────────────┐
│  Qwen Agent                  │                      │
│  System prompt + MCP tools   │                      │
│  ┌─────────────────────────────────────────────────┐│
│  │ Behaviors: Discovery → Deep-Dive → Recommend    ││
│  │            → Action Proposal → Reporting         ││
│  └─────────────────────────────────────────────────┘│
└──────────────────────────────┬──────────────────────┘
                               │
┌──────────────────────────────┼──────────────────────┐
│  Backend + Web UI            │                      │
│  Incident list, AI analysis, approve/reject actions │
└─────────────────────────────────────────────────────┘
```

## Appendix C: Flutter UI Testing

The BlueTeam Autopilot includes a **Flutter-based web UI** for incident response workflows.

### C.1 Start the Flutter App

```bash
cd app/blueteam_autopilot
flutter run -d chrome
```

**Expected:** Chrome opens with the BlueTeam Autopilot dashboard showing incident list.

### C.2 UI Components

| Component | Location | Purpose |
|---|---|---|
| Incident List | `lib/views/incident_list/` | Display security events from backend |
| Incident Detail | `lib/views/incident_detail/` | Show attack chain, AI analysis, compliance mapping |
| Action Panel | `lib/views/action_panel/` | Approve/reject response policies |
| Backend Client | `lib/api/backend_client.dart` | Communicate with backend API |

### C.3 State Management

The app uses **BLoC/Cubit** pattern for state management:

- `IncidentListCubit` - Manages incident list state
- `IncidentDetailCubit` - Manages single incident detail state
- `ActionPanelCubit` - Manages action proposal and approval workflow

### C.4 UI Test Scenarios

| Scenario | Expected Result |
|---|---|
| Load dashboard | Incident list populates from `list_security_events` |
| Click incident | Detail view shows attack chain, source IPs, affected assets |
| Click "Run AI Analysis" | Agent produces incident summary with root cause |
| Review compliance panel | NIST CSF and SOC 2 controls mapped to incident |
| Click "Recommend Action" | Agent suggests response policy with risk level |
| Toggle "Dry Run" → Execute | Shows dry-run simulation result (no state change) |
| Approve action | Policy executes, IP blocked in WAF |
| Verify in WAF console | Blocked IP appears in WAF blacklist / response policy log |

### C.5 Running Flutter Tests

```bash
cd app/blueteam_autopilot
flutter test
```

**Expected:** All widget and cubit tests pass:
- `action_panel_cubit_test.dart` - Action proposal and approval workflow
- `incident_detail_cubit_test.dart` - Incident detail loading and AI analysis
- `incident_list_cubit_test.dart` - Incident list loading and filtering
- `widget_test.dart` - Basic widget rendering

---

## Appendix D: Quick Demo Commands (Copy-Paste)

```bash
# $TEST_DOMAIN is exported by the prep skill (Stage 4d) — run prep first

# 1. Generate attack traffic
for i in $(seq 1 10); do curl -s -o /dev/null "http://$TEST_DOMAIN/?id=1%27%20OR%201=1"; sleep 1; done
curl -s -o /dev/null "http://$TEST_DOMAIN/search?q=%3Cscript%3Ealert(1)%3C/script%3E"
curl -s -o /dev/null "http://$TEST_DOMAIN/download?file=../../etc/passwd"

# 2. Wait 60s for event propagation, then verify
sleep 60
dart run packages/alibaba_security_cli/bin/alsec.dart events list --time-range lastHour

# 3. Start MCP server
dart run packages/alibaba_security_mcp/bin/server.dart
```
