---
name: iam-forensic
description: RAM/IAM security audit with trust analysis, risk scoring, remediation, and drift detection
version: 1.0
requires-hitl: true
phases:
  - id: discovery
    persona: iam-forensic
    tools: [list_ram_users, list_ram_roles, list_ram_policies, get_ram_credential_report]
    thinking: true
    output: iam_inventory
  - id: analysis
    persona: iam-forensic
    tools: [analyze_trust_relationships, score_risk_matrix, get_role_trust_policy, list_attached_policies_for]
    thinking: true
    input: iam_inventory
    output: risk_matrix
  - id: remediation
    persona: remediation-router
    tools: [detach_policy, rotate_access_key, delete_stale_user]
    requires-hitl: true
    input: risk_matrix
    output: remediation_log
  - id: persist
    persona: iam-forensic
    tools: [store_scan_snapshot, diff_previous_scan, store_incident_memory]
    input: [risk_matrix, remediation_log]
    output: scan_record
---
# IAM Forensic Workflow

A comprehensive RAM/IAM security audit that maps trust relationships,
identifies credential risks, and persists findings for cross-incident
drift detection.

## Phase: discovery

Enumerate all RAM entities in the Alibaba Cloud account:

1. **List RAM users** — Call `list_ram_users()` to get all user accounts.
   Note creation dates, last login times, and comments (service accounts
   vs. human users).

2. **List RAM roles** — Call `list_ram_roles()` to get all roles.
   For each role, note the trust policy principal (Service vs. Account)
   and MaxSessionDuration.

3. **List RAM policies** — Call `list_ram_policies()` to get all policies.
   Flag custom policies with wildcard actions or ram:PassRole.

4. **Credential report** — Call `get_ram_credential_report()` to get
   access key ages and staleness analysis.

Produce a structured inventory with all entities and their basic metadata.

## Phase: analysis

Analyze the inventory from the discovery phase for security risks:

1. **Trust relationship analysis** — Call `analyze_trust_relationships()`
   to evaluate all role trust policies. Look for:
   - Cross-account root trust without ExternalId
   - Overly permissive attached policies (AdministratorAccess on non-admin roles)
   - Excessive session durations (>3600s)

2. **Risk matrix scoring** — Call `score_risk_matrix()` to generate
   a unified risk matrix with per-entity scores.

3. **Deep-dive on high-risk entities** — For any entity scored CRITICAL
   or HIGH, call `get_role_trust_policy()` and `list_attached_policies_for()`
   to get full details.

4. **Produce findings** — For each risk found, create a finding with:
   - entity_type, entity_name, risk_score, risk_category
   - description, recommendation

Output a JSON structure with all findings and the overall risk summary.

## Phase: remediation

Based on the risk matrix from the analysis phase, propose and execute
remediation actions. **All actions require human approval (HITL).**

Priority order:
1. **CRITICAL risks first** — Cross-account trust misconfigurations
2. **HIGH risks next** — Over-privileged roles, stale credentials
3. **MEDIUM risks** — Key rotation, policy cleanup

For each remediation action:
- State what will change and why
- The system will prompt for human approval before executing
- Log the action taken

If no remediation is needed (all risks accepted), note that and proceed.

## Phase: persist

Store the scan results for future drift detection:

1. **Store snapshot** — Call `store_scan_snapshot()` with the full
   inventory and findings from this scan.

2. **Diff against previous** — Call `diff_previous_scan()` to compare
   against the most recent prior scan. Report:
   - New entities added since last scan
   - Entities removed since last scan
   - Entities with changed risk scores or status

3. **Produce drift report** — Summarize what changed and whether any
   new risks were introduced.

4. **Store in memory** — Call `store_incident_memory` with a concise
   summary of the key IAM findings (high-risk entities, risk scores)
   to build institutional memory for future similarity search.
