# Changelog

All notable changes to the Alibaba Blueteam project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-06-16

### Added

#### Core Skills Framework
- **blueteam-autopilot-core** — Central skill orchestrator with behavioral guardrails, compliance quick-reference, and MCP tools catalog
- **blueteam-autopilot-ops** — 17 CLI scripts for live Alibaba Cloud Security Center operations (events, alerts, vulnerabilities, WAF, assets, response policies, log delivery verification)
- **blueteam-autopilot-knowledge** — Curated security knowledge base (SOC 2 CC6, NIST CSF, asset inventory, trusted networks, WAF triage runbook) with fetch script
- **blueteam-autopilot-prep** — Pre-flight validation and trusted-network generation scripts for environment setup
- **blueteam-autopilot-reports** — Report generation pipeline with JSON schemas, Markdown templates, and Python renderer (incident reports, action proposals, vulnerability prioritization, runbook checklists)

#### Demo & Offline Mode
- **skills/fixtures/** — 15 JSON fixture files providing realistic mock responses for all 17 CLI scripts, enabling full demo mode with zero Alibaba Cloud credentials
- **skills/MODES.md** — Dual-mode (live / demo) architecture documentation

#### Documentation & Branding
- **README.md** — Project overview with SVG banner, getting-started guide, architecture diagram, and dual-mode instructions
- **assets/banner.svg** — Professional SVG banner with gradient design, shield icon, and project stats
- **skills/AUTONOMOUS_SETUP.md** — Autonomous agent setup and onboarding guide
- **skills/ENVIRONMENT_INDEPENDENCE.md** — Environment independence design principles
- **skills/alibaba-security-ops/SKILL.md** — Alibaba Security Ops integration skill definition

#### Configuration
- **.gitignore** — Repository hygiene (Python bytecode, Dart/Flutter artifacts, IDE files, environment secrets, OS files)
