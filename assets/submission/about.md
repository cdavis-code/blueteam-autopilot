# About the Project

## Inspiration

Working in security operations, I kept seeing the same pattern: talented SOC analysts burning out not because the threats were too complex, but because the *triage* was soul-crushing. Every alert required the same manual ritual. Pull context, check the asset, search the logs, cross-reference the CVE, draft the recommendation, map it to a compliance control. Repeat 200 times a day.

When Alibaba Cloud launched Agentic SOC, it solved the alert surfacing problem. But there was still a gap between "here's a list of events" and "here's what you should do about them." Track 4 (Autopilot Agent) in the Qwen Cloud Hackathon gave me the deadline to build that bridge: an AI copilot that picks up where the alert dashboard leaves off and carries an incident through investigation, response recommendation, and compliance reporting, with a human in the loop for every state-changing action.

## What it does

Security teams using Alibaba Cloud face a constant flood of Security Center alerts, WAF logs, and vulnerability reports. Manually triaging every event takes hours. Real attacks go uninvestigated in the meantime.

Alibaba Blueteam is a standalone AI agent that automates the full triage cycle:

1. **Discovers** security events from Agentic SOC and WAF
2. **Investigates** each incident with deep-dive analysis (attack chain, CVEs, attacker IPs)
3. **Recommends** the least-disruptive effective response (IP block, host isolation, vuln patch)
4. **Proposes** structured action plans for human approval
5. **Reports** with NIST CSF and SOC 2 compliance mapping
6. **Queries** live GRC data (CISO Assistant, Vanta) for compliance context during incident response

All state-changing actions require explicit human approval. SOC 2 CC6.8.3 compliant by design.

Works in two modes: `demo` (default, offline fixture data, only needs a Qwen Cloud API key) and `real` (production with live Alibaba Cloud APIs). A security analyst can be triaging events in 5 minutes with no Alibaba Cloud credentials.

## How we built it

A **standalone Python agent application** built on Qwen Cloud's OpenAI-compatible API and the **ConnectOnion** agent framework. The agent uses ConnectOnion's Agent class for tool orchestration, plugin lifecycle, and Textual TUI, with a custom `QwenCloudLLM` provider that preserves Qwen Cloud's thinking mode quality via internal streaming aggregation.

### Agent Architecture (`agent.py` + `connectonion_qwen/`)

The agent runtime uses ConnectOnion's `Agent` class with a custom LLM provider:

1. `QwenCloudLLM` sends messages + 17 tool definitions to Qwen Cloud (with internal `stream=True`)
2. Stream is aggregated internally — reasoning content, tool call arguments, and text deltas are collected into a single `LLMResponse`
3. ConnectOnion's `tool_executor` dispatches tool calls to plain Python functions
4. Results feed back as tool messages; loop repeats until final answer
5. `before_each_tool` plugin fires for state-changing tools — dry-run preview + human approval gate
6. `after_each_tool` plugin logs audit trail with output truncation

Key Qwen Cloud API features used:

| Feature | Qwen Cloud API | Usage in Agent |
|---------|----------------|----------------|
| **Function calling** | `tools` parameter with auto-generated schemas | All 17 tools as plain Python functions (type hints → JSON schema) |
| **Thinking mode** | `extra_body={"enable_thinking": true}` | Complex multi-step tool orchestration reasoning |
| **Parallel tool calls** | `parallel_tool_calls=True` | Independent queries (e.g., assets + events simultaneously) |
| **Streaming** | `stream=True` (internal aggregation) | Preserves thinking mode quality; aggregated before returning to ConnectOnion |
| **Structured output** | `response_format={"type": "json_object"}` | Formal action proposals with guaranteed valid JSON |

### Skill Layer (`skills/`)

The existing skills become the tool implementation layer:

1. **blueteam-autopilot-ops:** 17 production CLI scripts wrapping Alibaba Cloud APIs across 5 services: Security Center (SAS), WAF 3.0, Simple Log Service (SLS), VPC, and STS. Each script supports both real and demo modes transparently.

2. **blueteam-autopilot-core:** Fixtures and references. 15 JSON fixture files for demo mode, MCP tool specifications, and compliance control mappings.

3. **blueteam-autopilot-prep:** An 8-stage environment validator that checks CLI installation, credentials, RAM policies, service enablement, infrastructure, log delivery, config generation, and readiness before the agent ever touches a live API.

4. **blueteam-autopilot-knowledge:** Compliance controls (NIST CSF v2.0, SOC 2 Type II CC6), runbooks, trusted network profiles, and a GRC sync pipeline that pulls live framework data from CISO Assistant and Vanta MCP servers.

5. **blueteam-autopilot-reports:** Generates structured Markdown incident reports, action proposals, and vulnerability prioritization documents from JSON schemas and templates.

6. **alibaba-security-ops:** The origin. The standalone CLI skill from which the project evolved.

## Challenges we ran into

**API complexity.** The Security Center, WAF 3.0, and SLS APIs each have their own authentication patterns, pagination models, and versioning quirks. WAF 3.0 required a different API product name (`waf-openapi`) than expected, and SLS log queries needed a specific `From: aqs` parameter that wasn't documented in the main reference. Wrapping all 25+ API operations into clean, consistent CLI scripts took serious iteration.

**Dual-mode parity.** Making demo mode feel indistinguishable from real mode was harder than it sounds. The fixture data had to match the exact shape of live API responses, and every script needed a clean dispatch mechanism. Getting this right meant the agent's behavior is identical whether it's reading from a JSON file or a live API call.

**GRC integration with fallback.** Connecting to CISO Assistant and Vanta MCP servers for live compliance data was straightforward. Designing the graceful fallback was not. When MCP is unavailable, the agent uses locally synced compliance documents with a source-priority resolution chain. That required careful architecture to make sure the agent never stalls waiting for a GRC response.

**Human-in-the-loop without friction.** The design principle is "propose, don't execute." Implementing this across response policies, WAF rules, and vulnerability patches while keeping the workflow fluid meant thinking through every state transition. The dry-run simulation capability (show what *would* happen before asking for approval) was the key insight that made it work.

**Scope management.** The temptation to add more Alibaba Cloud services, more GRC integrations, and more response playbooks was constant. Staying focused on Track 4's core requirement, an autopilot agent that automates real-world security workflows end-to-end, meant saying no to interesting tangents and polishing what was already there.

## Accomplishments that we're proud of

**Zero-setup demo mode.** Bundling 15 JSON fixture files so the entire agent runs offline with no Alibaba Cloud credentials was one of the best design decisions. Judges and users can clone, `pip install`, add a Qwen Cloud API key, and start triaging in under 5 minutes. Demo mode is the default.

**Built on Qwen Cloud + ConnectOnion.** The standalone agent leverages Qwen Cloud's function calling, thinking mode, parallel tool calls, and structured output, delivered through the ConnectOnion framework's Agent class, plugin system, and Textual TUI. The agent isn't a wrapper around a chat API — it's a proper tool-orchestrating runtime with HITL plugins, compliance logging, and token tracking.

**GRC integration that actually works.** Connecting two live GRC MCP servers (CISO Assistant and Vanta) into the incident response workflow means compliance mapping happens during investigation, not as an afterthought. The fallback chain (live MCP, then synced documents, then bundled knowledge) keeps the agent running even when external services are down.

**17 registered tools across 4 categories.** The agent registers tools as OpenAI-format function definitions, each wrapping a production CLI script that works identically in real and demo modes. Core, WAF, response, and GRC tools are organized by function.

**SOC 2 compliance by design.** The "propose, don't execute" architecture means every state-changing action requires explicit human approval. This isn't a feature bolted on. It's the core design principle, and it made the architecture cleaner, not harder.

## What we learned

**Guardrails are a feature, not a constraint.** Designing the agent to *propose* actions rather than *execute* them actually improved the architecture. Human-in-the-loop isn't friction. It's the product.

**Demo mode changes everything for adoption.** The insight that judges (and users) need to *experience* a tool before committing to setting up credentials led to the dual-mode architecture. Bundling fixture files so the entire agent runs offline turned out to be the single most important adoption decision.

**GRC and SecOps belong in the same conversation.** Integrating live GRC data into incident response showed that compliance mapping isn't an after-the-fact report. It's real-time context that shapes the response itself.

**MCP is the right abstraction for cloud security.** Organizing 20+ tools through the Model Context Protocol gave the agent a clean, extensible interface to Alibaba Cloud's APIs without tight coupling. Adding a new tool means writing a CLI script and registering it. That's it.

## What's next for Alibaba Blueteam

**More Alibaba Cloud services.** The current skill set covers Security Center, WAF 3.0, SLS, VPC, and STS. The next wave adds Cloud Firewall, ActionTrail, and OSS security monitoring, each following the same MCP tool pattern established here.

**Automated response execution.** Today the agent proposes actions and waits for human approval. The next step is a trusted-action registry: pre-approved responses (like blocking known-bad IPs from threat intel feeds) that execute automatically, with full audit trails.

**Continuous compliance monitoring.** The current GRC integration maps incidents to compliance controls after the fact. The goal is real-time drift detection: the agent continuously compares your cloud posture against NIST CSF and SOC 2 requirements and flags gaps before they become incidents.

**Multi-cloud GRC correlation.** CISO Assistant and Vanta both support frameworks beyond what a single cloud provider covers. Extending the GRC sync pipeline to correlate controls across Alibaba Cloud, AWS, and Azure would give security teams a unified compliance view.
