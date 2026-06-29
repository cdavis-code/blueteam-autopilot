Title & Subtitle options:
1. Title: How I Built an AI Agent That Proposes Instead of Executes
   Subtitle: Designing a security operations copilot where human-in-the-loop isn't friction, it's the product.
2. Title: The "Propose, Don't Execute" Pattern for AI Agents
   Subtitle: What building a cloud security copilot taught me about guardrails, dual-mode architecture, and agent design.
3. Title: Building an AI Copilot for Cloud Security Operations
   Subtitle: A design walkthrough of an agent that triages alerts, investigates incidents, and never acts without approval.

---

## Introduction

SOC analysts don't burn out because the threats are too hard. They burn out because the triage is soul-crushing.

Every alert follows the same ritual. Pull context. Check the asset. Search the logs. Cross-reference the CVE. Draft the recommendation. Map it to a compliance control. Repeat 200 times a day. The thinking isn't hard, but it is relentless, and it leaves no time for the investigations that actually need human judgment.

When Alibaba Cloud launched Agentic SOC, it solved the alert surfacing problem. Events get surfaced, prioritized, and correlated. But there was still a gap between "here's a list of events" and "here's what you should do about them." I built **Alibaba Blueteam** to close that gap.

By the end of this article, you'll understand the three design decisions that shaped the whole project: why the agent proposes actions instead of executing them, why demo mode is the default (not an afterthought), and how the Model Context Protocol became the right abstraction for cloud security APIs.

If you'd rather watch than read, here's a 3-minute demo: [Watch on YouTube](https://www.youtube.com/watch?v=-eqQJuAFHhA)

Here's what the agent's output looks like when it finishes investigating a critical event:

![Agent triaging security events, sorted by severity with asset cross-referencing](https://raw.githubusercontent.com/cdavis-code/blueteam-autopilot/main/assets/submission/slides/demo_0005.png)

And here's what happens when it recommends a response. Notice the dry-run simulation and the explicit approval gate:

![Agent proposing a WAF IP-block response with dry-run simulation, awaiting human approval](https://raw.githubusercontent.com/cdavis-code/blueteam-autopilot/main/assets/submission/slides/demo_0007.png)

---

## The Problem We're Solving

Security teams on Alibaba Cloud face a constant stream of inputs: Security Center alerts, WAF logs, vulnerability scan results, and asset inventory changes. Each one demands the same six-step investigation before you can act. The steps are mechanical, but skipping one means missing a compliance control mapping or proposing a response that takes down a production asset.

The Alibaba Cloud APIs exist to pull this data. But calling five different services, correlating the results, checking compliance controls, and drafting a recommendation is not a single API call. It's a workflow. And workflows are where analysts drown.

The concrete failure mode: a HIGH severity WAF alert arrives at 2am. The analyst is tired. They block the attacker IP without checking the trusted network list. The IP belonged to a corporate VPN endpoint. Now they've cut off remote access for a branch office, and the incident they were investigating just got a lot more complicated.

That failure is not a training problem. It's a workflow problem. The analyst needed a system that cross-references the IP before proposing the block, shows the recommendation with the evidence, and waits for a human to say "go."

---

## The Design Philosophy

I had a choice about what the agent should be allowed to do. It could be fully autonomous: see an attack, block the IP, generate the report. Or it could be a read-only assistant: surface information but never touch anything.

Both are wrong for different reasons. Full autonomy means a bad recommendation at 2am becomes a bad action at 2am. Read-only means the analyst still does all the thinking, which is the thing they're burning out on.

The middle path is what I call "propose, don't execute." The agent does all the investigation, correlation, and recommendation work. But every state-changing action (blocking an IP, isolating a host, patching a vulnerability) is packaged as a structured proposal that requires explicit human approval before anything happens.

> **Design principle:** An agent that proposes actions is more useful than one that executes them, because the proposal is reviewable, auditable, and reversible. Execution is none of those things until a human says go.

This is also SOC 2 CC6.8.3 compliant by design. The approval gate isn't a feature I bolted on. It's the core architecture, and it made everything else cleaner.

---

## Project Overview

Alibaba Blueteam is a set of 6 modular agent skills orchestrated by a Qwen-powered core agent. It installs via `npx skills add` with no repository clone and no build step.

```bash
# Install and run (demo mode is the default, zero config)
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
```

The 6 skills, in the order you'd meet them:

| Skill | Role |
|-------|------|
| `blueteam-autopilot-core` | The brain. Role definition, 5-behavior triage cycle, guardrails. |
| `blueteam-autopilot-ops` | The hands. 17 CLI scripts wrapping Alibaba Cloud APIs. |
| `blueteam-autopilot-prep` | The gatekeeper. 8-stage environment validator (real mode only). |
| `blueteam-autopilot-knowledge` | The memory. Compliance controls, runbooks, GRC sync pipeline. |
| `blueteam-autopilot-reports` | The voice. Structured Markdown reports from JSON schemas. |
| `alibaba-security-ops` | The origin. The standalone CLI skill the project evolved from. |

Here's the architecture at a glance:

![Architecture diagram: Qwen-powered core agent orchestrating 6 skills, 5 Alibaba Cloud services, and GRC MCP servers](https://raw.githubusercontent.com/cdavis-code/blueteam-autopilot/main/assets/submission/slides/demo_0009.png)

---

## The 5-Behavior Triage Cycle

The core agent follows a fixed sequence for every incident. This wasn't arbitrary. Each behavior produces the input the next one needs, and the ordering ensures the agent never proposes an action before it has investigated the evidence.

```
Incident Discovery
    ↓
Incident Deep-Dive
    ↓
Recommendation Synthesis
    ↓
Action Proposal (requires human approval)
    ↓
Reporting
```

### Behavior 1: Incident Discovery

The agent starts by establishing context. It calls `get_account_context` to learn the region and Security Center edition, then `list_assets` to discover what cloud resources exist. Only then does it fetch events with `list_security_events`.

This order matters. If you fetch events before knowing your assets, you can't cross-reference "which of my things is affected?" and you can't apply the prioritization rule that SOC 2 scope assets get elevated severity.

### Behavior 2: Incident Deep-Dive

Given an event ID, the agent pulls the full attack chain, correlates alerts across data sources (WAF, CWPP, Cloud Firewall), and identifies the exploit vector. The critical step here is the trusted network cross-reference.

If an attacker IP matches a known corporate VPN or monitoring endpoint, the agent flags it as "Potentially Compromised Internal Asset" instead of proposing a perimeter block. This is the specific failure mode I described earlier, and it's why the cross-reference happens before the recommendation, not after.

### Behavior 3: Recommendation Synthesis

The agent matches the incident profile to available response policies. WAF attacks (SQLi, XSS, LFI) map to IP blocking policies. Host-level threats map to isolation policies. If nothing matches, it recommends creating a new policy.

The mitigation principle comes from NIST CSF RS.RP-1: balance operational availability against data risk. Perimeter containment via IP ACL is authorized for known-malicious behavior, but the agent always picks the least-disruptive option that works.

### Behavior 4: Action Proposal

This is where "propose, don't execute" becomes concrete. The agent generates a structured JSON proposal:

```json
// skills/blueteam-autopilot-core/BEHAVIORS.md - the proposal contract
{
  "reasoning": "Why this action is needed",
  "recommendedPolicyId": "pol-xxx",
  "expectedEffects": "What will change",
  "rollbackPlan": "How to undo if issues arise",
  "riskLevel": "LOW | MEDIUM | HIGH",
  "requiresApproval": true
}
```

The `requiresApproval` field is always `true`. The agent never calls `execute_response_policy` without explicit human confirmation. Before proposing, it runs pre-flight checks: trusted network cross-reference, dry-run simulation by default, and compliance control references in the reasoning.

> **Design principle:** The proposal JSON is the unit of accountability. Every state-changing action has one, and every one has a rollback plan. If you can't write the rollback, you don't understand the action well enough to propose it.

The tradeoff here is latency. Proposing instead of executing adds a human round-trip. For known-bad IPs from threat intelligence feeds, that round-trip feels unnecessary. The roadmap includes a trusted-action registry for pre-approved responses that auto-execute with audit trails. But for now, the approval gate is non-negotiable.

### Behavior 5: Reporting

The agent produces a Markdown incident report with six sections: summary, attack chain, compliance mapping, recommended action, rollback plan, and audit trail. The compliance mapping references NIST CSF and SOC 2 controls by ID, which means the report is ready for auditor review without someone manually adding the control references after the fact.

---

## Dual-Mode Architecture: Demo First

Here's a practical problem with security tools: you can't show them to anyone without credentials, cloud accounts, and working infrastructure. Judges at hackathons won't install your thing. Users evaluating tools won't commit 30 minutes to configuration before seeing if it works.

The obvious approach is to build the real thing first and add a demo mode later if someone asks. The problem with that approach is the demo mode always ends up being a different code path. It shows a subset of features, the responses don't match the real API shape, and anyone who tried the demo gets a misleading impression of what the tool does.

I decided to make demo mode the default and the real thing an opt-in. Same scripts, same agent behavior, different data source. The dispatch happens in every CLI script with a single conditional:

```bash
# skills/blueteam-autopilot-ops/scripts/list-events.sh - mode dispatch
if [ "${SECURITY_CENTER_MODE:-demo}" = "demo" ]; then
  FIXTURE_DIR="$(dirname "$SCRIPT_DIR")/../blueteam-autopilot-core/fixtures"
  FIXTURE_FILE="$FIXTURE_DIR/events_recent.json"
  if [ -f "$FIXTURE_FILE" ]; then
    cat "$FIXTURE_FILE"
    exit 0
  fi
fi
# ... real mode: call aliyun CLI below
```

The `${SECURITY_CENTER_MODE:-demo}` default means if no `.env` file exists, the script runs in demo mode. Fifteen JSON fixture files provide realistic data: 6 security events across all severity levels, full attack chains with CVEs, 5 response policies, WAF attack logs, and compliance mappings.

> **Design principle:** Make the zero-configuration path the path of least resistance. If demo mode requires an environment variable to activate, most people will never see it. If real mode requires a `.env` file, the people who need it already know they need it.

The cost of this approach is upfront work on the fixtures. Each JSON file had to match the exact shape of the corresponding API response. The agent's behavior must be identical whether it reads from a file or a live API call. That constraint took more effort than building a demo separately would have, but it means the demo is not a toy. It's the real agent with different data.

To switch to real mode with live Alibaba Cloud APIs:

```bash
cat > .env << 'EOF'
ALIBABA_ACCESS_KEY_ID="LTAI5t..."
ALIBABA_ACCESS_KEY_SECRET="HkfZ..."
SECURITY_CENTER_MODE=real
EOF
# ALIBABA_REGION is auto-discovered from aliyun CLI config (set ALIBABA_REGION in .env to override)
```

---

## MCP as the Tool Abstraction

The Model Context Protocol gave the agent a clean interface to Alibaba Cloud's APIs. Each tool is a function the agent can call: `list_security_events`, `get_security_event_detail`, `list_waf_top_rules`, `execute_response_policy`, and so on. Behind each tool is a CLI script that handles authentication, pagination, and error reporting.

Here's what I like about this pattern: adding a new capability means writing a CLI script and registering it as a tool. That's it. The agent doesn't need to know about API versioning quirks or authentication details. The script handles that. The agent just calls the tool and gets structured data back.

The project wraps 25+ API operations across 5 Alibaba Cloud services (Security Center, WAF 3.0, SLS, VPC, STS) into 17 CLI scripts. Each script follows the same pattern: load environment, check mode, dispatch to fixture or live API, format output.

The alternative would be to call the Alibaba Cloud APIs directly from the agent prompt. That's faster to build for one or two operations, but it puts API authentication logic, error handling, and pagination code into the prompt context. The prompt gets long, the model gets confused, and adding a new operation means editing the prompt. With MCP tools, the prompt stays focused on security reasoning and the scripts handle the plumbing.

> **Design principle:** Separate the agent's reasoning from the system's plumbing. The prompt should think about attacks and compliance. The scripts should think about APIs and authentication.

The gotcha: the Alibaba Cloud APIs have quirks that aren't obvious from the documentation. WAF 3.0 uses a different API product name (`waf-openapi`) than you'd expect. SLS log queries need a `From: aqs` parameter that isn't mentioned in the main reference. Each quirk lives in exactly one script, which is the right place for it.

---

## Compliance During Investigation, Not After

Most compliance workflows are after-the-fact. You handle the incident, then someone writes a report mapping it to NIST CSF controls or SOC 2 criteria. The mapping is a paperwork exercise, disconnected from the actual investigation.

Alibaba Blueteam does this differently. The agent references compliance controls during the investigation itself. When it correlates attack signals in Behavior 2, it maps them to NIST CSF DE.AE-2 (Anomaly Detection). When it synthesizes a recommendation in Behavior 3, it aligns with RS.RP-1 (Response Planning). By the time it writes the report, the compliance mapping is already there because it shaped the response.

The knowledge skill provides the compliance data through a three-tier fallback chain:

1. Live GRC MCP servers (CISO Assistant, Vanta) for real-time control status
2. Locally synced compliance documents when MCP is unavailable
3. Bundled knowledge fixtures as the last resort

```
GRC MCP Server (live)
    │
    ▼ unavailable
Synced local documents
    │
    ▼ missing
Bundled knowledge fixtures
```

> **Design principle:** Compliance mapping should shape the response, not describe it after the fact. If the control doesn't affect the agent's reasoning, citing it in the report is just paperwork.

The tradeoff is that the agent's prompt needs to carry condensed compliance context at all times. This adds to the prompt length and means every behavior definition references specific control IDs. The alternative is to fetch compliance documents on demand for every event, but that adds latency and makes the agent's reasoning depend on an external service that might be down.

---

## Conclusion

Three design principles shaped this project, and they're the ones I'd carry to the next agent build:

**Propose, don't execute.** An agent that packages its recommendations as reviewable proposals is more useful than one that acts autonomously. The proposal is auditable, reversible, and SOC 2 compliant by construction. The cost is a human round-trip, which is the point.

**Demo first, real second.** Making the zero-configuration path the default means more people see the real agent, not a stripped-down demo. The fixture work is upfront, but the adoption payoff is worth it.

**Separate reasoning from plumbing.** The agent prompt thinks about attacks and compliance. The CLI scripts think about APIs and authentication. MCP tools are the boundary between them, and adding a new capability means writing a script, not editing a prompt.

If you want to try it:

```bash
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
```

No Alibaba Cloud account needed. No credentials. No `.env` file. Demo mode is the default. You'll be triaging events in under 5 minutes.

**GitHub:** [github.com/cdavis-code/blueteam-autopilot](https://github.com/cdavis-code/blueteam-autopilot)

**Demo Video:** [Watch on YouTube](https://www.youtube.com/watch?v=-eqQJuAFHhA)

---

*Suggested Medium tags:* Security Operations, AI Agents, Alibaba Cloud, Model Context Protocol, SOC Automation
