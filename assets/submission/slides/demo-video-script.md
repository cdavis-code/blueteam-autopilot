

# Demo Video Script — Alibaba Blueteam

**Target duration:** 3:15  
**Track:** Track 4 — Autopilot Agent  
**Mode:** Demo (offline, zero credentials)

---

## Recording Tips

- Pause 1-2 seconds between scenes for editing cuts
- Total target: under 3:30 (judges won't watch beyond 3:30)

---

## Scene 1: Introduction

**Screen:** Image file demo_0001.png showing project banner

**Narration:**
> "Security analysts spend over 60% of their time manually triaging alerts. Alibaba Blueteam is an AI-powered SecOps copilot that automates the full incident triage lifecycle — from event discovery to action proposal — on Alibaba Cloud."

---

## Scene 2: Zero-Setup Install

**Screen:** Image file demo_0002.png showing how to get started with the project, then image demo_0002.png which shows the installed agent skills.

**Narration:**
> "Installation takes seconds. No repository clone needed. Just run npx skills add — and all 6 agent skills with 15 demo fixtures are bundled locally. The agent also connects to external MCP servers at startup, dynamically discovering tools from CISO Assistant and Alibaba Cloud without code changes."

---

## Scene 3: Confirm Skills Install

**Screen:** Image file demo_0003.png showing that the skills are installed in the agent harness

**Narration:**
> "Alibaba Blueteam installs six agent skills into your prefered agent harness."

---
## Scene 4: Event Discovery

**Screen:** Image file demo_0004.png which shows asking the agent

**Narration:**
> "Let's ask the agent to show recent security events. It can discover events across all severity levels — critical, high, medium, and low — with affected assets and timestamps."

---

## Scene 5: Event Result

**Screen:** Image demo_0005.png which shows the results of the ask.

**Narration:**
> "Notice the agent automatically sorts by severity and cross-references affected assets against the live inventory."

---

## Scene 6: Incident Deep-Dive

**Screen:** Image file demo_0006.png which shows asking the agent

**Narration:**
> "Now let's investigate a critical event. The agent performs a deep-dive analysis — extracting the full attack chain, identifying attacker IPs, correlating CVEs, and mapping to NIST CSF controls."

---

## Scene 7: Response Recommendation

**Screen:** Image demo_0007.png which shows the results of the ask.

**Narration:**
> "Based on the investigation, the agent recommends the least-disruptive response — blocking the attacker IP via WAF response policy. Critically, it proposes the action but requires explicit human approval before execution. This is SOC 2 CC6.8.3 compliant by design."

**Narration:**
> "The agent defaults to dry-run simulation. No state change happens without human confirmation."

---

## Scene 8: Incident Response Report

**Screen:** Image demo_0008.png which shows the agent generating a structured incident report

**Narration:**
> "Now let's generate a full incident response report. The agent aggregates data from 9 sources — event detail, alerts, assets, vulnerabilities, WAF, and compliance controls — into a single structured report with blast radius, investigation timeline, confidence rating, and audit trail. Pydantic models enforce the schema so reports are ready for ticket systems or compliance audits."

---

## Scene 9: GRC Sync & Compliance

**Screen:** Image demo_0009.png which shows the results of the GRC Sync request

**Narration:**
> "Blueteam also integrates with GRC tools like CISO Assistant for live compliance data. The sync pipeline discovers frameworks, validates controls, and maintains an audit trail."

**Action:** Run:
```bash
GRC_MODE=demo bash skills/blueteam-autopilot-knowledge/scripts/grc-sync.sh --list
```

---

## Scene 10: Architecture Overview

**Screen:** Image demo_0010.png which shows the project architectual diagram

**Narration:**
> "The architecture shows the Qwen-powered ConnectOnion agent orchestrating 19 built-in tools across 5 Alibaba Cloud services, with dynamic MCP tool discovery from external servers like CISO Assistant and Vanta. The async bridge pattern means any MCP server plugs in via a JSON config file. Dual-mode enables zero-setup demos and production use from the same codebase."

---

## Closing

**Screen:** Image demo_0011.png which shows the project logo

**Narration:**
> "Alibaba Blueteam — intelligent security operations with human-in-the-loop guardrails and automated compliance reporting."

---