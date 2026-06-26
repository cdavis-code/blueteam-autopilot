# Alibaba Blueteam — Submission Description

*Track 4: Autopilot Agent*

---

## What It Does

Alibaba Blueteam is an AI-powered SecOps copilot that automates the full security incident triage lifecycle on Alibaba Cloud — from event discovery through investigation, response recommendation, and compliance reporting — while enforcing human-in-the-loop guardrails on every state-changing action.

Security analysts spend 60%+ of their time manually triaging alerts. Alibaba Cloud's Agentic SOC surfaces security events but lacks intelligent investigation and context-aware response recommendations. Blueteam fills this gap with an autonomous agent that:

1. **Discovers** security events from Agentic SOC and WAF in real-time
2. **Investigates** each incident with deep-dive analysis (attack chains, CVEs, attacker IPs, affected assets)
3. **Recommends** the least-disruptive effective response (IP block via WAF, host isolation, vulnerability patch)
4. **Proposes** structured action plans requiring explicit human approval before execution
5. **Reports** with NIST CSF and SOC 2 compliance mapping for audit trails
6. **Queries** live GRC data (CISO Assistant, Vanta) for real-time compliance context during incident response

All state-changing actions require **explicit human approval** — compliant with SOC 2 CC6.8.3 by design.

---

## How It Works

### Architecture

Blueteam is built as 6 modular agent skills orchestrated by a Qwen-powered core agent:

| Skill | Purpose |
|-------|---------|
| **blueteam-autopilot-core** | 5-behavior triage cycle with MCP tool registry, mode-aware dispatch, and human-in-the-loop guardrails |
| **blueteam-autopilot-ops** | 17 CLI scripts wrapping Alibaba Cloud APIs (SAS, WAF 3.0, SLS, VPC, STS) via `aliyun` CLI |
| **blueteam-autopilot-prep** | 8-stage environment validation (CLI, credentials, RAM policies, services, infrastructure, logs, config, readiness) |
| **blueteam-autopilot-knowledge** | Compliance controls (NIST CSF, SOC 2), runbooks, trusted networks, GRC sync pipeline |
| **blueteam-autopilot-reports** | Markdown incident report generation with JSON schemas and templates |
| **alibaba-security-ops** | Standalone CLI skill (legacy/evolution reference) |

### Dual-Mode Architecture

- **Real mode** (`SECURITY_CENTER_MODE=real`): Live Alibaba Cloud API calls via `aliyun` CLI. Production-ready for enterprise SOC teams.
- **Demo mode** (`SECURITY_CENTER_MODE=demo`): Reads from 14 bundled JSON fixture files. Zero network calls, zero credentials, zero setup. Works fully offline.

Both modes share identical input/output shapes — agent behavior is indistinguishable regardless of mode.

### GRC Integration

Live compliance data from CISO Assistant Community and Vanta MCP servers. The agent queries GRC tools during incident response for real-time control status, framework requirements, and vendor risk — with fallback to locally synced compliance documents when MCP is unavailable.

A full GRC sync pipeline (`grc-sync.sh`) supports scheduled batch export of compliance frameworks with YAML frontmatter, version tracking, backup archival, and audit logging.

### MCP Tool Integration

20+ MCP tools organized across four categories:
- **Core tools**: Security events, alerts, vulnerabilities, assets
- **WAF tools**: Attack logs, top rules, top attacker IPs, instance discovery
- **Response tools**: Policy listing, dry-run simulation, execution (with human approval)
- **GRC tools**: Live queries to CISO Assistant MCP and Vanta MCP servers

---

## Judging Criteria Alignment

### Innovation & AI Creativity (30%)
- Sophisticated MCP integration across 4 tool categories (20+ tools) plus 2 GRC MCP servers
- Dual-mode architecture enabling zero-setup offline demos — unique approach for security tooling
- GRC sync pipeline with provider plugin architecture for multi-GRC support

### Technical Depth & Engineering (30%)
- 17 production CLI scripts wrapping 5 Alibaba Cloud service APIs (SAS, WAF 3.0, SLS, VPC, STS)
- 6 modular skills with clean separation of concerns (core logic, operations, validation, knowledge, reporting)
- Source-priority document resolution chain (GRC-synced → bundled → fallback with warnings)
- 8-stage automated environment validation before production use
- Comprehensive integration test suite (46 checks, all passing)

### Problem Value & Impact (25%)
- Addresses a real pain point: SOC analysts spending 60%+ time on manual triage
- Production-ready for Alibaba Cloud Enterprise/Ultimate Security Center customers
- Open-source, installable via `npx skills add` — no clone, no build step
- Dual-mode enables adoption without cloud account (demo) with clear upgrade path (real)

### Presentation & Documentation (15%)
- Comprehensive README with 5-minute getting started guide
- Architecture diagram showing full system topology
- Two-audience documentation (end-user quick start vs. developer setup)
- Inline code documentation and SKILL.md files for each skill module

---

## Key Technical Highlights

- **Alibaba Cloud APIs used**: Security Center (DescribeSuspEvents, DescribeSuspEventDetail, DescribeVulList), WAF 3.0 (DescribeInstance, DescribeRuleHitsTopRuleId, DescribeRuleHitsTopClientIp, DescribeSecurityEventLogs), SLS (GetLogs), VPC (DescribeVpcs), STS (GetCallerIdentity)
- **Qwen Cloud**: Powers the core agent reasoning via Qwen LLM for security event analysis, attack chain correlation, and response recommendation
- **MCP servers**: Alibaba Cloud Security MCP + CISO Assistant MCP + Vanta MCP
- **Compliance frameworks**: NIST CSF v2.0, SOC 2 Type II CC6
- **Install**: `npx skills add cdavis-code/blueteam-autopilot --skill '*' -y` (Node.js 18+, no clone required)

---

## Track

**Track 4: Autopilot Agent** — Automates real-world security operations workflows end-to-end: from system alerts to automated investigation and remediation recommendation, with human-in-the-loop checkpoints at all critical decision points.
