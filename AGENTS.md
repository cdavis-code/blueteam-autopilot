# BlueTeam Autopilot — Agent Setup

Standalone Python agent for multi-cloud SecOps (Alibaba Cloud + AWS). Built on Qwen Cloud + ConnectOnion framework with modular provider components and human-in-the-loop guardrails.

---

## Quick Start

```bash
# Install deps and configure API key
pip install -r requirements.txt
cp .env.example .env
# Edit .env: DASHSCOPE_API_KEY="sk-..."

# Run the agent
python blueteam.py
```

**Demo mode is the default** — reads from fixture JSON files in `skills/blueteam-autopilot-core/fixtures/`. No cloud credentials needed. Zero network calls.

For live cloud APIs, add to `.env`:
```bash
SECURITY_CENTER_MODE=real
```

Then configure CLI credentials:
- Alibaba Cloud: `aliyun configure` (stored in `~/.aliyun/config.json`)
- AWS: `aws configure` (stored in `~/.aws/credentials`)

---

## Required Commands

| Task | Command |
|------|---------|
| Run agent | `python blueteam.py` |
| Switch to real mode | Add `SECURITY_CENTER_MODE=real` to `.env` + run `aliyun configure` |
| Configure aliyun CLI | `aliyun configure` (sets AccessKey ID, Secret, region) |
| Verify setup (real mode) | `SECURITY_CENTER_MODE=real bash skills/blueteam-autopilot-ops/scripts/ping.sh` |
| Test a single script | `bash skills/blueteam-autopilot-ops/scripts/list-events.sh` |

No build, no tests, no codegen. Just `python blueteam.py`.

---

## Architecture

```
blueteam.py
├── ConnectOnion Agent + Textual TUI
├── QwenCloudLLM (custom provider, internal thinking-mode stream aggregation)
├── 19 tools (connectonion_qwen/tools.py)
│   └── Each tool → bash script in skills/blueteam-autopilot-ops/scripts/
│       └── If SECURITY_CENTER_MODE=demo → read fixtures/*.json
│       └── If SECURITY_CENTER_MODE=real → call `aliyun` CLI
└── 2 plugins (connectonion_qwen/plugins.py)
    ├── HITL approval gate (SOC 2 CC6.8.3): dry-run preview + y/N confirmation
    └── Compliance audit logger: after-tool logging with 4000-char output truncation
```

**Tools are plain Python functions with type hints.** ConnectOnion auto-generates OpenAI tool schemas from docstrings + type hints.

**Bash scripts dispatch based on mode:** demo mode returns fixture JSON; real mode calls `aliyun sas ...`, `aliyun waf-openapi ...`, `aliyun sls ...`.

**HITL approval only fires for state-changing tools:** `execute_response_policy`, `block_waf_ips`. Runs dry-run preview first, then prompts for y/N. Execution happens only if user types "yes".

---

## Key Configuration

| Env Var | Purpose | Default |
|---------|---------|---------|
| `DASHSCOPE_API_KEY` | Qwen Cloud API key (required) | None |
| `QWEN_MODEL` | Qwen model name | `qwen3.7-plus` |
| `ENABLE_THINKING` | Thinking mode for orchestration | `true` |
| `SECURITY_CENTER_MODE` | `demo` or `real` | `demo` |
| `INFRA` | Cloud providers to load (comma-separated) | `aliyun` |
| `MAX_TOOL_ROUNDS` | Agent iteration limit | `20` |
| `ALIBABA_REGION` | Override region auto-discovery | None (auto from `aliyun configure`) |
| `MCP_CONFIG_PATH` | Optional GRC MCP server config | `.mcp.json` |

Region is auto-discovered from `aliyun configure` output. Set `ALIBABA_REGION` to override.

---

## Multi-Cloud Support

The agent supports multiple cloud providers via the `INFRA` environment variable:

| Value | Providers Loaded |
|-------|------------------|
| `aliyun` (default) | Alibaba Cloud only (37 tools) |
| `aws` | AWS only (13 tools) |
| `aliyun,aws` | Both providers (50 tools) |

AWS tools are prefixed with `aws_` (e.g., `aws_list_findings`, `aws_ping`).
Alibaba Cloud tools have no prefix (e.g., `list_security_events`, `ping`).

**AWS services covered:** Security Hub, GuardDuty, WAF, CloudTrail, IAM, EC2.

---

## Repository Structure

| Path | Purpose |
|------|---------|
| `blueteam.py` | Entry point — wires ConnectOnion Agent + TUI + plugins |
| `connectonion_qwen/` | Custom Qwen provider, plugins, config |
| `connectonion_qwen/tools.py` | Thin dispatcher — loads tools from active providers |
| `connectonion_qwen/providers/` | Provider components (aliyun/, aws/) |
| `connectonion_qwen/providers/aliyun/tools.py` | 37 Alibaba Cloud tool functions |
| `connectonion_qwen/providers/aws/tools.py` | 13 AWS tool functions |
| `connectonion_qwen/plugins.py` | HITL approval gate + compliance logger |
| `connectonion_qwen/qwen_llm.py` | Custom LLM provider with thinking-mode internal streaming |
| `skills/blueteam-autopilot-ops/scripts/` | 17 bash scripts called by tools (demo vs. real dispatch) |
| `skills/blueteam-autopilot-core/fixtures/` | 15 demo fixture JSON files (default mode) |
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
bash skills/blueteam-autopilot-ops/scripts/list-events.sh

# Real mode
SECURITY_CENTER_MODE=real bash skills/blueteam-autopilot-ops/scripts/list-events.sh
```

Scripts source `.env` automatically from project root.

### Troubleshooting real mode

1. Verify credentials: `aliyun configure list`
2. Test CLI: `aliyun sas describe-version-config`
3. Check region auto-discovery: scripts call `skills/blueteam-autopilot-ops/scripts/_discover-region.sh`
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
| `blueteam-autopilot-knowledge` | Compliance docs, runbooks, GRC sync | Yes (tools call get-knowledge.sh) |
| `blueteam-autopilot-reports` | Incident report templates + render script | Yes (generate_incident_report tool) |
| `blueteam-autopilot-compat` | CLI compatibility validation | No (dev/test utility) |
| `alibaba-security-ops` | Legacy CLI skill (project evolution) | No |

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
