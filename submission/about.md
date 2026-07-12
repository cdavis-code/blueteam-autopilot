# About the Project

## Inspiration

Working in security operations, I kept seeing the same pattern: talented SOC analysts burning out not because the threats were too complex, but because the *triage* was soul-crushing. Every alert required the same manual ritual. Pull context, check the asset, search the logs, cross-reference the CVE, draft the recommendation, map it to a compliance control. Repeat 200 times a day.

When Alibaba Cloud launched Agentic SOC, it solved the alert surfacing problem. But there was still a gap between "here's a list of events" and "here's what you should do about them." Track 4 (Autopilot Agent) in the Qwen Cloud Hackathon gave me the deadline to build that bridge: an AI copilot that picks up where the alert dashboard leaves off and carries an incident through investigation, response recommendation, and compliance reporting, with a human in the loop for every state-changing action.

## What it does

Security teams using Alibaba Cloud face a constant flood of Security Center alerts, WAF logs, and vulnerability reports. Manually triaging every event takes hours. Real attacks go uninvestigated in the meantime.

Alibaba Blueteam is a standalone AI agent that automates the full triage cycle. While the interactive TUI is great for development and ad-hoc investigations, the primary production deployment is the autonomous SOC daemon (`--daemon`), which continuously monitors, triages, and escalates without human intervention.

1. **Discovers** security events from Agentic SOC and WAF
2. **Investigates** each incident with deep-dive analysis (attack chain, CVEs, attacker IPs)
3. **Recommends** the least-disruptive effective response (IP block, host isolation, vuln patch)
4. **Proposes** structured action plans for human approval
5. **Reports** with NIST CSF and SOC 2 compliance mapping, including blast radius, investigation timeline, and confidence ratings
6. **Queries** live GRC data (CISO Assistant, Vanta, Alibaba Cloud) for compliance context during incident response
7. **Discovers tools dynamically** from external MCP servers at startup, extending the agent's capabilities without code changes
8. **Hunts threats proactively** via a 4-phase workflow (collect → analyze → correlate → report) with external correlation
9. **Audits compliance posture** via a 4-phase workflow (inventory → map → evidence → report) with control gap analysis
10. **Monitors autonomously** as a daemon — continuously scanning for new alerts, auto-triaging by severity, and escalating only high-severity findings
11. **Remembers past incidents** — vector embeddings (DashScope text-embedding-v3) enable cross-incident similarity search ("Have we seen this before?")
12. **Writes files to disk** — save threat reports, investigation notes, and any text content via the `write_file` tool (with HITL approval)

All state-changing actions require explicit human approval. SOC 2 CC6.8.3 compliant by design.

Works in two modes: `demo` (default, offline fixture data, only needs a Qwen Cloud API key) and `real` (production with live Alibaba Cloud APIs). A security analyst can be triaging events in 5 minutes with no Alibaba Cloud credentials.

**Cron and automation ready.** The agent runs non-interactively via `--prompt` flag or piped stdin, making it suitable for scheduled security checks, CI/CD pipelines, and scripted workflows. Output goes to stdout for clean redirection; errors go to stderr with non-zero exit codes.

**Autonomous SOC daemon.** Run `python blueteam.py --daemon --interval 60` to deploy the agent as a continuous monitoring daemon. It polls for new alerts on a configurable interval, auto-triages by severity, checks similarity against institutional memory, and escalates only CRITICAL/HIGH findings to the console. Graceful SIGINT/SIGTERM shutdown with uptime summary.

## How we built it

A **standalone Python agent application** built on Qwen Cloud's OpenAI-compatible API and the **ConnectOnion** agent framework. The agent uses ConnectOnion's Agent class for tool orchestration, plugin lifecycle, and Textual TUI, with a custom `QwenCloudLLM` provider that preserves Qwen Cloud's thinking mode quality via internal streaming aggregation.

### Multi-Agent Workflow Engine (`workflows/`)

The v3.0 architecture introduces a declarative workflow engine that orchestrates specialist agents for complex investigations. Each workflow is defined as a WORKFLOW.md file with YAML frontmatter specifying phases, personas, and restricted tool sets per phase. The engine creates scoped Agent instances per phase with phase-specific system prompts.

Five specialist workflows ship with the agent:

| Workflow | Phases | Purpose |
|----------|--------|--------|
| `incident-response` | 5 | Reactive incident handling (discovery → deep_dive → recommendation → action → report) |
| `iam-forensic` | 4 | IAM security audit with credential risk scoring (discovery → analysis → remediation → persist) |
| `threat-hunt` | 4 | Proactive threat hunting with external correlation (collect → analyze → correlate → report) |
| `compliance-audit` | 4 | Compliance gap analysis with evidence collection (inventory → map → evidence → report) |
| `continuous-monitor` | 3 | Autonomous SOC monitoring driven by daemon loop (scan → triage → escalate) |

The main agent auto-delegates to workflows for investigations while handling quick single-tool queries directly. The system prompt was slimmed from 188 lines to ~88 lines — detailed behavior instructions live in WORKFLOW.md phase instructions.

### Vector Embeddings (`connectonion_qwen/embeddings.py`)

Universal incident embeddings using DashScope text-embedding-v3 (1024-dim in real mode, 64-dim deterministic hash fallback in demo mode). All 5 workflows auto-store findings via `store_incident_memory`, building institutional memory. The `search_similar_incidents` tool enables cross-incident pattern matching — "Have we seen this before?" — with cosine similarity search against all stored embeddings in a local SQLite database (`data/blueteam.db`).

### Autonomous SOC Daemon (`--daemon`)

The agent runs as a continuous monitoring daemon: `python blueteam.py --daemon --interval 60`. Each tick executes the `continuous-monitor` workflow — scanning for new events since the last check, triaging by severity, checking similarity against past incidents, and escalating only CRITICAL/HIGH findings. Monitor state (last check timestamp, tick count, escalation count) persists in the database across restarts. Graceful SIGINT/SIGTERM shutdown with uptime summary.

### Agent Architecture (`blueteam.py` + `connectonion_qwen/`)

The agent runtime uses ConnectOnion's `Agent` class with a custom LLM provider. It supports two execution modes:

- **Interactive TUI** — Full Textual-based terminal UI with status bar, thinking indicator, tool progress, token/cost tracking, and slash commands
- **Headless/Cron mode** — Non-interactive execution via `--prompt` flag or piped stdin. Creates agent with `quiet=True` (no TUI, no banner), runs a single prompt, prints response to stdout, and exits cleanly with graceful error handling

The agent processing flow:

1. `QwenCloudLLM` sends messages + 40 built-in tool definitions to Qwen Cloud (with internal `stream=True`), plus any dynamically discovered MCP tools
2. Stream is aggregated internally — reasoning content, tool call arguments, and text deltas are collected into a single `LLMResponse`
3. ConnectOnion's `tool_executor` dispatches tool calls to plain Python functions
4. Results feed back as tool messages; loop repeats until final answer
5. `before_each_tool` plugin fires for state-changing tools — dry-run preview + human approval gate
6. `after_each_tool` plugin logs audit trail with output truncation

Key Qwen Cloud API features used:

| Feature | Qwen Cloud API | Usage in Agent |
|---------|----------------|----------------|
| **Function calling** | `tools` parameter with auto-generated schemas | All 40 built-in tools + dynamic MCP tools as plain Python functions (type hints → JSON schema) |
| **Thinking mode** | `extra_body={"enable_thinking": true}` | Complex multi-step tool orchestration reasoning |
| **Parallel tool calls** | `parallel_tool_calls=True` | Independent queries (e.g., assets + events simultaneously) |
| **Streaming** | `stream=True` (internal aggregation) | Preserves thinking mode quality; aggregated before returning to ConnectOnion |
| **Structured output** | `response_format={"type": "json_object"}` | Formal action proposals with guaranteed valid JSON |

### Security & Prompt Injection Defense

Since the agent processes external data from Security Center, WAF logs, and MCP servers, every tool result is potentially adversarial. The agent implements a three-layer defense against prompt injection:

1. **Boundary markers** — Every tool result is wrapped in `[TOOL OUTPUT START]` / `[TOOL OUTPUT END]` delimiters by the compliance logger plugin. The system prompt explicitly instructs the model to treat everything between these markers as untrusted data — never as instructions, role assignments, or override commands.

2. **Pattern-based input filtering** — Before boundary wrapping, the compliance logger scans tool output against 15 configurable regex patterns loaded from `injection_patterns.json`. Patterns are classified by severity: critical (role hijack, fake system prompts, boundary marker cloning) triggers full content rejection; high (auto-execution claims, HITL bypass instructions, credential exfil attempts) triggers in-place redaction; medium (data exfil commands, encoded payloads) triggers audit logging. All detections emit timestamped audit entries with full match context.

3. **System prompt guardrails** — The agent's system prompt contains explicit instructions to treat all tool output as untrusted data, never interpret field values as instructions, and flag text resembling commands (`STOP`, `execute`, `override`, `pre-authorized`) as potential injection attempts.

Workflow phase agents inherit these defenses: phases that declare `requires-hitl: true` in their WORKFLOW.md frontmatter receive the HITL approval plugin, ensuring state-changing tools require operator confirmation even when executed by sub-agents. See `SECURITY.md` for the full security control reference.

### MCP Server Integration (`connectonion_qwen/mcp.py`)

External MCP servers are connected at startup via a background async event loop bridge:

1. Reads `.mcp.json` (or `MCP_CONFIG_PATH`) with `${VAR}` environment variable interpolation
2. Connects to each server via stdio or SSE transport with per-server configurable timeouts
3. MCP tool schemas are dynamically converted to Python type hints and `inspect.Signature` objects
4. Each MCP tool becomes a ConnectOnion-compatible function — indistinguishable from built-in tools
5. Unreachable servers are skipped with a warning; locally synced knowledge documents serve as fallback
6. `/mcp` slash command shows per-server connection status and tool counts
7. Clean session lifecycle management — sessions are entered via `__aenter__()` and exited on shutdown, preventing orphaned subprocesses and `BrokenPipeError` cascades

### Report Generation (`connectonion_qwen/report_models.py`)

Structured incident response reports are generated via Pydantic models:

- `IncidentReport` — top-level report with severity, AI summary, root cause, business impact
- `AttackChainStage` — attack chain reconstruction with evidence per stage
- `AffectedAsset` — impacted assets with criticality and SOC 2 scope tags
- `TimelineEvent` — chronological investigation reconstruction with data sources
- `RecommendedAction` — prioritized response actions with policy IDs and risk levels
- `AuditEntry` — complete audit trail of tool calls made during investigation

### Skill Layer (`skills/`)

The existing skills become the tool implementation layer:

1. **blueteam-autopilot-ops:** 31 production CLI scripts wrapping Alibaba Cloud APIs across 7 services: Security Center (SAS), WAF 3.0, Simple Log Service (SLS), VPC, STS, RAM, and Cloud SIEM. Each script supports both real and demo modes transparently.

2. **blueteam-autopilot-core:** Fixtures and references. 23 JSON fixture files for demo mode, MCP tool specifications, and compliance control mappings.

3. **blueteam-autopilot-prep:** An 8-stage environment validator that checks CLI installation, credentials, RAM policies, service enablement, infrastructure, log delivery, config generation, and readiness before the agent ever touches a live API.

4. **blueteam-autopilot-knowledge:** Compliance controls (NIST CSF v2.0, SOC 2 Type II CC6), runbooks, trusted network profiles, and a GRC sync pipeline that pulls live framework data from CISO Assistant and Vanta MCP servers.

5. **blueteam-autopilot-reports:** Generates structured Markdown incident reports, action proposals, and vulnerability prioritization documents from JSON schemas and templates.

## Challenges we ran into

**API complexity.** The Security Center, WAF 3.0, and SLS APIs each have their own authentication patterns, pagination models, and versioning quirks. WAF 3.0 required a different API product name (`waf-openapi`) than expected, and SLS log queries needed a specific `From: aqs` parameter that wasn't documented in the main reference. Wrapping all 25+ API operations into clean, consistent CLI scripts took serious iteration.

**Dual-mode parity.** Making demo mode feel indistinguishable from real mode was harder than it sounds. The fixture data had to match the exact shape of live API responses, and every script needed a clean dispatch mechanism. Getting this right meant the agent's behavior is identical whether it's reading from a JSON file or a live API call.

**GRC integration with fallback.** Connecting to CISO Assistant and Vanta MCP servers for live compliance data was straightforward. Designing the graceful fallback was not. When MCP is unavailable, the agent uses locally synced compliance documents with a source-priority resolution chain. That required careful architecture to make sure the agent never stalls waiting for a GRC response.

**MCP server lifecycle management.** The MCP Python SDK's `ClientSession` requires entering its async context manager to start the internal receive loop that routes server responses to per-request streams. Without `__aenter__()`, `initialize()` hangs waiting for a response that is never delivered, until the async bridge's 60-second timeout cancels everything — producing a `BrokenResourceError` cascade and leaving the server status empty. Getting the session lifecycle right — entering sessions after creation, keeping them alive for the agent's lifetime, and exiting them before closing stdio transports on shutdown — was a subtle debugging exercise that spanned two releases.

**Human-in-the-loop without friction.** The design principle is "propose, don't execute." Implementing this across response policies, WAF rules, and vulnerability patches while keeping the workflow fluid meant thinking through every state transition. The dry-run simulation capability (show what *would* happen before asking for approval) was the key insight that made it work.

**Scope management.** The temptation to add more Alibaba Cloud services, more GRC integrations, and more response playbooks was constant. Staying focused on Track 4's core requirement, an autopilot agent that automates real-world security workflows end-to-end, meant saying no to interesting tangents and polishing what was already there.

## Accomplishments that we're proud of

**Zero-setup demo mode.** Bundling 23 JSON fixture files so the entire agent runs offline with no Alibaba Cloud credentials was one of the best design decisions. Judges and users can install via Homebrew (`brew install blueteam-autopilot`) or `pip install`, add a Qwen Cloud API key, and start triaging in under 5 minutes. Demo mode is the default.

**Built on Qwen Cloud + ConnectOnion.** The standalone agent leverages Qwen Cloud's function calling, thinking mode, parallel tool calls, and structured output, delivered through the ConnectOnion framework's Agent class, plugin system, and Textual TUI. The agent isn't a wrapper around a chat API — it's a proper tool-orchestrating runtime with HITL plugins, compliance logging, and token tracking.

**40 built-in tools + dynamic MCP tools.** The agent ships 40 registered tools across 9 categories (core, events, WAF, response, reporting, IAM forensics, vector memory, monitoring, file operations), each wrapping a production CLI script that works identically in real and demo modes. On top of that, MCP server integration dynamically discovers and registers tools from external servers (CISO Assistant: 101 tools, Alibaba Cloud: 26 tools) at startup — making them available as first-class tools without code changes.

**Structured incident response reports.** The `generate_incident_report` tool aggregates data from 9 sources (event detail, alerts, assets, vulnerabilities, response policies, WAF instance, WAF events, NIST CSF controls, SOC 2 controls) into a single structured context package. Pydantic models enforce the schema: attack chain stages, blast radius, investigation timeline, confidence ratings, and a complete audit trail. Reports are suitable for export to ticket systems, compliance audits, or management review.

**MCP server integration that scales.** The async bridge pattern — background event loop thread bridging sync ConnectOnion tools to async MCP SDK — means any MCP server can be plugged in via `.mcp.json`. Stdio and SSE transports, per-server timeouts, environment variable interpolation, and graceful degradation are all handled. Adding a new MCP server means adding three lines to the config.

**Multi-agent workflow engine.** The v3.0 architecture introduces a declarative workflow engine with 5 specialist workflows — incident response, IAM forensics, threat hunting, compliance audit, and autonomous monitoring. Each workflow runs as a sequence of scoped agents with restricted tool sets, enabling complex multi-phase investigations that were impossible with a single flat agent loop.

**Autonomous SOC daemon.** The `--daemon` flag transforms the agent from a reactive copilot into a proactive security monitor. It continuously polls for new alerts, auto-triages by severity, checks institutional memory for recurring patterns, and escalates only high-severity findings. This is the "autonomous SOC" vision realized — the agent runs as a daemon watching for threats 24/7.

**SOC 2 compliance by design.** The "propose, don't execute" architecture means every state-changing action requires explicit human approval. This isn't a feature bolted on. It's the core design principle, and it made the architecture cleaner, not harder.

**Cron and automation from day one.** The agent isn't limited to interactive use. The `--prompt` flag and stdin piping enable scheduled security checks, CI/CD integration, and scripted workflows. Clean stdout/stderr separation means output can be redirected to files, logs, or other tools without parsing hacks.

**Homebrew distribution with auto-update.** A single `brew install blueteam-autopilot` sets up the agent, Python virtualenv, and all dependencies. The GitHub Actions workflow watches for new releases and automatically updates the formula SHA256 and resource hashes in the Homebrew tap, so users get the latest version with a standard `brew upgrade`.

## What we learned

**Guardrails are a feature, not a constraint.** Designing the agent to *propose* actions rather than *execute* them actually improved the architecture. Human-in-the-loop isn't friction. It's the product.

**Demo mode changes everything for adoption.** The insight that judges (and users) need to *experience* a tool before committing to setting up credentials led to the dual-mode architecture. Bundling fixture files so the entire agent runs offline turned out to be the single most important adoption decision.

**GRC and SecOps belong in the same conversation.** Integrating live GRC data into incident response showed that compliance mapping isn't an after-the-fact report. It's real-time context that shapes the response itself.

**MCP is the right abstraction for cloud security.** Organizing tools through the Model Context Protocol gave the agent a clean, extensible interface to Alibaba Cloud's APIs without tight coupling. Dynamic tool discovery means adding a new capability can be as simple as adding a server config. But MCP's async lifecycle requires careful attention — session management, context manager ordering, and graceful degradation are the difference between a demo and a production system.

**Aggregating investigation data into reports is non-trivial.** The `generate_incident_report` tool pulls from 9 different data sources in a single call. Getting the orchestration right — parallel where possible, sequential where dependencies exist, with proper error handling for each source — taught us that report generation is its own tool category, not just a formatting exercise.

**Headless mode changes the use cases.** Adding `--prompt` and stdin support wasn't just a CLI convenience — it unlocked cron jobs, CI/CD integration, and scripted security checks. The key insight was keeping the same agent runtime for both interactive and headless modes, just toggling `quiet=True` and skipping the TUI. Clean stdout/stderr separation makes the output pipe-friendly without any special handling.

## What's next for Alibaba Blueteam

**More Alibaba Cloud services.** The current skill set covers Security Center, WAF 3.0, SLS, VPC, and STS. The next wave adds Cloud Firewall, ActionTrail, and OSS security monitoring, each following the same MCP tool pattern established here.

**Automated response execution.** Today the agent proposes actions and waits for human approval. The next step is a trusted-action registry: pre-approved responses (like blocking known-bad IPs from threat intel feeds) that execute automatically, with full audit trails. The daemon mode is the foundation for this — it already auto-triages and escalates; the next step is auto-responding for pre-approved actions.

**Continuous compliance monitoring.** The current GRC integration maps incidents to compliance controls after the fact. The goal is real-time drift detection: the agent continuously compares your cloud posture against NIST CSF and SOC 2 requirements and flags gaps before they become incidents. The compliance-audit workflow is the first step toward this vision.

**Multi-cloud GRC correlation.** CISO Assistant and Vanta both support frameworks beyond what a single cloud provider covers. Extending the GRC sync pipeline to correlate controls across Alibaba Cloud, AWS, and Azure would give security teams a unified compliance view.

**Embedding-powered analytics.** The vector embedding layer is the foundation for richer institutional analytics — trend detection, attack pattern clustering, mean-time-to-resolution tracking, and predictive alerting based on historical incident similarity.
