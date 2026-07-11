# Changelog

All notable changes to the Alibaba Blueteam project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.1.0] — 2026-07-11

### Changed

#### Bash-to-Python Script Migration (Cross-Platform)
- **All 31 ops scripts converted from bash to Python** — `skills/blueteam-autopilot-ops/scripts/` now contains only `.py` files. Enables Windows compatibility without requiring bash/Git Bash.
- **All 3 prep scripts converted** — `validate_configuration.py`, `generate_trusted_networks.py`, `configure_policies.py` replace their `.sh` predecessors.
- **Shared infrastructure** — `_helpers.py` replaces `_discover-region.sh` and `_rewrite-timestamps.sh` with Python functions (`discover_region()`, `rewrite_timestamps()`, `load_fixture()`).
- **`_base.py`** — New `BaseScript` class with demo/real mode dispatch, `run_aliyun()` subprocess wrapper, and lazy region discovery. `DryRunMixin` provides `--real` flag handling for state-changing scripts.
- **`tools.py` dispatcher update** — `_run_script()` now prefers `.py` files over `.sh`, using `sys.executable` for cross-platform Python invocation. Converts hyphen-based script names to underscore-based Python filenames automatically.
- **`aliyun` CLI calls unchanged** — Python scripts invoke `aliyun` CLI via `subprocess.run()` (same as bash). The `aliyun` CLI is a Go binary available on all platforms, so no API call changes were needed.

### Removed

- **All 33 bash scripts** — `.sh` files deleted from `skills/blueteam-autopilot-ops/scripts/` (31 files) and `skills/blueteam-autopilot-prep/scripts/` (3 files) after Python equivalents were verified.
- **`requirements.txt`** — Removed in favor of `pyproject.toml` (PEP 621). Install via `pip install -e .`

### Documentation

- **AGENTS.md** — Updated install instructions (`pip install -e .`), script references (`.sh` → `.py`), tool count (39 → 40), and architecture description (bash → Python scripts).
- **README.md** — Updated directory tree, skill summary, and architecture diagram references.

---

## [3.0.5] — 2026-07-11

### Added

#### File Writing Tool
- **`write_file` tool (40th tool)** — New tool in `tools.py` that writes text content to a file on disk. Accepts `file_path` (absolute or project-relative) and `content` parameters. Creates parent directories automatically. Returns JSON with status, file path, and bytes written.
- **HITL approval for `write_file`** — Added to `_STATE_CHANGING_TOOLS` in both `tools.py` and `plugins.py`. Dry-run preview shows file path, content preview (first 200 chars), and byte count before requiring operator approval.
- **Tool count: 39 → 40** — `write_file` added to `ALL_TOOLS` list.

### Changed

#### Documentation — TUI vs. Daemon Positioning
- **README.md** — Added positioning note clarifying that the primary use case is autonomous monitoring via `--daemon` mode. The interactive TUI is designed for ad-hoc investigation, testing, and development — not as a replacement for a full SOC dashboard.
- **about.md** — Reframed "What it does" section to lead with the daemon-as-primary-deployment message. Added `write_file` as item 12 in the capability list. Updated tool count from 39 → 40 and categories from 8 → 9 (added "file operations").
- **README.md demo mode FAQ** — Clarified that demo mode requires a Qwen Cloud API key (not fully offline).

#### Debug Logging Cleanup
- Removed temporary `[HITL]` and `[TUI_APPROVE]` debug logging from `plugins.py` and `blueteam.py` that was added during `write_file` HITL integration testing.

---

## [3.0.4] — 2026-07-11

### Added

#### Prompt Injection Input Filter
- **`connectonion_qwen/injection_patterns.json`** — Runtime-loadable JSON file with 15 configurable regex patterns for detecting prompt injection attempts in tool output. Patterns classified into three severity levels: critical (reject entire content), high (redact matched text), medium (log warning, pass through).
- **`_sanitize_injections()` in `plugins.py`** — Screens every tool result for injection patterns after truncation but before `[TOOL OUTPUT START]`/`[TOOL OUTPUT END]` boundary wrapping. Critical hits replace content with a block notice; high hits redact matched substrings in-place; medium hits log a warning. All detections emit audit log entries with full match context.
- **`_load_injection_patterns()` / `_scan_for_injections()`** — Helper functions for pattern loading (cached after first read) and scanning. Invalid regexes are logged and skipped without crashing.
- **GARAK-3 mitigation** — Adds a third defense layer (input filtering) on top of existing context isolation (boundary markers) and system prompt guardrails.

#### SECURITY.md
- **`SECURITY.md`** — Comprehensive security controls reference documenting threat model, prompt injection prevention (3-layer defense), HITL enforcement, audit trail, supply chain protection, credential protection, and SOC 2 / NIST CSF compliance mapping.

### Fixed

#### HITL Gate Bypass Bugs
- **BUG-7 — `run_command` missing from HITL gate** — `run_command` was absent from `_STATE_CHANGING_TOOLS` in `plugins.py`, so the HITL approval plugin skipped it entirely despite a dry-run handler existing. Added `run_command` to the set so arbitrary bash commands now require operator confirmation.
- **SEC-4 — Workflow engine bypasses HITL gate** — Phase agents in `workflows/_engine/runner.py` were created with `plugins=[]`, stripping all plugins including HITL approval. Fixed by conditionally wiring `hitl_approval_plugin` into phases that declare `requires-hitl: true` in their WORKFLOW.md frontmatter.

#### Script Fixes
- **BUG-8 — `get-knowledge.sh` stat order** — Swapped `stat -c` (Linux) before `stat -f` (macOS) so Linux systems don't fall through to the macOS path and emit a harmless but noisy error.
- **BUG-9 — `block-waf-ips.sh` demo mode ignores arguments** — Moved argument parsing before the demo mode early return so demo output correctly reflects the IPs passed on the command line instead of echoing an empty list.
- **BUG-10 — Broken `MODES.md` link** — Replaced non-existent `MODES.md` reference in `alibaba-security-ops/SKILL.md` with a reference to `.env.example`.
- **BUG-11 — Overly permissive resource ID regex** — Tightened resource ID pattern in `validate-configuration.sh` from `{2,}` to `{6,}` and added `waf-[a-z0-9]+-` prefix structure, eliminating false positives on short hex strings.

### Changed

#### Documentation
- **README.md** — Added Security section summarizing the five key control areas with a link to `SECURITY.md`. Added entry to Table of Contents. Added `SECURITY.md` to the directory tree.
- **`blueteam.py`** — Welcome banner version updated to v3.0.4.

---

## [3.0.3] — 2026-07-08

### Changed

#### Scoped Auto-Approval CLI
- **`--auto-approve` flag redesign** — Changed from a boolean `--auto-approve`/`--no-auto-approve` pair to a comma-delimited list of tool names (e.g. `--auto-approve execute_local_script,run_command`). Each listed tool bypasses HITL confirmation; unlisted tools still require approval.
- **Default narrowed** — Defaults to `"execute_local_script"` only. Previously auto-approved ALL state-changing tools.
- **`--auto-approve none`** — Special value to disable auto-approval entirely, requiring HITL confirmation for every state-changing action.
- **`BooleanOptionalAction` removed** — No longer needed; flag now accepts a plain string.

#### Plugin-Level Auto-Approval Gate
- **`set_auto_approved_tools()`** — New setter in `plugins.py` that registers the auto-approved tool set from CLI args.
- **`_auto_approved_tools`** — Module-level set checked by `hitl_approval()` before invoking the dry-run + approval flow. Tools in this set return immediately (no HITL, no dry-run).
- **`hitl_approval()` scoping** — Auto-approve check happens after `_STATE_CHANGING_TOOLS` membership but before `_run_dry_run()` and `_request_approval()`, scoping HITL bypass to specific tools rather than a global toggle.

#### TUI Wiring Simplified
- **Always-on TUI callback** — `set_tui_approval_callback(_tui_approve)` is now unconditional in TUI mode. The old `lambda *_: True` bypass path is replaced by the plugin-level auto-approve gate.
- **Headless/daemon parity** — `set_auto_approved_tools()` is called in `main()` before any mode dispatch, so headless and daemon modes respect the scoped auto-approve list.

#### Documentation
- **TOC added to README.md** — Full table of contents with anchor links to all major sections.
- **CLI Options table** — New dedicated section documenting all 4 CLI flags with the updated `--auto-approve` behavior.

## [3.0.2] — 2026-07-08

### Added

#### Alibaba Cloud Env Var Auto-Discovery
- **`_discover_aliyun_env()` in `config.py`** — Auto-discovers `ALIBABA_REGION`, `ALIBABA_ACCESS_KEY_ID`, and `ALIBABA_ACCESS_KEY_SECRET` from `aliyun configure` and `~/.aliyun/config.json` at module import time. Populates `os.environ` so `run_command` subprocesses inherit these values without requiring them in `.env`. Region auto-discovered via `aliyun configure get region`; credentials read from the current profile in `~/.aliyun/config.json`.

#### TUI Progress Log Plugin
- **`tui_result_capture_plugin`** — New ConnectOnion `after_each_tool` plugin that pushes tool results to the `ProgressLog` widget in the TUI. Uses module-level `_tui_app` reference set at TUI startup; gracefully no-ops in prompt/daemon modes.

### Changed

#### Plugin Architecture Refactor
- **Inline handler → proper plugin** — Moved `_capture_tool_result` from a 34-line inline handler in `blueteam.py` (registered via private `agent._register_event()`) to a proper `@after_each_tool` plugin in `plugins.py`. Registers via standard `plugins=[...]` in `_create_agent()`. Removes private API dependency.
- **Shared trace helper** — Consolidated duplicate trace traversal logic shared by `compliance_logger` and `capture_tool_result` into `_get_last_tool_result(agent)`. Eliminates ~26 lines of redundant code and enforces consistent field name usage (`tool_name` with `name` fallback).
- **Plugin execution order** — `tui_result_capture` now runs BEFORE `compliance_logger` so the ProgressLog sees raw tool results (before `[TOOL OUTPUT START]`/`[TOOL OUTPUT END]` wrappers are applied for LLM context).
- **Plugin count: 2 → 3** (hitl_approval, tui_result_capture, compliance_logger).

#### TUI Rendering Fix
- **MarkupError resolved** — Set `_render_markup = False` in `ProgressLog` widget to prevent Rich from parsing square brackets in tool results as markup tags. Was causing `MarkupError: Expected markup value` crashes during layout refresh.

### Removed

#### Dart SDK References
- **`blueteam-autopilot-prep/SKILL.md`** — Removed Dart SDK ≥ 3.4 from prerequisite table and optional tool list (no Dart runtime exists in this project).
- **`alibaba-security-ops/SKILL.md`** — Removed all Dart migration history: "Replaces Dart MCP tool" tags, Dart Original descriptions, Key Differences comparison table, and Don't-use-when section referencing Dart.

---

## [3.0.1] — 2026-07-06

### Added

#### End-to-End Testing Regime
- **`tests/e2e/`** — Comprehensive real-mode testing suite covering all 5 workflows, cross-cutting features, and daemon mode.
- **`deliver-attacks.sh`** — Sample attack delivery via curl (SQLi, XSS, LFI, command injection, scanner behavior, SSRF) targeting WAF-protected domains.
- **`test-workflows.sh`** — Per-workflow validation for incident-response, iam-forensic, threat-hunt, compliance-audit, and continuous-monitor.
- **`test-cross-cutting.sh`** — Embedding search, HITL gating, monitor persistence, DB schema validation, IAM drift detection.
- **`test-daemon.sh`** — Daemon mode startup, attack detection, graceful shutdown verification.
- **`run-all-tests.sh`** — Orchestrator with prerequisite validation and phase-based execution.

### Fixed

#### WAF Attack Delivery
- **HTTP-level rule triggering** — Switched from HTTPS to HTTP to bypass SSL-level connection resets and generate actual WAF log events (HTTP 405 responses).
- **Curl error handling** — Added graceful handling of connection resets (exit code 35) to correctly identify WAF blocking.
- **Attack payload tuning** — Updated payloads to use standard signatures (UNION-based SQLi, script tag XSS, double-encoding LFI) that trigger WAF detection rules.

---

## [3.0.0] — 2026-07-06

### Added

#### Multi-Agent Workflow Engine
- **`workflows/_engine/`** — Declarative workflow orchestration engine (parser.py, runner.py, context.py). Parses WORKFLOW.md files with YAML frontmatter defining phases, creates scoped Agent instances per phase with restricted tool sets and phase-specific system prompts, and accumulates outputs via WorkflowContext.
- **`workflows/incident-response/WORKFLOW.md`** — 5-phase reactive incident handling (discovery → deep_dive → recommendation → action → report). Migrated all 5+2 behaviors from the monolithic system prompt into declarative workflow phases.
- **`workflows/iam-forensic/WORKFLOW.md`** — 4-phase IAM security audit (discovery → analysis → remediation → persist) with 13 IAM tools and credential risk scoring.
- **`workflows/threat-hunt/WORKFLOW.md`** — 4-phase proactive threat hunting (collect → analyze → correlate → report) with external correlation and pattern analysis.
- **`workflows/compliance-audit/WORKFLOW.md`** — 4-phase compliance gap analysis (inventory → map → evidence → report) with control mapping and evidence collection.
- **`workflows/continuous-monitor/WORKFLOW.md`** — 3-phase autonomous SOC monitoring (scan → triage → escalate) driven by the daemon loop.
- **Auto-delegation** — Main agent auto-delegates to workflows for investigations while handling quick single-tool queries directly.

#### Vector Embeddings for Similarity Search
- **`connectonion_qwen/embeddings.py`** — Universal incident embeddings using DashScope text-embedding-v3 (1024-dim in real mode, 64-dim deterministic hash fallback in demo mode). Cosine similarity search against all stored embeddings.
- **`connectonion_qwen/memory.py`** — Persistent SQLite/libSQL database (`data/blueteam.db`) with `incident_embeddings` table for vector storage and `monitor_state` table for daemon state tracking.
- **`search_similar_incidents`** tool — Query institutional memory for previously seen incidents similar to the current investigation. Returns top-k matches with similarity scores.
- **`store_incident_memory`** tool — Store incident descriptions as embeddings for future similarity search. All 5 workflows auto-store findings.

#### Autonomous SOC Daemon
- **`--daemon` / `-d` CLI flag** — Run as continuous monitoring daemon. Polls on configurable interval, auto-triages new alerts, escalates high-severity findings.
- **`--interval` / `-i` CLI flag** — Monitoring interval in seconds (default: 60). Daemon sleeps between ticks with graceful SIGINT/SIGTERM shutdown.
- **`get_monitor_state`** / **`update_monitor_state`** tools — Track last check timestamp, tick count, and escalation count in the database.
- **Rich console output** — CRITICAL/HIGH escalations highlighted in red, all-clear in green, with per-tick timestamps and shutdown summary.

### Changed

#### System Prompt Refactoring
- **`connectonion_qwen/system_prompt.py`** — Slimmed from 188 lines to ~88 lines (53% reduction). Monolithic behavior definitions replaced with auto-delegation rules that route to the appropriate workflow. Identity, compliance context, and guardrails preserved.

#### Tool Count
- **37 tools** (up from 19): 13 IAM forensic tools, 2 workflow engine tools, 2 vector memory tools, 2 monitoring tools, plus original 18 security tools.

#### Documentation
- **`blueteam.py`** — Welcome banner version updated to v3.0.0
- **`.env.example`** — Added Memory & Embeddings section and Autonomous SOC daemon section
- **`submission/about.md`** — Updated with workflow engine, embeddings, daemon mode, and autonomous SOC capabilities

---

## [2.2.1] — 2026-07-03

### Added

#### Demo Mode Timestamp Rewriting
- **`_rewrite-timestamps.sh`** — Shared helper script that rewrites fixture timestamps relative to "now" at runtime, preserving chronological spacing between events while making demo data appear fresh
- **`list-events.sh`** — Demo mode now pipes fixture through `rewrite_timestamps` function before returning
- **`list-waf-events.sh`** — Same timestamp rewriting applied to WAF event fixtures
- Timestamp fields handled: `createdAt`, `timestamp`, `detectedAt`, `updatedAt`

### Fixed

#### Secure Coding Audit Fixes
- **`connectonion_qwen/tools.py`** — Generic exception handler now logs detail server-side and returns sanitized "Tool execution failed. Please retry." message to LLM (prevents information leakage)
- **`connectonion_qwen/tools.py`** — `block_waf_ips` now validates IP/CIDR inputs using Python's `ipaddress` module before passing to script (prevents malformed input to state-changing tool)
- **`connectonion_qwen/mcp.py`** — MCP tool failures log detail server-side, return "MCP tool execution failed. Please retry." (prevents internal error exposure)
- **`connectonion_qwen/qwen_llm.py`** — Qwen Cloud API errors log detail server-side, return "Qwen Cloud API error. Check your API key and model configuration." (prevents API key/endpoint leakage)
- **`connectonion_qwen/config.py`** — `MAX_TOOL_ROUNDS` int parse wrapped in try/except, defaults to 20 on invalid env var input (prevents crash on malformed config)

### Changed
- `blueteam.py` — Welcome banner version updated to v2.2.1

---

## [2.2.0] — 2026-07-03

### Added

#### Headless / Cron Mode
- **`--prompt` / `-p` CLI argument** — Run the agent non-interactively with a single prompt, then exit. Ideal for cron jobs, CI pipelines, and automation workflows.
- **Stdin piping** — Pipe prompts via stdin (`echo "Show events" | python blueteam.py`). If both `--prompt` and stdin are provided, they are concatenated with a newline separator.
- **`_run_prompt()`** — Headless execution path: creates agent with `quiet=True` (no TUI, no banner), runs a single prompt, prints response to stdout, and exits cleanly.
- **Graceful error handling** — Headless mode catches exceptions and prints clean error messages to stderr with non-zero exit code (no raw tracebacks).

#### Configurable API Endpoint
- **`QWEN_BASE_URL` env var** — Override the DashScope API base URL via `.env`. Defaults to the international endpoint (`https://dashscope-intl.aliyuncs.com/compatible-mode/v1`). Supports mainland China endpoint and custom gateways.
- **.env.example** — Documented `QWEN_BASE_URL` option with examples for both international and mainland China endpoints.

### Changed
- `blueteam.py` — Welcome banner version updated to v2.2.0
- `connectonion_qwen/config.py` — `QWEN_BASE_URL` now reads from environment variable with default fallback (previously hardcoded)

---

## [2.1.4] — 2026-07-02

### Fixed

#### MCP Server Loading (ClientSession lifecycle)
- **`connectonion_qwen/mcp.py`** — Fixed MCP servers failing to load at startup (0 tools registered, empty `/mcp` status, 60s overall timeout). Root cause: `ClientSession` was constructed without entering its async context manager, so `__aenter__` never started the `_receive_loop` that routes server responses to per-request streams. `initialize()` hung waiting for a response that was never delivered, until the async bridge's 60s overall cap cancelled everything — producing a `BrokenResourceError` cascade and leaving `_server_status` empty. Verified against `.mcp.json` (ciso-assistant: 101 tools, alibabacloud-mcp-server: 26 tools — both now connect cleanly).
- **Session lifecycle** — `ClientSession` is now entered via `__aenter__()` after creation (starts the receive loop) and kept alive in `_sessions` for the agent's lifetime so later tool calls reuse the live connection.
- **`shutdown_mcp()`** — Now exits each `ClientSession` (`__aexit__`) before closing the stdio transports that back them, cancelling their receive loops cleanly on quit.

### Changed
- `agent.py` — TUI welcome banner version set to v2.1.4
- README.md — Slash Commands feature row updated to include `/mcp` (MCP server connection status), which was already registered in `agent.py` but missing from the docs

---

## [2.1.3] — 2026-06-30

### Added

#### Incident Response Report Generation Tool
- **`generate_incident_report`** — New tool (19th) that aggregates all investigation data (event detail, alerts, assets, vulnerabilities, WAF, compliance controls) into a structured context package for report synthesis
- **`connectonion_qwen/report_models.py`** — Pydantic models for structured IR report data: `IncidentReport`, `AttackChainStage`, `AffectedAsset`, `TimelineEvent`, `RecommendedAction`, `AuditEntry`
- **Extended schema** — `incident-report.json` updated with `timeline`, `blastRadius`, `confidence`, `recommendedActions`, `rollbackPlan`, and `auditTrail` fields
- **Extended template** — `incident-report.md` updated with Blast Radius, Investigation Timeline, Confidence Rating, Recommended Actions, Rollback Plan, and Audit Trail sections
- **System prompt** — Added Behavior 5b protocol instructing the agent to use `generate_incident_report` for comprehensive IR reports with compliance mapping and executive summary

### Changed
- `connectonion_qwen/tools.py` — Added `generate_incident_report` to `ALL_TOOLS` (now 19 tools); added `_safe_parse` helper for JSON parsing
- `agent.py` — Version bumped to v2.3.0

---

## [2.1.2] — 2026-06-30

### Added

#### MCP Server Integration
- **`connectonion_qwen/mcp.py`** — MCP client bridge that connects to external MCP servers, discovers tools, and wraps them as ConnectOnion-compatible Python functions
- **`.mcp.json`** — Default MCP server config with CISO Assistant (stdio) and Vanta (SSE) presets
- **Async bridge** — Background event loop thread bridges sync ConnectOnion tools to async MCP SDK, with 10s per-server connection timeout
- **Dynamic tool wrapping** — MCP tool schemas (JSON Schema) auto-converted to Python type hints + signatures for ConnectOnion's tool_factory
- **Graceful degradation** — Unreachable MCP servers are skipped with warnings; existing knowledge documents serve as fallback
- **`MCP_CONFIG_PATH`** — New env var / config option to override `.mcp.json` path
- **`mcp>=1.27,<2`** — Official MCP Python SDK added to dependencies

### Changed
- `requirements.txt` — Added `mcp>=1.27,<2`
- `agent.py` — Loads MCP tools at startup and appends to built-in tools; cleans up on exit
- `.env.example` — Added MCP configuration section

---

## [2.1.1] — 2026-06-30

### Fixed

#### Agent WAF Fallback for Basic Edition
- **System prompt** — Added Basic/Advanced edition fallback instructions: when `list_security_events` returns 0 events, the agent now automatically queries WAF logs via `list_waf_security_events`, `list_waf_top_rules`, and `list_waf_top_ips`
- **list-events.sh** — Added WAF fallback hint when Security Center returns 0 events; suppressed human-readable headers in agent mode (`AGENT_MODE=1`)

#### WAF CLI Parameter Naming
- **list-waf-top-rules.sh** — Fixed `--InstanceId` → `--instance-id`, `--StartTimestamp` → `--start-timestamp`, `--EndTimestamp` → `--end-timestamp` (WAF CLI requires lowercase-hyphenated params)
- **list-waf-top-ips.sh** — Same parameter naming fix as above

#### Script Output Parsing
- **list-waf-top-rules.sh** — Changed from human-readable text to structured JSON output; fixed `HitCount` → `Count` field name to match actual API response; resolved bash double-quote conflicts by using single-quoted Python
- **list-waf-top-ips.sh** — Same JSON output fix and quote conflict resolution
- **tools.py** — Added `AGENT_MODE=1` environment variable to suppress human-readable script headers when agent calls tools, ensuring clean JSON output for LLM parsing

---

## [2.1.0] — 2026-06-30

### Added

#### ConnectOnion Framework Integration
- **ConnectOnion adoption** — Migrated from custom agent loop to the [ConnectOnion](https://github.com/openonion/connectonion) agent framework (v1.0.4) for full agent runtime, plugin system, and Textual TUI
- **`agent.py`** — Single entry point (`python agent.py`) wiring QwenCloudLLM + Agent + Chat TUI with slash commands (`/help`, `/clear`, `/model`, `/quit`)
- **`connectonion_qwen/`** — New package containing all Qwen Cloud integration code:
  - `qwen_llm.py` — Custom `QwenCloudLLM(LLM)` provider with internal streaming aggregation preserving Qwen's thinking mode quality
  - `tools.py` — 17 tools converted from JSON schemas to plain Python functions (auto-schema from type hints + docstrings)
  - `plugins.py` — HITL approval plugin (`before_each_tool` hook) and compliance audit logger (`after_each_tool` hook)
  - `config.py` — Typed `.env` configuration (moved from `agent/config.py`)
  - `system_prompt.py` — System prompt (moved from `agent/system_prompt.py`)
- **Interactive TUI** — Full Textual-based terminal UI via ConnectOnion with status bar, thinking indicator, tool progress, and token/cost tracking
- **Plugin architecture** — ConnectOnion event system replacing inline HITL gates and adding compliance audit logging with output truncation

### Changed

#### Architecture
- Entry point changed from `python -m agent` to `python agent.py`
- Dependencies simplified to `connectonion>=1.0.0` + `python-dotenv` (ConnectOnion pulls in `textual`, `openai`, `rich` transitively)
- Tool registration: 17 tools auto-generate JSON schemas from Python type hints instead of hand-crafted schema definitions
- HITL approval gates now implemented as ConnectOnion `before_each_tool` plugin instead of inline agent loop logic

### Removed

- **`agent/` package** — Entire custom agent runtime deleted (9 files, ~1,282 lines): `main.py`, `cli.py`, `tools.py`, `hitl.py`, `config.py`, `system_prompt.py`, `__init__.py`, `__main__.py`, `requirements.txt`
- Custom `AgentCallbacks` dataclass — replaced by ConnectOnion's plugin event system
- Custom Rich-based CLI — replaced by ConnectOnion's Textual TUI

### Documentation
- README.md: Updated install instructions, directory tree, architecture diagram, feature table, and FAQ to reflect ConnectOnion architecture
- about.md: Updated "How we built it" section with ConnectOnion integration details

---

## [2.0.0] — 2026-06-30

### Added

#### Standalone Agent Runtime (`agent/`)
- **agent/** — Production-ready Python SecOps agent with interactive CLI, built on Qwen Cloud's OpenAI-compatible API
- **Function Calling Loop** — 17 registered tools mapped to ops bash scripts with parallel tool call support and configurable max rounds
- **Thinking Mode** — Optional Qwen reasoning mode for complex tool orchestration; reasoning streamed to terminal in rich formatting
- **Streaming** — Custom stream aggregator handling incremental tool call arguments, reasoning content, and text deltas
- **Human-in-the-Loop (HITL)** — SOC 2 CC6.8.3-compliant approval gates enforced in code; dry-run preview before state-changing actions
- **Structured Output** — Formal action proposal generation with reasoning, risk level, and rollback plan via JSON response format
- **Interactive CLI** — Rich-formatted terminal UI with slash commands (`/help`, `/clear`, `/history`, `/model`, `/quit`), startup banner, and multi-turn conversation
- **Dual Mode** — Demo mode (default) reads from fixture JSON files; real mode calls live Alibaba Cloud APIs via `SECURITY_CENTER_MODE` env var
- **Callback Architecture** — `AgentCallbacks` dataclass with hooks for thinking, tool calls, results, text, and HITL — decouples core from CLI for future web UI integration
- **Configuration** — Typed `.env` configuration via `python-dotenv` with validation; dependencies limited to `openai`, `python-dotenv`, and `rich`

#### CLI Compatibility Validation (blueteam-autopilot-compat)
- **blueteam-autopilot-compat** — New skill for detecting breaking changes in `aliyun` CLI commands, parameters, and response structures
- **cli-baseline.json** — Baseline of 26 commands across 6 product namespaces (sas, waf-openapi, sls, cloud-siem, sts, vpc) with expected parameters and response fields
- **check-compat.sh** — 5-stage compatibility validator: CLI installation, baseline load, command existence, parameter checks, live API tests

#### Region Auto-Discovery
- **_discover-region.sh** — Shared helper for automatic region discovery (env var → `aliyun configure` → `~/.aliyun/config.json` → error with guidance)
- All 17 ops scripts now auto-discover region from `aliyun` CLI configuration instead of requiring `ALIBABA_REGION` in `.env`

### Changed

#### Response Policy API Fix (siem-socket → cloud-siem)
- Fixed `list-response-policies.sh` to use correct product `cloud-siem` with API version `2022-06-16` and PascalCase parameters (`--PageSize`, `--CurrentPage`)
- Fixed `execute-response-policy.sh` to use `UpdateAutomateResponseConfigStatus` (the actual API for enabling response rules)
- Updated ops SKILL.md with Enterprise edition requirement note for response policy APIs

#### Documentation
- README.md: Updated skill count (6 → 7), added compat skill to directory tree and skill summary table
- medium-article.md: Updated fixture count (14 → 15), removed `ALIBABA_REGION` from `.env` example
- about.md: Updated fixture count, reordered mode description to lead with demo default

## [1.0.0] — 2026-06-16

### Added

#### Core Skills Framework
- **blueteam-autopilot-core** — Central skill orchestrator with behavioral guardrails, compliance quick-reference, and MCP tools catalog
- **blueteam-autopilot-ops** — 17 CLI scripts for live Alibaba Cloud Security Center operations (events, alerts, vulnerabilities, WAF, assets, response policies, log delivery verification)
- **blueteam-autopilot-knowledge** — Curated security knowledge base (SOC 2 CC6, NIST CSF, asset inventory, trusted networks, WAF triage runbook) with fetch script
- **blueteam-autopilot-prep** — Pre-flight validation and trusted-network generation scripts for environment setup
- **blueteam-autopilot-reports** — Report generation pipeline with JSON schemas, Markdown templates, and Python renderer (incident reports, action proposals, vulnerability prioritization, runbook checklists)

#### Demo & Offline Mode
- **skills/blueteam-autopilot-core/fixtures/** — 15 JSON fixture files providing realistic mock responses for all 17 CLI scripts, enabling full demo mode with zero Alibaba Cloud credentials
- **skills/MODES.md** — Dual-mode (live / demo) architecture documentation

#### GRC Integration
- **skills/blueteam-autopilot-core/references/mcp-tools.md** — GRC Tools section with CISO Assistant and Vanta MCP server configurations
- **CISO Assistant MCP** — stdio MCP server for live risk assessment, compliance audit, and framework queries
- **Vanta MCP** — Remote HTTP MCP server (OAuth) for live controls, tests, evidence, policies, and vendor risk queries
- **Live GRC query capability** — Agent queries live GRC data during incident response; falls back to synced local documents when MCP is unavailable

#### Documentation & Branding
- **README.md** — Project overview with SVG banner, getting-started guide, architecture diagram, and dual-mode instructions
- **assets/banner.svg** — Professional SVG banner with gradient design, shield icon, and project stats
- **skills/AUTONOMOUS_SETUP.md** — Autonomous agent setup and onboarding guide
- **skills/ENVIRONMENT_INDEPENDENCE.md** — Environment independence design principles
- **skills/alibaba-security-ops/SKILL.md** — Alibaba Security Ops integration skill definition

#### Configuration
- **.gitignore** — Repository hygiene (Python bytecode, Dart/Flutter artifacts, IDE files, environment secrets, OS files)
