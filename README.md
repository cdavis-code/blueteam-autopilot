<div align="center">

![Alibaba Blueteam](assets/banner.svg)

*Intelligent security operations with human-in-the-loop guardrails*

**Triage** security events · **Investigate** incidents · **Recommend** responses · **Report** compliance

* SOC 2 CC6.8 compliant by design
* Dual-mode: live production & offline demo
* **Standalone Python agent** built on Qwen Cloud with function calling + thinking mode
* 17 CLI scripts · 7 agent skills · zero credentials for demo

🎬 **[Watch Demo Video](https://www.youtube.com/watch?v=-eqQJuAFHhA)**

[Getting Started ↓](#5-minute-getting-started-demo-mode) · [Real Mode Setup ↓](#real-mode-setup) · [Architecture ↓](#architecture)

</div>

---

## Quick Install

### Option A: Standalone Agent (Recommended)

A standalone Python agent built on **Qwen Cloud's OpenAI-compatible API** using function calling, thinking mode, and streaming. Run it directly from the terminal — no AI IDE harness required.

```bash
# Clone the repository
git clone https://github.com/cdavis-code/blueteam-autopilot.git
cd blueteam-autopilot

# Install Python dependencies
pip install -r agent/requirements.txt

# Configure your Qwen Cloud API key
cp .env.example .env
# Edit .env and add: DASHSCOPE_API_KEY="sk-..."

# Run the agent
python -m agent
```

The agent uses 17 registered tools (mapped to the bundled bash scripts) and enforces human-in-the-loop approval gates in code for all state-changing actions.

### Option B: Skills for AI IDE Harness

Install as skills for Qoder, Cursor, or other AI IDEs:

```bash
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
```

This creates a new project directory and installs all 7 agent skills (with bundled demo fixtures). Demo mode is the default, so you can start immediately with zero configuration.

---

## What It Does

Security teams using Alibaba Cloud face a constant flood of Security Center alerts, WAF logs, and vulnerability reports. Manually triaging every event takes hours — meanwhile, real attacks go uninvestigated.

**BlueTeam Autopilot** is a standalone AI agent built on Qwen Cloud that:

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
| `demo` | ❌ Offline | None (agent: `DASHSCOPE_API_KEY` only) | Instant | Demos, CI, development (default) |
| `real` | ✅ Live API | `aliyun` CLI + RAM credentials + `.env` | ~1-3s per call | Production incidents |

**Demo mode is the default.** For the standalone agent, you need a Qwen Cloud API key. For the skills (AI IDE harness), no `.env` file is needed. To switch to real mode with live Alibaba Cloud API calls, create a `.env` file:

```bash
# Standalone agent + real mode
cat > .env << 'EOF'
DASHSCOPE_API_KEY="sk-..."             # Qwen Cloud API key (required for agent)
ALIBABA_ACCESS_KEY_ID="LTAI5t..."
ALIBABA_ACCESS_KEY_SECRET="HkfZ..."
SECURITY_CENTER_MODE=real
# ALIBABA_REGION="ap-southeast-1"  # Optional — auto-discovered from aliyun CLI config
EOF
```

See [.env.example](.env.example) for all available configuration options.

---

## 5-Minute Getting Started (Demo Mode)

No Alibaba Cloud account? No problem. Demo mode works with zero cloud setup:

### Standalone Agent

```bash
# 1. Clone and install
git clone https://github.com/cdavis-code/blueteam-autopilot.git
cd blueteam-autopilot
pip install -r agent/requirements.txt

# 2. Configure Qwen Cloud API key
cp .env.example .env
# Edit .env: DASHSCOPE_API_KEY="sk-..."

# 3. Run the agent and start investigating
python -m agent
# > Show me recent security events
# > Investigate event evt-demo-20260614-001
# > What response policies are available?
```

### AI IDE Harness (Skills)

```bash
# 1. Create a project directory and install skills
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y

# 2. Start your agent harness and ask:
#    "Show me recent security events"
#    "Investigate event evt-demo-20260614-001"
#    "What response policies are available?"
#
# The agent will use bundled fixture data — no API calls, no credentials.
```

**What happens under the hood:** Demo mode is the default. The scripts read from bundled `skills/blueteam-autopilot-core/fixtures/*.json` files instead of calling Alibaba Cloud APIs. You get realistic responses with:
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

- [Python 3.10+](https://python.org) (for the standalone agent)
- [Node.js 18+](https://nodejs.org) (for `npx`, if using skills in AI IDE)
- [aliyun CLI](https://github.com/aliyun/aliyun-cli) installed
- RAM user with these policies:
  - `AliyunYundunSASReadOnlyAccess` — Security Center
  - `AliyunYundunWAFv3FullAccess` — WAF 3.0
  - `AliyunLogFullAccess` — SLS log queries
  - `AliyunVPCReadOnlyAccess` — VPC discovery
- Security Center Enterprise (4) or Ultimate (5) edition
- WAF 3.0 instance with at least one protected domain

### Quick Setup

Your `.env` file must include Qwen Cloud API key plus Alibaba Cloud credentials:

| Variable | Purpose | Example |
|----------|---------|--------|
| `DASHSCOPE_API_KEY` | Qwen Cloud API key (required for agent) | `sk-...` |
| `ALIBABA_ACCESS_KEY_ID` | RAM user AccessKey ID | `LTAI5t...` |
| `ALIBABA_ACCESS_KEY_SECRET` | RAM user AccessKey Secret | `HkfZ...` |
| `SECURITY_CENTER_MODE` | Execution mode (`demo` or `real`) | `real` |
| `ALIBABA_REGION` | Target region (optional — auto-discovered from `aliyun configure`) | `ap-southeast-1` |

```bash
# 1. Clone the repository
git clone https://github.com/cdavis-code/blueteam-autopilot.git
cd blueteam-autopilot

# 2. Install Python dependencies
pip install -r agent/requirements.txt

# 3. Configure credentials (Qwen Cloud + Alibaba Cloud + real mode)
cp .env.example .env
# Edit .env:
#   DASHSCOPE_API_KEY="sk-..."
#   ALIBABA_ACCESS_KEY_ID="LTAI5t..."
#   ALIBABA_ACCESS_KEY_SECRET="HkfZ..."
#   SECURITY_CENTER_MODE=real

# 4. Validate your environment (optional, for real mode)
# Use the blueteam-autopilot-prep skill — it runs an 8-stage automated
# check (CLI, credentials, RAM policies, services, infrastructure, logs,
# config generation, readiness report) before you start investigating.

# 5. Run the agent and start investigating
python -m agent
# > Show me HIGH severity events from the last hour
# > Deep-dive into event evt-xxx-yyy
```

See [skills/blueteam-autopilot-prep/SKILL.md](skills/blueteam-autopilot-prep/SKILL.md) for the full environment validation procedure.

---

## What's Inside

```
.
├── README.md                          # This file
├── BUGS.md                            # Known issues and security findings
├── LICENSE                            # MIT License
├── CHANGELOG.md                       # Version history
├── .env.example                       # Environment variable template
│
├── agent/                             # Standalone Python agent (Qwen Cloud)
│   ├── __init__.py                    # Package marker
│   ├── __main__.py                    # Entry point: python -m agent
│   ├── main.py                        # Agent loop: Qwen API with function calling
│   ├── tools.py                       # 17 tool schemas + bash script executor
│   ├── system_prompt.py               # System prompt (condensed SKILL.md + BEHAVIORS.md)
│   ├── hitl.py                        # Human-in-the-loop approval gates
│   ├── cli.py                         # Interactive CLI with rich formatting
│   ├── config.py                      # .env loader + typed configuration
│   └── requirements.txt               # openai, python-dotenv, rich
│
├── assets/
│   ├── banner.svg                     # Project banner
│   ├── logo.png                       # Project logo
│   ├── architecture-diagram.svg       # Architecture overview
│   └── submission/                    # Hackathon submission materials
│       ├── about.md                   # Devpost submission content
│       ├── medium-article.md          # Medium article draft
│       ├── proof-of-deployment.md     # Alibaba Cloud deployment evidence
│       ├── console-*.png              # Alibaba Cloud console screenshots
│       └── slides/                    # Demo video script + screenshots
│
└── skills/
    ├── blueteam-autopilot-core/       # Core agent: 5-behavior triage cycle
    │   ├── SKILL.md                   # Main prompt — role, tools, guardrails
    │   ├── BEHAVIORS.md               # Detailed workflow for each behavior
    │   ├── references/                # MCP tools, compliance, runbooks
    │   │
    │   └── fixtures/                  # Demo data (15 JSON files — bundled with install)
    │       ├── README.md              # Fixture map and capture instructions
    │       ├── ping.json
    │       ├── account_context.json
    │       ├── events_recent.json     # 6 security events
    │       ├── event_detail.json      # Full attack chain
    │       ├── event_detail_evt-demo-20260614-003.json  # Prompt injection test fixture
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
    │       └── _discover-region.sh    # Shared region auto-discovery helper
    │
    ├── blueteam-autopilot-prep/       # Environment validator (real mode only)
    │   ├── SKILL.md                   # 8-stage validation procedure
    │   └── scripts/                   # generate-trusted-networks.sh, etc.
    │
    ├── blueteam-autopilot-knowledge/  # Compliance docs, runbooks & GRC sync
    │   ├── SKILL.md
    │   ├── documents/                 # NIST CSF, SOC 2, runbooks, trusted networks, change mgmt policy
    │   ├── grc-providers/             # GRC integration scripts (CISO Assistant)
    │   ├── scripts/                   # fetch-knowledge.sh, grc-sync.sh, grc-webhook.sh
    │   └── policies.json              # Compliance policy definitions
    │
    ├── blueteam-autopilot-reports/    # Report generation
    │   ├── SKILL.md
    │   ├── templates/                 # Incident report, action proposal templates
    │   ├── schemas/                   # JSON schemas for structured reports
    │   └── scripts/                   # render-report.py
    │
    ├── blueteam-autopilot-compat/     # CLI compatibility validation
    │   ├── SKILL.md                   # Compatibility checker documentation
    │   ├── references/                # CLI command baseline (cli-baseline.json)
    │   └── scripts/                   # check-compat.sh (5-stage validator)
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
| `blueteam-autopilot-knowledge` | Compliance controls, runbooks, GRC sync pipeline, trusted networks |
| `blueteam-autopilot-reports` | Markdown incident report generation with JSON schemas |
| `blueteam-autopilot-compat` | CLI compatibility validation — detects breaking changes in `aliyun` CLI commands, parameters, and response structures |
| `alibaba-security-ops` | Standalone CLI skill — project evolution reference |

---

## Architecture

![Architecture Diagram](assets/architecture-diagram.svg)

<details>
<summary>Text-based architecture (fallback)</summary>

```
┌──────────────┐
│   User / CLI  │  "Show me recent security events"
│   (python -m  │
│    agent)     │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Agent Runtime (agent/main.py)                │
│  • Qwen Cloud API (OpenAI-compatible)         │
│  • Function calling: 17 tool schemas          │
│  • Thinking mode: complex orchestration         │
│  • Streaming: real-time CLI output            │
│  • HITL gates: SOC 2 CC6.8.3 in code          │
└──────┬───────────────────────────────────────┘
       │
       ├─── tools.py ──▶ bash scripts ──┬─── real mode ──▶ Alibaba Cloud APIs
       │                                 │                   (SAS, WAF, SLS)
       │                                 │
       │                                 └─── demo mode ──▶ fixtures/*.json
       │                                                     (zero network)
       │
       ├─── GRC MCP ────▶ CISO Assistant / Vanta MCP servers
       │                     (live compliance data, fallback to synced docs)
       │
       └─── Qwen Cloud ──▶ Qwen LLM (agent reasoning + tool orchestration)
```

</details>

---

## FAQ

### Do I need an Alibaba Cloud account to try this?

**No!** For the standalone agent, you only need a Qwen Cloud API key (free tier available at [dashscope-intl.aliyuncs.com](https://dashscope-intl.aliyuncs.com)). Demo mode uses bundled fixture files — no Alibaba Cloud credentials needed. For the skills (AI IDE harness), even the Qwen key is optional — the IDE provides the LLM.

### Is this production-ready?

Yes, in real mode. The agent calls the same Alibaba Cloud APIs that enterprise SOC teams use (Security Center, WAF, SLS). The `blueteam-autopilot-prep` skill validates your entire environment before use.

### Does the AI actually execute response actions?

Only with **explicit human approval**. All state-changing actions require the `--real` flag AND human confirmation. This is a hard requirement per SOC 2 CC6.8.3.

### Can I use this with my own Alibaba Cloud region?

Yes! Region is auto-discovered from your `aliyun` CLI configuration (`aliyun configure`). You can also set `ALIBABA_REGION` in `.env` to override it explicitly.

### How does the standalone agent work?

The agent (`agent/main.py`) runs a function calling loop against Qwen Cloud's OpenAI-compatible API. It registers 17 tools (each mapped to a bash script), enables thinking mode for complex orchestration, and streams results to the CLI in real-time. State-changing tools require human approval before execution.

### How do I contribute or report issues?

Open an issue or PR on the repository. Fixture capture instructions are in the bundled [skills/blueteam-autopilot-core/fixtures/README.md](skills/blueteam-autopilot-core/fixtures/README.md).

### What's the minimum Security Center edition needed?

- **Demo mode:** None — works offline
- **Real mode (read-only):** Any edition, but Advanced+ recommended
- **Real mode (full Agentic SOC):** Enterprise (4) or Ultimate (5)

---

## License

[MIT License](LICENSE) — Copyright (c) 2026 Chris Davis
