---
name: incident-response
description: Full incident lifecycle — discovery, deep-dive, recommendation, action, and reporting
version: 1.0
requires-hitl: true
phases:
  - id: discovery
    persona: triage
    tools: [get_account_context, list_assets, list_security_events, get_waf_instance_info, list_waf_security_events, verify_log_delivery, list_waf_top_ips, list_waf_top_rules]
    thinking: true
    output: incident_inventory
  - id: deep_dive
    persona: investigator
    tools: [get_security_event_detail, list_alerts_for_event, get_knowledge_document]
    thinking: true
    input: incident_inventory
    output: incident_analysis
  - id: recommendation
    persona: responder
    tools: [list_response_policies, list_vulnerabilities, get_vulnerability_detail, get_knowledge_document]
    thinking: true
    input: incident_analysis
    output: recommendation
  - id: action
    persona: remediation-router
    tools: [execute_response_policy, block_waf_ips]
    requires-hitl: true
    input: recommendation
    output: action_result
  - id: report
    persona: reporter
    tools: [generate_incident_report, store_incident_memory]
    thinking: false
    input: [incident_analysis, recommendation, action_result]
    output: incident_report
---
# Incident Response Workflow

Full incident lifecycle from initial discovery through reporting.
Executes 5 phases in sequence, each with a specialist persona.

## Phase: discovery

Enumerate the security landscape and identify active incidents:

1. Call `get_account_context` to establish region and edition.
2. Call `list_assets` to discover cloud assets dynamically.
3. Call `list_security_events` with appropriate time range and severity filter.
4. Sort results by severity (CRITICAL > HIGH > MEDIUM > LOW).
5. Cross-reference affected assets against the asset list.
   Assets tagged "SOC 2 scope" or "sensitive" elevate events to HIGH+.

**IMPORTANT — Basic/Advanced Edition Fallback:**
If `list_security_events` returns 0 events (empty SuspEvents array), this is
EXPECTED on Basic or Advanced Security Center editions (Enterprise/Ultimate
required for Agentic SOC events). In this case, you MUST immediately fall
back to WAF-based investigation:
1. Call `get_waf_instance_info` to confirm WAF is active.
2. Call `list_waf_security_events` with the same time range — this queries
   SLS directly and contains real attack data (blocked requests, attack
   types, attacker IPs, matched rules).
3. Call `verify_log_delivery` to confirm the logging pipeline is healthy.
4. Use `list_waf_top_ips` and `list_waf_top_rules` for attack pattern analysis.
5. Report WAF events as the primary data source, noting that Security Center
   events require Enterprise edition.
Never report "no events found" without first checking WAF logs.

Produce a structured inventory of all discovered events, affected assets,
and their severity classifications.

## Phase: deep_dive

Analyze specific incidents in detail:

Given an event ID from the discovery phase:
1. Call `get_security_event_detail` — extract attack chain, source IPs, CVEs.
2. Call `list_alerts_for_event` — get underlying alerts grouped by source.
3. Correlate signals per NIST CSF DE.AE-2 (Anomaly Detection).
4. Check attacker IPs against trusted networks.
   If a source IP matches a trusted network, flag as "Potentially Compromised
   Internal Asset" — do NOT propose a perimeter block.

Produce a detailed analysis for each incident including:
- Attack chain reconstruction
- Source IP geolocation and classification (external vs. internal/trusted)
- Affected assets and blast radius
- CVEs or exploit vectors if applicable

## Phase: recommendation

Synthesize response recommendations based on the analysis:

1. Call `list_response_policies` to find matching automation rules.
2. Match incident to policy:
   - WAF attacks (SQLi, XSS, LFI) -> IP blocking policies
   - Host-level threats -> isolation/quarantine policies
   - No matching policy -> recommend creating a new one
3. For vulnerability-driven incidents, call `list_vulnerabilities` and
   `get_vulnerability_detail` for prioritized remediation.
4. Align with NIST CSF RS.RP-1 (Response Planning).

**Knowledge Fetching Policy:**
Do NOT call `get_knowledge_document` for every security event. Call it ONLY when:
- Generating a formal incident report that must cite specific control IDs.
- Proposing a state-changing action and needing policy references.
- The investigation requires compliance details or policy text.

For routine triage, rely on the condensed compliance context:
- NIST CSF: PR.PT-4 (Network Bounding), DE.AE-2 (Anomaly Detection), RS.RP-1 (Response Planning)
- SOC 2: CC6.1 (Boundary Protection), CC6.8 (Unauthorized Activity Triage)

Produce a prioritized list of recommended actions with policy IDs and risk levels.

## Phase: action

Execute approved response actions. **All state-changing actions require human approval (HITL).**

### Action Proposal
Generate a structured JSON proposal for human review:
```json
{
  "reasoning": "Why this action is needed",
  "recommendedPolicyId": "pol-xxx",
  "expectedEffects": "What will change",
  "rollbackPlan": "How to undo if issues arise",
  "riskLevel": "LOW | MEDIUM | HIGH",
  "requiresApproval": true
}
```

Pre-flight checks:
- Cross-reference attacker IPs against trusted networks.
- Default to dry-run simulation (dryRun=true) unless user explicitly opts in.
- Reference SOC 2 CC6.8.3 and NIST CSF controls in the reasoning.
- NEVER execute state-changing actions without explicit human approval.

### Direct WAF IP Blocking
When blocking specific attacker IPs:
1. Cross-reference IPs against trusted networks FIRST (use `get_knowledge_document`
   with type="trusted_networks").
2. Call `block_waf_ips` with dry_run=true to preview the action.
3. Present the dry-run result to the user for approval.
4. Only after explicit user approval, call `block_waf_ips` with dry_run=false.
   This creates a WAF ip_blacklist defense rule via the WAF 3.0 API.
5. The rule is auto-discovered: WAF instance ID and template ID are resolved
   internally — no manual configuration needed.

### Response Policy Execution
When executing a response policy:
1. Call `execute_response_policy` with the policy ID and event ID.
2. The system will prompt for human approval before executing.
3. Log the action taken and its result.

If no action is needed or the user declines, note that and proceed to reporting.

## Phase: report

Generate a comprehensive incident response report.

Call `generate_incident_report(event_id, additional_context)` to aggregate
all investigation data into a single structured context package.
Pass any prior findings in additional_context for richer synthesis.

Produce a comprehensive IR report with these sections:

1. **Summary** — event title, severity, affected assets, one-paragraph overview.
2. **Attack Chain** — stages, source IPs, exploit vectors, geographic origin.
3. **Blast Radius** — scope of impact (systems, data, users affected).
4. **Investigation Timeline** — chronological reconstruction from first
   alert through current state, with data source for each entry.
5. **Confidence Rating** — verdict confidence (0.0-1.0) with justification
   (e.g., 0.85 = True Positive >85% confidence).
6. **Compliance Mapping** — NIST CSF PR.PT-4, DE.AE-2, RS.RP-1; SOC 2 CC6.1, CC6.8.
7. **Recommended Actions** — prioritized action table with policy IDs and risk levels.
8. **Rollback Plan** — how to undo each recommended action.
9. **Audit Trail** — every tool call made, with timestamp and result summary.

Map findings to compliance controls:
- WAF perimeter blocking -> NIST CSF PR.PT-4, SOC 2 CC6.1
- Multi-signal correlation -> NIST CSF DE.AE-2, SOC 2 CC6.8
- Response policy selection -> NIST CSF RS.RP-1, SOC 2 CC6.8
- Human approval requirement -> SOC 2 CC6.8.3
- Audit trail documentation -> NIST CSF DE.AE-2, SOC 2 CC6.8

The report should be suitable for export to ticket systems, compliance
audits, or management review. Include executive summary language.

After generating the report, call `store_incident_memory` with a concise
description of the key findings (attack type, affected assets, severity)
to build institutional memory for future similarity search.
