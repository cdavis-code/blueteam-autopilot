# Qwen Autopilot Agent Package

## Context

Spec section 6 defines a Qwen-based agent that consumes the MCP server tools (C1-C9) to triage incidents, synthesize recommendations, and propose response actions. The agent runs in **Qwen Cloud** (hosted), so we need prompt artifacts, output models, and deployment config -- not a full agent runtime.

The `secops/` directory contains operational knowledge base documents that the agent must reference in its system prompt and behavior logic:
- **asset_inventory.md** -- Network topology: ecs.muayid.com = Customer Payment Portal API, SOC 2 scope
- **change_management_policy.md** -- Firewall/ACL changes require human authorization (justifies HITL checkpoint)
- **compliance_nist_csf_de_excerpt.md** -- NIST CSF controls: network bounding (PR.PT-4), anomaly correlation (DE.AE-2), response planning (RS.RP-1)
- **compliance_soc2_cc6_excerpt.md** -- SOC 2 CC6 controls: WAF mandatory, logging, automated mitigation with audit trail + admin validation
- **runbook_secops_waf_mitigation.md** -- Step-by-step WAF triage: contextual discovery -> mitigation execution (with human approval) -> rollback/logging
- **trusted_networks.md** -- Corporate/whitelisted IPs that must not be blindly blocked (flag as "potentially compromised internal asset" instead)

## Task 1: Create the agent package scaffold

Add `packages/alibaba_security_agent/` to the workspace.

**Files:**
- `packages/alibaba_security_agent/pubspec.yaml` -- depends on `alibaba_security_api` (workspace), `json_annotation`; no runtime dependencies on MCP or LLM SDKs
- `packages/alibaba_security_agent/analysis_options.yaml`
- `packages/alibaba_security_agent/lib/alibaba_security_agent.dart` -- barrel export
- Update root `pubspec.yaml` workspace list to include the new package

## Task 2: SecOps knowledge base loader

Create `lib/src/knowledge/secops_knowledge.dart` to embed the secops documents as agent context:

- `SecOpsKnowledge` class with static getters for each document as Dart string constants (inlined from the secops/ markdown files at build time)
- `SecOpsKnowledge.summary()` -- returns a condensed version for token-budget-constrained prompts
- `SecOpsKnowledge.complianceControls()` -- extracts just the NIST CSF + SOC 2 controls as a structured list
- `SecOpsKnowledge.runbook()` -- returns the WAF triage runbook steps
- `SecOpsKnowledge.trustedNetworks()` -- returns the trusted/whitelisted IP context

These constants are the authoritative reference the system prompt uses when reasoning about compliance requirements, runbook steps, asset context, and trusted networks.

## Task 3: System prompt (core deliverable)

Create `lib/src/prompts/system_prompt.dart` containing the full Qwen Autopilot system prompt as a Dart constant. This prompt implements spec 6.1 and 6.2 and **embeds the secops knowledge base**:

- **Role**: "You are BlueTeam Autopilot, a cautious but efficient SecOps analyst..."
- **Tool awareness**: Lists all MCP tools (ping, list_security_events, get_security_event_detail, list_alerts_for_event, list_vulnerabilities, get_vulnerability_detail, list_response_policies, execute_response_policy, get_account_context, plus WAF tools)
- **Operational context** (from secops/ knowledge base):
  - Asset inventory: ecs.muayid.com hosts Customer Payment Portal API under SOC 2 scope
  - Compliance obligations: NIST CSF (PR.PT-4, DE.AE-2, RS.RP-1) and SOC 2 CC6.1/CC6.8 controls
  - Change management: firewall/ACL changes require human authorization
  - Trusted networks: corporate IPs must be flagged as "potentially compromised" not blindly blocked
- **5 core behaviors** (from spec 6.2, informed by runbook):
  1. Incident discovery -- call list_security_events, sort by severity; cross-reference asset_inventory context
  2. Incident deep-dive -- get_security_event_detail + list_alerts_for_event; correlate signals per DE.AE-2; follow runbook Step 2.1 (identify asset, source IP, exploit vector)
  3. Recommendation synthesis -- list_response_policies, match to incident; list_vulnerabilities for prioritization; align with RS.RP-1 (balance availability vs risk)
  4. Action proposal -- generate structured proposal (reasoning, policy_id, expected_effects, rollback_plan); NEVER call execute_response_policy without explicit human approval (per CC6.8.3 and change_management_policy); check trusted_networks before proposing IP blocks
  5. Reporting -- produce concise Markdown summaries with compliance control references; include audit trail per runbook Step 3

Also create `lib/src/prompts/behavior_prompts.dart` with focused sub-prompts for each behavior that can be composed or used independently. Each behavior prompt should reference the relevant secops controls and runbook steps.

## Task 4: Structured output models

Create Dart models for the agent's structured outputs (spec 6.2.4):

- `lib/src/models/incident_report.dart` -- `IncidentReport` with fields: eventId, title, severity, aiSummary (markdown), rootCause, businessImpact, attackChain, affectedAssets, sourceIps, relatedCves
- `lib/src/models/action_proposal.dart` -- `ActionProposal` with fields: reasoning, recommendedPolicyId, expectedEffects, rollbackPlan, riskLevel, requiresApproval (always true)
- `lib/src/models/vulnerability_prioritization.dart` -- `VulnerabilityPrioritization` with fields: rankedVulns (list), remediationSteps, assetGrouping
- Use `json_serializable` with `explicitToJson: true` (matching existing convention)

## Task 5: Markdown report templates

Create `lib/src/templates/report_templates.dart` with Dart functions that render the structured models as Markdown:

- `renderIncidentReport(IncidentReport)` -- produces the full incident summary for the UI / tickets, includes compliance control references
- `renderVulnerabilityTriage(VulnerabilityPrioritization)` -- produces the prioritized vuln list with "Export to Markdown" (spec 9.3)
- `renderActionProposal(ActionProposal)` -- produces the human-approval-ready action summary with change-management authorization reminder
- `renderRunbookChecklist(IncidentReport)` -- produces a step-by-step checklist aligned with runbook_secops_waf_mitigation.md

## Task 6: Qwen Cloud deployment configuration

Create `lib/src/config/agent_config.dart`:

- `AgentConfig` class with fields: mcpServerEndpoint, systemPrompt (loads from prompts), defaultTimeRangeMinutes, defaultDryRun, maxIncidentsPerRun
- `AgentConfig.fromEnvironment()` -- reads from env vars (MCP_ENDPOINT, etc.)
- `toQwenCloudManifest()` -- generates a JSON manifest suitable for Qwen Cloud agent configuration

Create `config/qwen_agent_manifest.json.example` -- example deployment manifest.

## Task 7: Tests

Create `test/alibaba_security_agent_test.dart`:

- System prompt content tests (verify it mentions all tools, all behaviors, dry-run constraint, compliance controls, trusted network awareness)
- SecOps knowledge loader tests (verify all 6 documents are accessible, summary/truncation works)
- Model serialization round-trips (IncidentReport, ActionProposal, VulnerabilityPrioritization)
- Template rendering tests (verify Markdown output contains expected sections including compliance refs and runbook checklist)
- AgentConfig tests

## Task 8: Verify

- `dart pub get` in workspace root
- `dart analyze .` -- 0 issues
- `dart run build_runner build` in agent package (for json_serializable)
- `dart test` in agent package -- all pass
- Verify existing packages still pass: `dart analyze .` + `dart test` in api, cli, mcp
