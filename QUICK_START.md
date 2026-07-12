# BlueTeam — Quick Start Walkthrough (Demo Mode)

A 5-minute guided tour of BlueTeam's best features, all running in demo mode with zero cloud credentials.

---

## Setup (2 minutes)

**Option A: Homebrew (macOS/Linux)**

```bash
# Install
brew tap cdavis-code/blueteam
brew trust cdavis-code/blueteam
brew install blueteam-autopilot

# Configure API key (only Qwen Cloud needed — no Alibaba Cloud account)
mkdir -p ~/.blueteam
echo 'DASHSCOPE_API_KEY="sk-..."' > ~/.blueteam/.env

# Launch
blueteam
```

**Option B: pip**

```bash
# Install
pip install blueteam-autopilot

# Configure API key (only Qwen Cloud needed — no Alibaba Cloud account)
mkdir -p ~/.blueteam
echo 'DASHSCOPE_API_KEY="sk-..."' > .env

# Launch
blueteam
```

**Option C: Third-Party Agent Harness (AI IDE)**

```bash
# Install skills into your AI IDE (Qoder, Cursor, OpenCode, etc.)
npx skills add cdavis-code/blueteam-autopilot --skill '*'

# Start using in your IDE chat
```

The skills integrate directly into your IDE's AI chat. You get the same 40 tools, 5 workflows, and HITL approval gates as the standalone TUI — all within your editor. Zero cloud credentials needed for demo mode.

The Textual TUI loads instantly. You're in **demo mode** — all data comes from 23 bundled fixture files. No network calls, no cloud account needed.

---

## Scenario 1: Triage Security Events

**Type:** `Show me recent security events`

BlueTeam fetches and prioritizes 6 security events across all severity levels:

| Severity | Event | Source |
|----------|-------|--------|
| **CRITICAL** | OpenSSL RCE (CVE-2024-5678, CVSS 9.8) | CWPP |
| HIGH | SQL Injection on production WAF | WAF |
| HIGH | LFI Path Traversal attack | WAF |
| MEDIUM | XSS attempt on login page | WAF |
| MEDIUM | SSH brute force (15 source IPs) | CloudFirewall |
| LOW | Suspicious outbound data transfer | CWPP |

**What this shows:** Automatic severity-based prioritization with cross-referenced asset context. The CRITICAL event on the database server (`i-prod-db-01`) surfaces first.

---

## Scenario 2: Deep-Dive Investigation

**Type:** `Investigate the most recent CRITICAL event`

BlueTeam performs a full incident deep-dive:

1. **Attack chain extraction** — Identifies the OpenSSL buffer overflow vulnerability
2. **CVE correlation** — Maps to CVE-2024-5678 with CVSS 9.8 scoring
3. **Asset context** — Confirms `i-prod-db-01` is a SOC 2 in-scope database server (elevates priority)
4. **Attacker footprint** — Shows exploit vectors and potential lateral movement paths
5. **Compliance mapping** — Flags NIST CSF DE.AE-2 (Anomaly Detection) and SOC 2 CC6.8 (Unauthorized Activity Triage)

**What this shows:** The agent doesn't just list events — it investigates like a senior analyst, correlating signals and referencing compliance controls.

---

## Scenario 3: WAF Attack Analysis

**Type:** `Show me WAF attack logs from the last hour`

BlueTeam displays real WAF events with attacker IPs, hit counts, and blocked URLs:

```
203.0.113.100  →  SQLi  →  /api/v1/search?q=product     (47 hits, blocked)
203.0.113.101  →  XSS   →  /login?redirect=%3Cscript%3E  (12 hits, blocked)
203.0.113.100  →  LFI   →  /upload/../../../etc/passwd   (23 hits, blocked)
203.0.113.102  →  Scanner → /admin/config.php            (156 hits, observed)
203.0.113.103  →  SQLi  →  /api/v1/users?id=1' OR '1'='1 (8 hits, blocked)
```

**What this shows:** Live-style WAF log analysis with IP correlation — notice `203.0.113.100` appears in both SQLi and LFI attacks (same attacker, multiple vectors).

---

## Scenario 4: Response Policies & HITL Approval

**Type:** `What response policies are available?`

BlueTeam lists 5 Agentic SOC response policies:

| Policy | Actions | Use Case |
|--------|---------|----------|
| Block IP — 24h | `block_ip`, `create_waf_rule`, `notify` | Automated scanners |
| Block IP — Permanent | `block_ip_permanent`, `notify_manager` | Confirmed malicious actors |
| Isolate Host | `isolate_instance`, `create_snapshot` | RCE, webshell, malware |
| Apply Vuln Fix | `apply_fix`, `verify_fix`, `create_ticket` | Verified CVEs |
| Notify Only | `create_ticket`, `notify_security_ops` | MEDIUM/LOW events |

**Now try:** `Block the SQL injection attacker IP 203.0.113.100`

BlueTeam triggers the **HITL approval gate**:

1. **Dry-run preview** — Shows exactly what will happen (IP added to WAF blacklist for 24h)
2. **Confirmation prompt** — `y/N` — execution only proceeds if you type "yes"
3. **Audit log** — Action recorded with timestamp, operator, and outcome

**What this shows:** SOC 2 CC6.8.3 compliance — no state-changing action executes without explicit human approval. The dry-run preview lets you verify before committing.

---

## Scenario 5: Compliance Audit

**Type:** `Run a compliance audit`

BlueTeam performs a 4-phase compliance gap analysis:

1. **Control Discovery** — Loads NIST CSF and SOC 2 control definitions
2. **Evidence Collection** — Maps current security posture to control requirements
3. **Gap Analysis** — Identifies missing controls and implementation gaps
4. **Report Generation** — Produces a Markdown report with control IDs, status, and remediation priorities

**What this shows:** Automated compliance auditing with framework-aware analysis — not just a checklist, but contextual gap identification.

---

## Scenario 6: Threat Hunting

**Type:** `Run a threat hunt for the last 24 hours`

BlueTeam executes the proactive threat-hunt workflow:

1. **Hypothesis Generation** — Identifies potential threat vectors based on asset inventory
2. **Data Collection** — Queries events, WAF logs, vulnerabilities, and IAM activity
3. **Pattern Analysis** — Correlates signals across data sources
4. **Findings Report** — Documents discovered threats with confidence levels and recommended actions

**What this shows:** Proactive security — the agent doesn't wait for alerts, it hunts for threats using multi-phase workflows.

---

## Scenario 7: Non-Interactive Mode (Cron/Automation)

Exit the TUI (`Ctrl+C`) and try:

```bash
blueteam --prompt "Summarize today's security events"
```

Output goes to stdout — perfect for cron jobs, CI pipelines, or piping to other tools.

---

## What's Available in Demo Mode

All 40 tools work with fixture data:

- **Security Center:** Events, alerts, vulnerabilities, assets, response policies
- **WAF:** Attack logs, top rules, top attacker IPs, instance info
- **IAM:** Users, roles, policies, credential reports, trust analysis
- **Compliance:** Knowledge documents, GRC framework queries, audit reports
- **Operations:** Local script execution, file writing, command execution
- **Vector Memory:** Incident similarity search ("Have we seen this before?")

The only difference from real mode: data comes from fixtures instead of live Alibaba Cloud APIs.

---

## Key Takeaways

| Feature | Demo Mode | Real Mode |
|---------|-----------|-----------|
| Setup time | 2 minutes | 10 minutes (CLI + RAM policies) |
| Data source | 23 JSON fixtures | Live Alibaba Cloud APIs |
| All 40 tools | ✅ Working | ✅ Working |
| HITL approval | ✅ Enforced | ✅ Enforced |
| Compliance audit | ✅ Full workflow | ✅ Full workflow |
| Threat hunting | ✅ 4-phase workflow | ✅ 4-phase workflow |
| Vector memory | ✅ Embeddings | ✅ Embeddings |
| Network calls | ❌ None | ✅ `aliyun` CLI |

---

## Next Steps

- **Production deployment:** See [Real Mode Setup](README.md#real-mode-setup) in the main README
- **Autonomous monitoring:** Try `blueteam --daemon` for 24/7 SOC operations
- **Architecture deep-dive:** Open [blueteam-architecture.html](assets/blueteam-architecture.html) in your browser
- **Full documentation:** [README.md](README.md) · [SECURITY.md](SECURITY.md) · [about.md](submission/about.md)
