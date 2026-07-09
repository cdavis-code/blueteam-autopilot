---
name: blueteam-autopilot-knowledge
description: >
  On-demand knowledge base for BlueTeam. Contains compliance
  controls, runbooks, policies, and infrastructure references. Use when
  needing detailed compliance citations or operational procedures.
allowed-tools:
  - Bash
  - Read
---

# BlueTeam - Knowledge Base

> **Environment Independence:**
> Knowledge documents contain example values marked with `{{VARIABLE}}` syntax or
> labeled as "EXAMPLE". Always use dynamic data from MCP tools for real operations.
> Environment-specific documents (e.g., trusted-networks.md) are auto-generated
> by the `blueteam-autopilot-prep` skill during environment setup.

On-demand knowledge documents for compliance controls, runbooks, policies, and infrastructure.

## When to Use

Invoke this skill when:
- Citing specific compliance control IDs in formal reports
- Referencing full runbook procedures during incident response
- Looking up trusted network IP ranges
- Understanding organizational security policies

**Knowledge Fetching Policy:** Do NOT fetch knowledge documents for every event.
Only fetch when:
1. User explicitly asks for compliance details or policy text
2. Generating formal incident reports requiring control citations
3. Proposing state-changing actions needing policy references
4. User asks knowledge-seeking questions ("what does policy X say?")

For routine triage, use the condensed context in [blueteam-autopilot-core](../blueteam-autopilot-core/SKILL.md).

---

## Document Catalog

### Compliance Controls

| Document | Type | Source | Purpose | Fetch Command |
|----------|------|--------|---------|---------------|
| `nist-csf.md` | Compliance | GRC | NIST Cybersecurity Framework (PR.PT-4, DE.AE-2, RS.RP-1) | `fetch-knowledge.sh nist-csf` |
| `soc2-cc6.md` | Compliance | GRC | SOC 2 Type II CC6 controls (CC6.1, CC6.8) | `fetch-knowledge.sh soc2-cc6` |

**When to Reference:**
- **NIST CSF:** Justifying detection/correlation requirements (DE.AE-2), response planning (RS.RP-1)
- **SOC 2 CC6:** Justifying human approval requirements (CC6.8.3), perimeter defense (CC6.1)

---

### Runbooks

| Document | Type | Source | Purpose | Fetch Command |
|----------|------|--------|---------|---------------|
| `runbook-waf-triage.md` | Runbook | Manual | WAF perimeter threat triage (RUN-SEC-042) | `fetch-knowledge.sh runbook-waf-triage` |

**When to Reference:**
- During incident response following standardized procedures
- Citing rollback procedures in action proposals
- Training new analysts on triage workflow

---

### Policies

| Document | Type | Source | Purpose | Fetch Command |
|----------|------|--------|---------|---------------|
| `trusted-networks.md` | Policy | Auto-generated | Corporate VPN + monitoring IP whitelist | `fetch-knowledge.sh trusted-networks` |

**When to Reference:**
- Cross-referencing attacker IPs before proposing blocks
- Flagging potentially compromised internal assets
- Distinguishing external attacks from insider threats

---

### Infrastructure

| Document | Type | Source | Purpose | Fetch Command |
|----------|------|--------|---------|---------------|
| `asset-inventory.md` | Infrastructure | Dynamic | Asset topology reference (discovered via `list_assets`) | `fetch-knowledge.sh asset-inventory` |

**When to Reference:**
- Understanding asset relationships during deep-dive
- Identifying SOC 2 scope assets
- Mapping affected assets to business impact

---

## Fetch Script

**Location:** `scripts/fetch-knowledge.sh`

**Usage:**
```bash
# Fetch specific document
./scripts/fetch-knowledge.sh nist-csf
./scripts/fetch-knowledge.sh soc2-cc6
./scripts/fetch-knowledge.sh runbook-waf-triage
./scripts/fetch-knowledge.sh trusted-networks
./scripts/fetch-knowledge.sh asset-inventory

# List available documents
./scripts/fetch-knowledge.sh
```

**Output:** Document content to stdout (Markdown format)

---

## GRC Sync

### Overview

GRC-sourced compliance documents (NIST CSF, SOC2) can be synchronized from your GRC tool of record. The sync infrastructure keeps local knowledge documents aligned with the authoritative framework definitions in your GRC platform.

### Sync Commands

**Location:** `scripts/grc-sync.sh`

```bash
# List all policies and their sync status
./scripts/grc-sync.sh --list

# Preview what would be synced (no writes)
./scripts/grc-sync.sh --dry-run

# Sync all GRC-enabled policies
./scripts/grc-sync.sh

# Sync a specific policy only
./scripts/grc-sync.sh nist-csf
./scripts/grc-sync.sh soc2-cc6

# Test with demo mode (no live GRC instance needed)
GRC_MODE=demo ./scripts/grc-sync.sh --dry-run
GRC_MODE=demo ./scripts/grc-sync.sh nist-csf
```

### Webhook Receiver

**Location:** `scripts/grc-webhook.sh`

```bash
# Trigger sync for a specific framework update
echo '{"event":"framework_update","library":"NIST CSF v2.0"}' | ./scripts/grc-webhook.sh

# Trigger full sync of all GRC policies
./scripts/grc-webhook.sh --request-body '{"event":"sync_all"}'
```

### Source-Priority Resolution

`fetch-knowledge.sh` implements a priority chain for document resolution:

1. **GRC-synced version** (`documents/grc-synced/<doc>.md`) — used when `source=grc` and sync has been performed
2. **Bundled default** (`documents/<doc>.md`) — fallback when GRC is enabled but not yet synced
3. **Warning** — logged if GRC is enabled but document hasn't been synced

### Policy Configuration

**Location:** `../blueteam-autopilot-prep/scripts/configure-policies.sh`

Interactive wizard for configuring GRC provider connections and policy sync settings. Updates `policies.json` — the single source of truth for all policy declarations.

---

## Decision Tree: Which Document to Fetch?

```
User needs compliance details?
├─ NIST CSF controls (DE.AE-2, RS.RP-1, PR.PT-4)?
│  └─ Fetch: nist-csf.md
├─ SOC 2 controls (CC6.1, CC6.8.3)?
│  └─ Fetch: soc2-cc6.md
└─ Change Management Policy?
   └─ (Reference condensed context in core SKILL.md)

User needs operational procedure?
├─ WAF triage steps?
│  └─ Fetch: runbook-waf-triage.md
└─ Rollback procedure?
   └─ Fetch: runbook-waf-triage.md (Section 3)

User asks about IP/address?
├─ Is it a source IP in an attack?
│  └─ Fetch: trusted-networks.md
└─ Is it an asset IP?
   └─ Fetch: asset-inventory.md

GRC sync needed?
├─ Compliance document out of date?
│  └─ Run: grc-sync.sh <policy_id>
├─ New GRC framework available?
│  └─ Run: configure-policies.sh (wizard)
└─ Verify sync status?
   └─ Run: grc-sync.sh --list
```

---

## Integration with Core Skill

The [blueteam-autopilot-core](../blueteam-autopilot-core/) skill references these documents:

- **Behavior 2 (Deep-Dive):** Fetch `nist-csf` for full control mapping
- **Behavior 4 (Action Proposal):** Fetch `soc2-cc6` for approval gate details
- **Behavior 5 (Reporting):** Fetch `nist-csf` and `soc2-cc6` for formal reports

**MCP Tool Alternative:**
If MCP server is available, use:
```
get_knowledge_document(type="compliance_nist")
get_knowledge_document(type="compliance_soc2")
get_knowledge_document(type="runbook_waf_triage")
get_knowledge_document(type="trusted_networks")
```

---

## GRC Provider Architecture

### Plugin Pattern

GRC integration uses a provider plugin pattern under `grc-providers/`. Each provider is a standalone shell script that implements three contract functions:

| Function | Purpose | Returns |
|----------|---------|---------|
| `grc_connect()` | Authenticate and validate connectivity | 0 on success, 1 on failure |
| `grc_list_frameworks()` | List available compliance frameworks | JSON array to stdout |
| `grc_get_framework(id)` | Export framework controls as Markdown | Markdown to stdout |

### Provider Contract

All providers source `grc-providers/_template.sh` and override the three contract functions. The template defines standard environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `GRC_MODE` | `demo` for offline testing, empty for live | (empty) |
| `GRC_BASE_URL` | GRC tool base URL | from policies.json |
| `GRC_EMAIL` | Authentication email | from policies.json |
| `GRC_API_TOKEN` | API token (alternative to password) | from policies.json |
| `GRC_VERIFY_SSL` | Verify SSL certificates | `false` |

### CISO Assistant Community Provider

**File:** `grc-providers/ciso-assistant.sh`

Implements the provider contract against [CISO Assistant Community](https://github.com/intuitem/ciso-assistant-community):

| API Endpoint | Used By | Method |
|-------------|---------|--------|
| `/api/iam/login/` | `grc_connect()` | POST |
| `/api/stored-libraries/` | `grc_list_frameworks()` | GET |
| `/api/requirement-nodes/?library=<id>` | `grc_get_framework()` | GET |

Auth: `POST /api/iam/login/` with `{"email":"...","password":"..."}` → `Authorization: Token <token>` header.

### Adding a New Provider

1. Copy `grc-providers/_template.sh` to `grc-providers/<provider>.sh`
2. Implement `grc_connect()`, `grc_list_frameworks()`, `grc_get_framework()`
3. Add demo mode fixture data in `grc_get_framework()` for offline testing
4. Register the provider in `policies.json` under `grc_providers`
5. Assign policies to the provider via their `grc.provider` field

---

## Document Sources

All knowledge documents are sourced from the `secops/` directory in the project root:

| Skill Document | Source File |
|----------------|-------------|
| `documents/nist-csf.md` | `secops/compliance_nist_csf_de_excerpt.md` |
| `documents/soc2-cc6.md` | `secops/compliance_soc2_cc6_excerpt.md` |
| `documents/runbook-waf-triage.md` | `secops/runbook_secops_waf_mitigation.md` |
| `documents/trusted-networks.md` | `secops/trusted_networks.md` (enhanced) |
| `documents/asset-inventory.md` | Generated (assets discovered dynamically) |

---

## Updating Knowledge Documents

### Manual Documents

To update a knowledge document:

1. Edit the source file in `secops/` directory
2. Copy to `documents/` directory (or use symlink)
3. Test with `fetch-knowledge.sh <type>`
4. Verify compliance citations are still accurate

### GRC-Sourced Documents

For GRC-sourced compliance documents (NIST CSF, SOC2):

1. Update the framework in your GRC tool (CISO Assistant Community)
2. Run `grc-sync.sh <policy_id>` to pull the latest version
3. The sync script automatically:
   - Archives the previous version to `documents/archive/`
   - Writes the new version to `documents/grc-synced/`
   - Appends an entry to `sync-log.jsonl`
4. Verify with `grc-sync.sh --list`

**Important:** Changes to compliance controls should be reviewed by security team before deployment.
