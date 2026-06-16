---
name: blueteam-autopilot-knowledge
description: >
  On-demand knowledge base for BlueTeam Autopilot. Contains compliance
  controls, runbooks, policies, and infrastructure references. Use when
  needing detailed compliance citations or operational procedures.
allowed-tools:
  - Bash
  - Read
---

# BlueTeam Autopilot - Knowledge Base

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

| Document | Type | Purpose | Fetch Command |
|----------|------|---------|---------------|
| `nist-csf.md` | Compliance | NIST Cybersecurity Framework (PR.PT-4, DE.AE-2, RS.RP-1) | `fetch-knowledge.sh nist-csf` |
| `soc2-cc6.md` | Compliance | SOC 2 Type II CC6 controls (CC6.1, CC6.8) | `fetch-knowledge.sh soc2-cc6` |

**When to Reference:**
- **NIST CSF:** Justifying detection/correlation requirements (DE.AE-2), response planning (RS.RP-1)
- **SOC 2 CC6:** Justifying human approval requirements (CC6.8.3), perimeter defense (CC6.1)

---

### Runbooks

| Document | Type | Purpose | Fetch Command |
|----------|------|---------|---------------|
| `runbook-waf-triage.md` | Runbook | WAF perimeter threat triage (RUN-SEC-042) | `fetch-knowledge.sh runbook-waf-triage` |

**When to Reference:**
- During incident response following standardized procedures
- Citing rollback procedures in action proposals
- Training new analysts on triage workflow

---

### Policies

| Document | Type | Purpose | Fetch Command |
|----------|------|---------|---------------|
| `trusted-networks.md` | Policy | Corporate VPN + monitoring IP whitelist | `fetch-knowledge.sh trusted-networks` |

**When to Reference:**
- Cross-referencing attacker IPs before proposing blocks
- Flagging potentially compromised internal assets
- Distinguishing external attacks from insider threats

---

### Infrastructure

| Document | Type | Purpose | Fetch Command |
|----------|------|---------|---------------|
| `asset-inventory.md` | Infrastructure | Asset topology reference (dynamic discovery) | `fetch-knowledge.sh asset-inventory` |

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

To update a knowledge document:

1. Edit the source file in `secops/` directory
2. Copy to `documents/` directory (or use symlink)
3. Test with `fetch-knowledge.sh <type>`
4. Verify compliance citations are still accurate

**Important:** Changes to compliance controls should be reviewed by security team before deployment.
