# BlueTeam — Agent Setup

Standalone Python agent for Alibaba Cloud SecOps. Built on Qwen Cloud + ConnectOnion framework with 19 security tools and human-in-the-loop guardrails.

---

## Quick Start

```bash
# Install deps and configure API key
pip install -e .
cp .env.example .env
# Edit .env: DASHSCOPE_API_KEY="sk-..."

# Run the agent
python blueteam.py
```

**Demo mode is the default** — reads from fixture JSON files in `skills/blueteam-autopilot-core/fixtures/`. No Alibaba Cloud credentials needed. Zero network calls.

For live Alibaba Cloud APIs, add to `.env`:
```bash
SECURITY_CENTER_MODE=real
```

Then run `aliyun configure` to set up credentials (stored in `~/.aliyun/config.json`). Scripts use the `aliyun` CLI credentials automatically.

---

## Required Commands

| Task | Command |
|------|---------|
| Run agent | `python blueteam.py` |
| Switch to real mode | Add `SECURITY_CENTER_MODE=real` to `.env` + run `aliyun configure` |
| Configure aliyun CLI | `aliyun configure` (sets AccessKey ID, Secret, region) |
| Verify setup (real mode) | `SECURITY_CENTER_MODE=real python skills/blueteam-autopilot-ops/scripts/ping.py` |
| Test a single script | `python skills/blueteam-autopilot-ops/scripts/list_events.py` |

No build, no tests, no codegen. Just `python blueteam.py`.

---

## Architecture

```
blueteam.py
├── ConnectOnion Agent + Textual TUI
├── QwenCloudLLM (custom provider, internal thinking-mode stream aggregation)
├── 40 tools (connectonion_qwen/tools.py)
│   └── Each tool → Python script in skills/blueteam-autopilot-ops/scripts/
│       └── If SECURITY_CENTER_MODE=demo → read fixtures/*.json
│       └── If SECURITY_CENTER_MODE=real → call `aliyun` CLI
└── 2 plugins (connectonion_qwen/plugins.py)
    ├── HITL approval gate (SOC 2 CC6.8.3): dry-run preview + y/N confirmation
    └── Compliance audit logger: after-tool logging with 4000-char output truncation
```

**Tools are plain Python functions with type hints.** ConnectOnion auto-generates OpenAI tool schemas from docstrings + type hints.

**Python scripts dispatch based on mode:** demo mode returns fixture JSON; real mode calls `aliyun sas ...`, `aliyun waf-openapi ...`, `aliyun sls ...`. Scripts are cross-platform compatible (Windows/macOS/Linux).

**HITL approval only fires for state-changing tools:** `execute_response_policy`, `block_waf_ips`. Runs dry-run preview first, then prompts for y/N. Execution happens only if user types "yes".

---

## Key Configuration

| Env Var | Purpose | Default |
|---------|---------|---------|
| `DASHSCOPE_API_KEY` | Qwen Cloud API key (required) | None |
| `QWEN_MODEL` | Qwen model name | `qwen3.7-plus` |
| `ENABLE_THINKING` | Thinking mode for orchestration | `true` |
| `SECURITY_CENTER_MODE` | `demo` or `real` | `demo` |
| `MAX_TOOL_ROUNDS` | Agent iteration limit | `50` |
| `ALIBABA_REGION` | Override region auto-discovery | None (auto from `aliyun configure`) |
| `MCP_CONFIG_PATH` | Optional GRC MCP server config | `.mcp.json` |

Region is auto-discovered from `aliyun configure` output. Set `ALIBABA_REGION` to override.

---

## Repository Structure

| Path | Purpose |
|------|---------|
| `blueteam.py` | Entry point — wires ConnectOnion Agent + TUI + plugins |
| `connectonion_qwen/` | Custom Qwen provider, 39 tool functions, plugins, config |
| `connectonion_qwen/tools.py` | 40 tools as plain Python functions (auto-schema from type hints) |
| `connectonion_qwen/plugins.py` | HITL approval gate + compliance logger |
| `connectonion_qwen/qwen_llm.py` | Custom LLM provider with thinking-mode internal streaming |
| `skills/blueteam-autopilot-ops/scripts/` | 31 Python scripts called by tools (demo vs. real dispatch) |
| `skills/blueteam-autopilot-core/fixtures/` | 23 demo fixture JSON files (default mode) |
| `skills/blueteam-autopilot-knowledge/knowledge/` | Compliance docs, runbooks (NIST CSF, SOC 2, etc.) |
| `skills/blueteam-autopilot-core/SKILL.md` | Agent role, behavior workflow, compliance guardrails |
| `skills/blueteam-autopilot-knowledge/` | Compliance docs, runbooks, GRC sync scripts |

---

## Common Patterns

### Adding a new tool

1. Define a Python function in `connectonion_qwen/tools.py` with type hints + docstring
2. Append to `ALL_TOOLS` list at bottom of `tools.py`
3. Create bash script in `skills/blueteam-autopilot-ops/scripts/`
4. Add fixture JSON in `skills/blueteam-autopilot-core/fixtures/` for demo mode
5. Script dispatches on `SECURITY_CENTER_MODE`: demo returns fixture, real calls `aliyun` CLI

### Running scripts directly (without agent)

```bash
# Demo mode (default)
python skills/blueteam-autopilot-ops/scripts/list_events.py

# Real mode
SECURITY_CENTER_MODE=real python skills/blueteam-autopilot-ops/scripts/list_events.py
```

Scripts source `.env` automatically from project root.

### Troubleshooting real mode

1. Verify credentials: `aliyun configure list`
2. Test CLI: `aliyun sas describe-version-config`
3. Check region auto-discovery: scripts call `_helpers.py:discover_region()`
4. If scripts timeout: may need Security Center Enterprise edition (code 4) or Ultimate (5) for Agentic SOC features

### State-changing actions

**Only `execute_response_policy` is gated by HITL plugin.** All other tools are read-only.

When a state-changing tool is called:
1. Plugin runs dry-run (script without `--real` flag)
2. Displays preview + prompts for y/N
3. If user types "yes", runs script with `--real` flag
4. Otherwise, returns "Denied by operator"

To add a new state-changing tool, append to `_STATE_CHANGING_TOOLS` in `plugins.py` and add dry-run logic.

---

## Gotchas

- **Alibaba Cloud CLI API names are lowercase with hyphens** (e.g., `describe-susp-events`, not `DescribeSuspEvents`)
- **Demo mode is the default** — no `.env` or credentials needed to try the agent
- **Scripts auto-discover region from `aliyun configure`** — set `ALIBABA_REGION` in `.env` only if you need to override
- **Thinking mode is ON by default** — internal streaming aggregation preserves Qwen's thinking quality
- **Tool output truncated to 4000 chars** by compliance logger plugin (after-tool hook) to save context
- **MCP servers optional** — agent loads GRC tools from `.mcp.json` if present, skips if unavailable
- **Python 3.10+ required** — type hints use `|` union syntax
- **ConnectOnion pulls in `textual`, `openai`, `rich` transitively** — no need to install separately

---

## Skills Summary

7 skills total (intended for AI IDE harness use). Standalone agent only needs `blueteam.py` + `connectonion_qwen/`.

| Skill | Purpose | Used by Agent |
|-------|---------|---------------|
| `blueteam-autopilot-core` | Agent role, behavior workflow, compliance controls | Yes (system_prompt.py references it) |
| `blueteam-autopilot-ops` | 17 bash scripts wrapping `aliyun` CLI | Yes (tools.py calls scripts) |
| `blueteam-autopilot-prep` | Environment validation (8-stage, real mode only) | No (manual pre-flight checks) |
| `blueteam-autopilot-knowledge` | Compliance docs, runbooks, GRC sync | Yes (tools call get_knowledge.py) |
| `blueteam-autopilot-reports` | Incident report templates + render script | Yes (generate_incident_report tool) |
| `blueteam-autopilot-compat` | CLI compatibility validation | No (dev/test utility) |

---

## Dependencies

```
connectonion>=1.0.0    # Agent framework with TUI
mcp>=1.27,<2           # Optional GRC integrations
python-dotenv>=1.0.0   # .env loader
```

ConnectOnion transitively pulls: `textual` (TUI), `openai` (client), `rich` (formatting).

---

## No IDE Harness? No Problem.

This repo was originally packaged as 7 skills for Qoder/Cursor/OpenCode. The standalone agent (`blueteam.py`) was added later to demonstrate the framework without requiring an AI IDE.

Both modes work:
- **Standalone agent:** `python blueteam.py` → full Textual TUI with Qwen Cloud
- **Skills in AI IDE:** `npx skills add cdavis-code/blueteam-autopilot --skill '*'` → IDE provides LLM

Same tools, same scripts, same fixtures. Pick your workflow.
