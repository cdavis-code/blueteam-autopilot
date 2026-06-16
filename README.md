<div align="center">

![Alibaba Blueteam](assets/banner.svg)

*Intelligent security operations with human-in-the-loop guardrails*

**Triage** security events · **Investigate** incidents · **Recommend** responses · **Report** compliance

* SOC 2 CC6.8 compliant by design
* Dual-mode: live production & offline demo
* 17 CLI scripts · 6 agent skills · zero credentials for demo

[Getting Started ↓](#5-minute-getting-started-demo-mode) · [Real Mode Setup ↓](#real-mode-setup) · [Architecture ↓](#architecture)

</div>

---

## Quick Install

**Prerequisite:** [Node.js 18+](https://nodejs.org) (for `npx`). No repository clone needed. Install directly into your project:

```bash
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
echo 'SECURITY_CENTER_MODE=demo' > .env
```

This creates a new project directory, installs all 6 agent skills (with bundled demo fixtures), and sets demo mode for immediate offline use.

---

## What It Does

Security teams using Alibaba Cloud face a constant flood of Security Center alerts, WAF logs, and vulnerability reports. Manually triaging every event takes hours — meanwhile, real attacks go uninvestigated.

**Alibaba Blueteam** is an AI copilot that:

1. **Discovers** security events from Agentic SOC and WAF
2. **Investigates** each incident with deep-dive analysis (attack chain, CVEs, attacker IPs)
3. **Recommends** the least-disruptive effective response (IP block, host isolation, vuln patch)
4. **Proposes** structured action plans for human approval
5. **Reports** with NIST CSF and SOC 2 compliance mapping
6. **Queries** live GRC data (CISO Assistant, Vanta) for compliance context during incident response

All state-changing actions require **explicit human approval** — SOC 2 CC6.8.3 compliant by design.

---

## Two Modes at a Glance

| Mode | Network | Prerequisites | Speed | Use Case |
|------|---------|--------------|-------|----------|
| `real` | ✅ Live API | `aliyun` CLI + RAM credentials | ~1-3s per call | Production incidents |
| `demo` | ❌ Offline | None | Instant | Demos, CI, development |

Set via the `.env` file in your project root (all scripts `source .env` automatically):

```bash
# Demo mode — offline, no credentials
echo 'SECURITY_CENTER_MODE=demo' > .env

# Real mode — live Alibaba Cloud API calls
echo 'SECURITY_CENTER_MODE=real' > .env
```

---

## 5-Minute Getting Started (Demo Mode)

No Alibaba Cloud account? No problem. Demo mode works with zero setup and zero network calls:

```bash
# 1. Create a project directory and install skills
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y

# 2. Set demo mode
echo 'SECURITY_CENTER_MODE=demo' > .env

# 3. Start your agent harness and ask:
#    "Show me recent security events"
#    "Investigate event evt-demo-20260614-001"
#    "What response policies are available?"
#
# The agent will use bundled fixture data — no API calls, no credentials.
```

**What happens under the hood:** The skills detect `SECURITY_CENTER_MODE=demo` and read from bundled `skills/blueteam-autopilot-core/fixtures/*.json` files instead of calling Alibaba Cloud APIs. You get realistic responses with:
- 6 security events across all severity levels (CRITICAL → LOW)
- Full attack chains with CVEs (e.g., CVE-2026-1234 for RCE)
- 5 Agentic SOC response policies (IP block, host isolation, vuln patch)
- 5 ECS assets with SOC 2 scope tags
- WAF attack logs with top rules and attacker IPs
- NIST CSF and SOC 2 compliance document mappings

That's it. No credentials, no cloud account, no configuration.

---

## Real Mode Setup

For production use with live Alibaba Cloud data:

### Prerequisites

- [Node.js 18+](https://nodejs.org) (for `npx`)
- [aliyun CLI](https://github.com/aliyun/aliyun-cli) installed
- RAM user with these policies:
  - `AliyunYundunSASReadOnlyAccess` — Security Center
  - `AliyunYundunWAFv3FullAccess` — WAF 3.0
  - `AliyunLogFullAccess` — SLS log queries
  - `AliyunVPCReadOnlyAccess` — VPC discovery
- Security Center Enterprise (4) or Ultimate (5) edition
- WAF 3.0 instance with at least one protected domain

### Quick Setup

Your `.env` file must include three Alibaba Cloud credentials plus the mode switch:

| Variable | Purpose | Example |
|----------|---------|--------|
| `ALIBABA_ACCESS_KEY_ID` | RAM user AccessKey ID | `LTAI5t...` |
| `ALIBABA_ACCESS_KEY_SECRET` | RAM user AccessKey Secret | `HkfZ...` |
| `ALIBABA_REGION` | Target Alibaba Cloud region | `ap-southeast-1` |
| `SECURITY_CENTER_MODE` | Execution mode | `real` |

```bash
# 1. Create project and install skills
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y

# 2. Configure credentials and switch to real mode
cat > .env << 'EOF'
ALIBABA_ACCESS_KEY_ID="LTAI5t..."
ALIBABA_ACCESS_KEY_SECRET="HkfZ..."
ALIBABA_REGION="ap-southeast-1"
SECURITY_CENTER_MODE=real
EOF

# 3. Validate your environment
# Use the blueteam-autopilot-prep skill — it runs an 8-stage automated
# check (CLI, credentials, RAM policies, services, infrastructure, logs,
# config generation, readiness report) before you start investigating.

# 4. Start investigating — ask your agent harness:
#    "Show me HIGH severity events from the last hour"
#    "Deep-dive into event evt-xxx-yyy"
```

See [skills/blueteam-autopilot-prep/SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) for the full environment validation procedure.

---

## What's Inside

```
.
├── README.md                          # This file
└── skills/
    ├── blueteam-autopilot-core/       # Core agent: 5-behavior triage cycle
    │   ├── SKILL.md                   # Main prompt — role, tools, guardrails
    │   ├── BEHAVIORS.md               # Detailed workflow for each behavior
    │   ├── references/                # MCP tools, compliance, runbooks
    │   │
    │   └── fixtures/                  # Demo data (14 JSON files — bundled with install)
    │       ├── README.md              # Fixture map and capture instructions
    │       ├── ping.json
    │       ├── account_context.json
    │       ├── events_recent.json     # 6 security events
    │       ├── event_detail.json      # Full attack chain
    │       ├── alerts.json
    │       ├── vulnerabilities.json   # 5 CVEs
    │       ├── vulnerability_detail.json
    │       ├── response_policies.json # 5 response policies
    │       ├── assets.json            # 5 ECS instances
    │       ├── waf_instance.json
    │       ├── waf_events.json        # WAF attack logs
    │       ├── waf_top_rules.json     # Top 10 WAF rules
    │       ├── waf_top_ips.json       # Top 10 attacker IPs
    │       └── knowledge_list.json
    │
    ├── blueteam-autopilot-ops/        # CLI operations: 17 Bash scripts
    │   ├── SKILL.md                   # Script catalog + CLI↔MCP matrix
    │   └── scripts/                   # ping.sh, list-events.sh, etc.
    │
    ├── blueteam-autopilot-prep/       # Environment validator (real mode only)
    │   ├── SKILL.md                   # 8-stage validation procedure
    │   └── scripts/                   # generate-trusted-networks.sh, etc.
    │
    ├── blueteam-autopilot-knowledge/  # Compliance docs & runbooks
    │   ├── SKILL.md
    │   └── documents/                 # NIST CSF, SOC 2, runbooks
    │
    ├── blueteam-autopilot-reports/    # Report generation
    │   ├── SKILL.md
    │   └── scripts/                   # render-report.py
    │
    └── alibaba-security-ops/          # Standalone CLI skill (legacy/evolution)
        └── SKILL.md
```

### Skill Summary

| Skill | Purpose |
|-------|---------|
| `blueteam-autopilot-core` | AI agent workflow — 5-behavior triage cycle with guardrails; GRC MCP live query (CISO Assistant, Vanta) |
| `blueteam-autopilot-ops` | 17 CLI scripts wrapping `aliyun` commands (with demo dispatch) |
| `blueteam-autopilot-prep` | Environment validation (8-stage, real-mode only) |
| `blueteam-autopilot-knowledge` | Compliance controls, runbooks, trusted networks |
| `blueteam-autopilot-reports` | Markdown incident report generation |
| `alibaba-security-ops` | Standalone CLI skill — project evolution reference |

---

## Architecture

```
┌──────────────┐
│   User / AI   │  "Show me recent security events"
│   Harness     │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  blueteam-autopilot-core (SKILL.md)           │
│  • Role + tools + guardrails                  │
│  • 5-behavior triage cycle (BEHAVIORS.md)     │
│  • Mode-aware: SECURITY_CENTER_MODE           │
└──────┬───────────────────────────────────────┘
       │
       ├─── real mode ────▶ aliyun CLI ────▶ Alibaba Cloud APIs
       │                                      (SAS, WAF, SLS)
       │
       ├─── demo mode ───▶ skills/blueteam-autopilot-core/fixtures/*.json
                             (zero network, bundled with install)
       │
       └─── GRC MCP ────▶ CISO Assistant / Vanta MCP servers
                             (live compliance data, fallback to synced docs)
```

---

## Hackathon Info

**Event:** Qwen Cloud Hackathon — Track 4: Autopilot Agent  
**Platform:** Alibaba Cloud Security Center + Agentic SOC  
**Problem:** Security analysts spend 60%+ of time on triage. Agentic SOC surfaces events but lacks intelligent investigation and recommendation.

**Our solution:** An AI copilot that automates the full triage cycle — from event discovery to action proposal — while keeping humans in the loop for all state changes. Works offline for demos, online for production.

### Judging Criteria Alignment

| Criteria | How We Address It |
|----------|-------------------|
| **Technical Depth** | 17 CLI scripts wrapping real Alibaba Cloud APIs; 6 skills with deep security domain knowledge |
| **Practical Value** | Production-ready incident response with SOC 2 CC6.8.3 guardrails |
| **Innovation** | Dual-mode architecture (real/demo) for offline demos and online production |
| **Demo Quality** | 14 fixture files with realistic attack chains; 5-minute offline demo with zero setup |

---

## FAQ

### Do I need an Alibaba Cloud account to try this?

**No!** With Node.js 18+ installed, run `npx skills add`, create a `.env` with `SECURITY_CENTER_MODE=demo`, and everything runs offline using bundled fixture files. No credentials, no API calls, no cloud account. No repository clone required.

### Is this production-ready?

Yes, in real mode. The skills call the same Alibaba Cloud APIs that enterprise SOC teams use. The `blueteam-autopilot-prep` skill validates your entire environment before use.

### Does the AI actually execute response actions?

Only with **explicit human approval**. All state-changing actions require the `--real` flag AND human confirmation. This is a hard requirement per SOC 2 CC6.8.3.

### Can I use this with my own Alibaba Cloud region?

Yes! All region values are dynamically discovered via `get_account_context` / `get-account-context.sh`.

### How do I contribute or report issues?

Open an issue or PR on the repository. Fixture capture instructions are in the bundled [skills/blueteam-autopilot-core/fixtures/README.md](skills/blueteam-autopilot-core/fixtures/README.md).

### What's the minimum Security Center edition needed?

- **Demo mode:** None — works offline
- **Real mode (read-only):** Any edition, but Advanced+ recommended
- **Real mode (full Agentic SOC):** Enterprise (4) or Ultimate (5)

---

## License

See repository license file.
