

# Demo Video Script — Alibaba Blueteam

**Target duration:** 2:45  
**Track:** Track 4 — Autopilot Agent  
**Mode:** Demo (offline, zero credentials)

---

## Recording Tips

- Pause 1-2 seconds between scenes for editing cuts
- Total target: under 3 minutes (judges won't watch beyond 3 min)

---

## Scene 1: Introduction

**Screen:** Image file demo_0001.png showing project banner

**Narration:**
> "Security analysts spend over 60% of their time manually triaging alerts. Alibaba Blueteam is an AI-powered SecOps copilot that automates the full incident triage lifecycle — from event discovery to action proposal — on Alibaba Cloud."

---

## Scene 2: Zero-Setup Install

**Screen:** Image file demo_0002.png (@Image2) showing how to get started with the project, then image demo_0002.png which shows the installed agent skills.

**Narration:**
> "Installation takes seconds. No repository clone needed. Just run npx skills add — and all 6 agent skills with 14 demo fixtures are bundled locally."

---

## Scene 3: Confirm Skills Install

**Screen:** Image file demo_0003.png (@Image3) showing that the skills are installed in the agent harness

**Narration:**
> "Alibaba Blueteam installs six agent skills into your prefered agent harness."

---
## Scene 4: Event Discovery

**Screen:** Image file demo_0004.png (@Image4) which shows asking the agent

**Narration:**
> "Let's ask the agent to show recent security events. It can discover events across all severity levels — critical, high, medium, and low — with affected assets and timestamps."

---

## Scene 5: Event Result

**Screen:** Image demo_0005.png (@Image5) which shows the results of the ask.

**Narration:**
> "Notice the agent automatically sorts by severity and cross-references affected assets against the live inventory."

---

## Scene 6: Incident Deep-Dive

**Screen:** Image file demo_0006.png (@Image6) which shows asking the agent

**Narration:**
> "Now let's investigate a critical event. The agent performs a deep-dive analysis — extracting the full attack chain, identifying attacker IPs, correlating CVEs, and mapping to NIST CSF controls."

---

## Scene 7: Response Recommendation

**Screen:** Image demo_0007.png (@Image7) which shows the results of the ask.

**Narration:**
> "Based on the investigation, the agent recommends the least-disruptive response — blocking the attacker IP via WAF response policy. Critically, it proposes the action but requires explicit human approval before execution. This is SOC 2 CC6.8.3 compliant by design."

**Narration:**
> "The agent defaults to dry-run simulation. No state change happens without human confirmation."

---

## Scene 8: GRC Sync & Compliance

**Screen:** Image demo_0008.png (@Image8) which shows the results of the GRC Sync request

**Narration:**
> "Blueteam also integrates with GRC tools like CISO Assistant for live compliance data. The sync pipeline discovers frameworks, validates controls, and maintains an audit trail."

**Action:** Run:
```bash
GRC_MODE=demo bash skills/blueteam-autopilot-knowledge/scripts/grc-sync.sh --list
```

---

## Scene 9: Architecture Overview

**Screen:** Image demo_0009.png (@Image9) which shows the project architectual diagram

**Narration:**
> "The architecture shows the Qwen-powered core agent orchestrating 6 skills, calling 5 Alibaba Cloud services via 17 CLI scripts, with GRC MCP servers for live compliance data. Dual-mode enables zero-setup demos and production use from the same codebase."

---

## Closing

**Screen:** Image demo_0010.png which shows the project logo

**Narration:**
> "Alibaba Blueteam — intelligent security operations with human-in-the-loop guardrails."

---