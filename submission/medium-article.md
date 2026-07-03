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

If you'd rather watch than read, here's a 3-minute demo: [Watch on YouTube](https://youtu.be/v0by8nknCQc)

Here's what the agent's output looks like when it finishes investigating a critical event:

![Agent triaging security events, sorted by severity with asset cross-referencing](https://raw.githubusercontent.com/cdavis-code/blueteam-autopilot/main/submission/slides/demo_0005.png)

And here's what happens when it recommends a response. Notice the dry-run simulation and the explicit approval gate:

![Agent proposing a WAF IP-block response with dry-run simulation, awaiting human approval](https://raw.githubusercontent.com/cdavis-code/blueteam-autopilot/main/submission/slides/demo_0007.png)

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

Alibaba Blueteam is available in two forms: a **standalone Python agent** built on Qwen Cloud and the ConnectOnion framework, and a set of **7 modular agent skills** for AI IDE harnesses like Qoder or Cursor.

### Option A: Standalone Agent (Recommended)

A production-ready agent with an interactive Textual TUI, thinking mode, and function calling:

```bash
# Clone and install
git clone https://github.com/cdavis-code/blueteam-autopilot.git
cd blueteam-autopilot
pip install -r requirements.txt

# Configure your Qwen Cloud API key
cp .env.example .env
# Edit .env: DASHSCOPE_API_KEY="sk-..."

# Run the agent
python blueteam.py
```

The standalone agent provides a full terminal UI with status bar, thinking indicator, tool progress, token/cost tracking, and slash commands (`/help`, `/clear`, `/model`, `/mcp`, `/quit`). It uses ConnectOnion's plugin system for HITL approval gates and compliance audit logging.

### Option B: Skills for AI IDE Harness

Install as skills for Qoder, Cursor, or other AI IDEs:

```bash
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
```

Both options use the same 19 tools, 17 CLI scripts, and 15 demo fixtures. The choice is whether you want the standalone agent with its purpose-built TUI, or the flexibility of your preferred AI IDE.

The 7 skills, in the order you'd meet them:

| Skill | Role |
|-------|------|
| `blueteam-autopilot-core` | The brain. Role definition, 5-behavior triage cycle, guardrails. |
| `blueteam-autopilot-ops` | The hands. 17 CLI scripts wrapping Alibaba Cloud APIs. |
| `blueteam-autopilot-prep` | The gatekeeper. 8-stage environment validator (real mode only). |
| `blueteam-autopilot-knowledge` | The memory. Compliance controls, runbooks, GRC sync pipeline. |
| `blueteam-autopilot-reports` | The voice. Structured Markdown reports from JSON schemas. |
| `blueteam-autopilot-compat` | The watchdog. CLI compatibility validator — detects breaking changes in `aliyun` commands and response structures. |
| `alibaba-security-ops` | The origin. The standalone CLI skill the project evolved from. |

Here's the architecture at a glance:

![Architecture diagram: Qwen-powered core agent orchestrating 7 skills, 6 Alibaba Cloud services, and GRC MCP servers](https://raw.githubusercontent.com/cdavis-code/blueteam-autopilot/main/submission/slides/demo_0009.png)

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

The agent produces a comprehensive incident response report using the `generate_incident_report` tool — the 19th tool in the agent's toolkit. This tool aggregates all investigation data (event detail, alerts, assets, vulnerabilities, WAF logs, compliance controls) into a structured context package, then synthesizes a Markdown report with eight sections: executive summary, blast radius, attack chain timeline, affected assets, confidence rating, recommended actions, rollback plan, and audit trail.

The report schema is enforced by Pydantic models (`IncidentReport`, `AttackChainStage`, `AffectedAsset`, `TimelineEvent`, `RecommendedAction`, `AuditEntry`), ensuring the output is ready for ticket systems or compliance audits without manual schema validation. The compliance mapping references NIST CSF and SOC 2 controls by ID, which means the report is ready for auditor review without someone manually adding the control references after the fact.

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
# 1. Configure aliyun CLI credentials (stored in ~/.aliyun/config.json)
aliyun configure

# 2. Add Qwen Cloud API key and enable real mode in .env
cat > .env << 'EOF'
DASHSCOPE_API_KEY="sk-..."
SECURITY_CENTER_MODE=real
EOF
# ALIBABA_REGION is auto-discovered from aliyun CLI config (set ALIBABA_REGION in .env to override)
```

---

## Headless Mode: Automation and Cron Jobs

Sometimes you don't want an interactive agent. You want a scheduled job that checks for new critical events every hour and logs the results. Or a CI pipeline that runs the agent against a pull request's security impact analysis.

The standalone agent supports headless execution via the `--prompt` flag or stdin piping:

```bash
# Single prompt, output to stdout
python blueteam.py --prompt "Show me recent security events"

# Pipe from stdin
echo "Investigate event evt-demo-20260614-001" | python blueteam.py

# Combine both (concatenated with newline)
python blueteam.py --prompt "Context: WAF analysis" <<< "for IP 1.2.3.4"

# Cron job: check events every hour
0 * * * * /path/to/blueteam.py --prompt "Check for new CRITICAL events" >> /var/log/blueteam.log 2>&1
```

In headless mode, the agent runs with `quiet=True` (no TUI, no banner), processes a single prompt, prints the response to stdout, and exits. State-changing tools are auto-rejected since there's no interactive approval possible. Errors go to stderr with a non-zero exit code.

This pattern turns the agent from an interactive copilot into a batch processor. The same investigation logic, the same compliance checks, the same structured output — just without the human in the loop. For monitoring dashboards or automated triage pipelines, headless mode means the agent can run on a schedule and feed results into your existing alerting infrastructure.

---

## MCP as the Tool Abstraction

The Model Context Protocol gave the agent a clean interface to Alibaba Cloud's APIs. Each tool is a function the agent can call: `list_security_events`, `get_security_event_detail`, `list_waf_top_rules`, `execute_response_policy`, and so on. Behind each tool is a CLI script that handles authentication, pagination, and error reporting.

Here's what I like about this pattern: adding a new capability means writing a CLI script and registering it as a tool. That's it. The agent doesn't need to know about API versioning quirks or authentication details. The script handles that. The agent just calls the tool and gets structured data back.

The project wraps 26+ API operations across 6 Alibaba Cloud services (Security Center, WAF 3.0, SLS, Cloud SIEM, VPC, STS) into 19 tools. Each script follows the same pattern: load environment, check mode, dispatch to fixture or live API, format output.

### External MCP Server Integration

Beyond the built-in tools, the agent also connects to external MCP servers at startup for live GRC data. The `connectonion_qwen/mcp.py` module provides an MCP client bridge that:

1. Reads server configurations from `.mcp.json` (with `${VAR}` environment variable interpolation)
2. Connects via stdio or SSE transports with per-server timeouts
3. Dynamically discovers tools and wraps them as ConnectOnion-compatible Python functions
4. Gracefully degrades when servers are unreachable — synced knowledge documents serve as fallback

The `.mcp.json` includes presets for CISO Assistant (live GRC framework data), Vanta (compliance posture), Alibaba Cloud Ops (extended cloud operations), DFIR-IRIS (incident response ticketing), and Atlassian (Jira/Confluence). Use `/mcp` in the TUI to see per-server connection status and tool count.

This means the agent can query live compliance data during an investigation — checking whether a control is actually implemented, not just whether the documentation says it should be.

The alternative would be to call the Alibaba Cloud APIs directly from the agent prompt. That's faster to build for one or two operations, but it puts API authentication logic, error handling, and pagination code into the prompt context. The prompt gets long, the model gets confused, and adding a new operation means editing the prompt. With MCP tools, the prompt stays focused on security reasoning and the scripts handle the plumbing.

> **Design principle:** Separate the agent's reasoning from the system's plumbing. The prompt should think about attacks and compliance. The scripts should think about APIs and authentication.

The gotcha: the Alibaba Cloud APIs have quirks that aren't obvious from the documentation. WAF 3.0 uses a different API product name (`waf-openapi`) than you'd expect. SLS log queries need a `From: aqs` parameter that isn't mentioned in the main reference. Cloud SIEM (response policies) uses PascalCase action names (`ListAutomateResponseConfigs`) with a required `--Version 2022-06-16` flag, and only works on Enterprise edition. Each quirk lives in exactly one script, which is the right place for it.

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

**Standalone Agent** (recommended — full TUI with thinking mode):
```bash
git clone https://github.com/cdavis-code/blueteam-autopilot.git
cd blueteam-autopilot
pip install -r requirements.txt
cp .env.example .env
# Edit .env: DASHSCOPE_API_KEY="sk-..."
python blueteam.py
```

**AI IDE Harness** (Qoder, Cursor, etc.):
```bash
mkdir secops && cd secops
npx skills add cdavis-code/blueteam-autopilot --skill '*' -y
```

**Headless / Cron** (non-interactive):
```bash
python blueteam.py --prompt "Show me recent security events"
```

No Alibaba Cloud account needed for demo mode. Demo mode is the default. You'll be triaging events in under 5 minutes.

**GitHub:** [github.com/cdavis-code/blueteam-autopilot](https://github.com/cdavis-code/blueteam-autopilot)

**Demo Video:** [Watch on YouTube](https://youtu.be/v0by8nknCQc)

---

*Suggested Medium tags:* Security Operations, AI Agents, Alibaba Cloud, Model Context Protocol, SOC Automation
