# Demo Video Script — Alibaba Blueteam

**Target duration:** 2:45  
**Track:** Track 4 — Autopilot Agent  
**Mode:** Demo (offline, zero credentials)

---

## Pre-Recording Setup

1. Open terminal at project root with dark theme, large font (16pt+)
2. Run: `echo 'SECURITY_CENTER_MODE=demo' > .env`
3. Have architecture diagram open in browser tab
4. Clear terminal: `clear`

---

## Scene 1: Introduction (0:00–0:20)

**Screen:** Terminal showing project root directory

**Narration:**
> "Security analysts spend over 60% of their time manually triaging alerts. Alibaba Blueteam is an AI-powered SecOps copilot that automates the full incident triage lifecycle — from event discovery to action proposal — on Alibaba Cloud."

**Action:** Scroll through the project directory tree to show the skill structure.

---

## Scene 2: Zero-Setup Install (0:20–0:40)

**Screen:** Terminal

**Narration:**
> "Installation takes seconds. No repository clone needed. Just run npx skills add — and all 6 agent skills with 14 demo fixtures are bundled locally."

**Action:** Type and run:
```bash
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
echo 'SECURITY_CENTER_MODE=demo' > .env
```

**Show:** The skill installation output.

---

## Scene 3: Event Discovery (0:40–1:10)

**Screen:** Terminal with agent harness

**Narration:**
> "Let's ask the agent to show recent security events. It discovers 6 events across all severity levels — critical, high, medium, and low — with affected assets and timestamps."

**Action:** Ask the agent:
```
"Show me recent security events"
```

**Show:** Agent response listing events with severity, titles, and affected assets.

**Narration:**
> "Notice the agent automatically sorts by severity and cross-references affected assets against the live inventory."

---

## Scene 4: Incident Deep-Dive (1:10–1:45)

**Screen:** Terminal

**Narration:**
> "Now let's investigate a critical event. The agent performs a deep-dive analysis — extracting the full attack chain, identifying attacker IPs, correlating CVEs, and mapping to NIST CSF controls."

**Action:** Ask the agent:
```
"Investigate event evt-demo-20260614-001"
```

**Show:** Agent response with:
- Attack chain stages
- Attacker IPs and geolocation
- CVE identifiers
- NIST CSF control mapping (DE.AE-2, PR.PT-4)
- SOC 2 CC6.8 compliance reference

---

## Scene 5: Response Recommendation (1:45–2:15)

**Screen:** Terminal

**Narration:**
> "Based on the investigation, the agent recommends the least-disruptive response — blocking the attacker IP via WAF response policy. Critically, it proposes the action but requires explicit human approval before execution. This is SOC 2 CC6.8.3 compliant by design."

**Action:** Ask the agent:
```
"What response do you recommend?"
```

**Show:** Agent response with:
- Recommended action (IP block via WAF)
- Dry-run simulation of the policy execution
- Rollback plan
- Human approval checkpoint

**Narration:**
> "The agent defaults to dry-run simulation. No state change happens without human confirmation."

---

## Scene 6: GRC Sync & Compliance (2:15–2:35)

**Screen:** Terminal

**Narration:**
> "Blueteam also integrates with GRC tools like CISO Assistant for live compliance data. The sync pipeline discovers frameworks, validates controls, and maintains an audit trail."

**Action:** Run:
```bash
GRC_MODE=demo bash skills/blueteam-autopilot-knowledge/scripts/grc-sync.sh --list
```

**Show:** Policy sync status output showing NIST CSF and SOC2 policies with GRC provider config.

---

## Scene 7: Architecture Overview (2:35–2:50)

**Screen:** Architecture diagram in browser

**Narration:**
> "The architecture shows the Qwen-powered core agent orchestrating 6 skills, calling 5 Alibaba Cloud services via 17 CLI scripts, with GRC MCP servers for live compliance data. Dual-mode enables zero-setup demos and production use from the same codebase."

**Action:** Point to key components on the diagram.

---

## Closing (2:50–2:55)

**Screen:** Terminal or title card

**Narration:**
> "Alibaba Blueteam — intelligent security operations with human-in-the-loop guardrails."

---

## Recording Tips

- Use `script` command or asciinema for terminal recording
- Keep mouse movements smooth and deliberate
- Pause 1-2 seconds between scenes for editing cuts
- Total target: under 3 minutes (judges won't watch beyond 3 min)
- Upload to YouTube as unlisted first, verify playback, then make public
