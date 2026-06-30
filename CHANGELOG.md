# Changelog

All notable changes to the Alibaba Blueteam project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] — 2026-06-30

### Added

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
