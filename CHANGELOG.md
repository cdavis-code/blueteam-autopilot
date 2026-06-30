# Changelog

All notable changes to the Alibaba Blueteam project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] — 2026-07-01

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
