---
name: compliance-audit
description: Compliance audit — inventory assets and controls, map against NIST CSF/SOC 2, collect evidence of control effectiveness, produce gap analysis report
version: 1.0
requires-hitl: false
phases:
  - id: inventory
    persona: asset-auditor
    tools: [get_account_context, list_assets, list_ram_users, list_ram_roles, list_ram_policies, list_response_policies]
    thinking: true
    output: asset_inventory
  - id: map
    persona: compliance-analyst
    tools: [get_knowledge_document, list_knowledge_documents, analyze_trust_relationships, score_risk_matrix]
    thinking: true
    input: asset_inventory
    output: control_mapping
  - id: evidence
    persona: evidence-collector
    tools: [list_security_events, list_waf_security_events, list_vulnerabilities, get_ram_credential_report]
    thinking: true
    input: control_mapping
    output: audit_evidence
  - id: report
    persona: audit-reporter
    tools: [generate_incident_report, store_incident_memory]
    thinking: false
    input: [control_mapping, audit_evidence]
    output: gap_analysis
---
# Compliance Audit Workflow

Compliance gap analysis across Alibaba Cloud environment.
Executes 4 phases: inventory → map → evidence → report.

## Phase: inventory

Enumerate all assets, IAM entities, policies, and response automation.

### Tool Invocations

1. Establish region and edition:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/get_account_context.py
   ```

2. Discover cloud assets (tag each by compliance scope):
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_assets.py
   ```
   Tag "SOC 2 scope" or "sensitive" assets as high-priority.
   Note asset types (ECS, RDS, SLB, OSS, etc.)

3. Enumerate all RAM users:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_ram_users.py
   ```

4. Enumerate all RAM roles:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_ram_roles.py
   ```

5. Enumerate all policies (system + custom):
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_ram_policies.py
   ```

6. Identify automated response rules:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_response_policies.py
   ```

### Expected Output

Produce a structured inventory including:
- Asset count by type and compliance scope
- IAM entity count (users, roles, policies)
- Response automation coverage (how many policy rules exist)
- Any assets without associated response policies

## Phase: map

Map controls against NIST CSF functions and SOC 2 trust service criteria.

### Tool Invocations

1. See available compliance guidance:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_knowledge.py
   ```

2. Fetch NIST CSF and SOC 2 reference docs:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/get_knowledge.py compliance_nist
   python skills/blueteam-autopilot-ops/scripts/get_knowledge.py compliance_soc2
   ```

3. Assess IAM trust configurations:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/analyze_trust_relationships.py
   ```

4. Identify risk findings:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/score_risk_matrix.py
   ```

### Control Assessment

For each control, assess implementation status:

**NIST CSF Functions:**
- **PR.PT-4 (Network Bounding)**: Is WAF deployed? Are IP blacklists active?
  Are trusted networks defined?
- **DE.AE-2 (Anomaly Detection)**: Are security events being detected?
  Is alert correlation working? Are WAF rules triggering?
- **RS.RP-1 (Response Planning)**: Are response policies configured?
  Is HITL approval enforced? Is rollback capability documented?

**SOC 2 Trust Service Criteria:**
- **CC6.1 (Boundary Protection)**: WAF coverage, network segmentation,
  trusted network definitions.
- **CC6.8 (Unauthorized Activity Triage)**: Event detection rates,
  alert response times, investigation procedures.

### Expected Output

Produce a control-by-control mapping with status:
- **Implemented**: Control is active and configured
- **Partial**: Control exists but has gaps
- **Gap**: Control is missing or not configured

## Phase: evidence

Gather time-windowed evidence of control effectiveness.

### Tool Invocations

1. Assess detection coverage:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_events.py [time_range]
   ```
   Analyze: How many events detected? Severity distribution?
   Are events being correlated across sources?

2. If Security Center events are empty, assess via WAF:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_waf_events.py [time_range]
   ```
   WAF events demonstrate perimeter control effectiveness.
   Note: Basic/Advanced editions don't generate Security Center events.

3. Assess vulnerability management:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/list_vulnerabilities.py [time_range]
   ```
   Analyze: How many open vulnerabilities? Are critical vulns being
   remediated within SLA? Patch coverage percentage.

4. Assess credential hygiene:
   ```bash
   python skills/blueteam-autopilot-ops/scripts/get_ram_credential_report.py
   ```
   Analyze: Stale access keys (>90 days)? Users without MFA?
   Over-privileged roles?

### Evidence Categories

- **Detection effectiveness**: Are controls actually catching threats?
- **Response readiness**: Can the organization respond to incidents?
- **Credential hygiene**: Are IAM best practices followed?
- **Vulnerability management**: Is patching keeping up with discoveries?

## Phase: report

Produce a comprehensive gap analysis report.

### Tool Invocations

Aggregate all audit evidence from prior phases into a comprehensive report.
This is a harness-native synthesis task — combine data from all prior
script invocations.

For institutional memory: save a concise summary of the compliance gaps
found (control references, risk ratings) to a JSON file for future
similarity search.

### Report Sections

1. **Executive Summary** — Overall compliance posture (Compliant/Partial/Non-Compliant),
   key findings in 2-3 sentences, audit scope and time window.
2. **Control Status Matrix** — Table of all controls with status (Implemented/Partial/Gap),
   evidence reference, and risk rating.
3. **NIST CSF Assessment** — Control-by-control analysis for PR.PT-4, DE.AE-2, RS.RP-1
   with evidence and findings.
4. **SOC 2 Assessment** — Control-by-control analysis for CC6.1, CC6.8 with evidence
   and findings.
5. **IAM Posture** — Credential hygiene findings, trust relationship risks,
   over-privileged entities, stale credentials.
6. **Vulnerability Management** — Patch coverage, SLA compliance, critical exposure,
   remediation trends.
7. **Gap Analysis** — Prioritized list of gaps with:
   - Control reference (NIST CSF / SOC 2)
   - Current state vs. expected state
   - Risk rating (Critical/High/Medium/Low)
   - Remediation recommendation
   - Effort estimate (Low/Medium/High)
8. **Remediation Roadmap** — Prioritized action plan:
   - Immediate: Address critical gaps (e.g., missing WAF, no response policies)
   - Short-term: Fix partial controls (e.g., improve detection coverage)
   - Long-term: Enhance maturity (e.g., implement continuous monitoring)
9. **Audit Trail** — All tools called, data sources consulted, time window,
   evidence collected.

### Compliance Control Mapping

- WAF deployment and rules → NIST CSF PR.PT-4, SOC 2 CC6.1
- Event detection and correlation → NIST CSF DE.AE-2, SOC 2 CC6.8
- Response policy configuration → NIST CSF RS.RP-1, SOC 2 CC6.8
- IAM credential management → SOC 2 CC6.1, CC6.8
- Vulnerability remediation → NIST CSF RS.RP-1
---
name: compliance-audit
description: Compliance audit — inventory assets and controls, map against NIST CSF/SOC 2, collect evidence of control effectiveness, produce gap analysis report
version: 1.0
requires-hitl: false
phases:
  - id: inventory
    persona: asset-auditor
    tools: [get_account_context, list_assets, list_ram_users, list_ram_roles, list_ram_policies, list_response_policies]
    thinking: true
    output: asset_inventory
  - id: map
    persona: compliance-analyst
    tools: [get_knowledge_document, list_knowledge_documents, analyze_trust_relationships, score_risk_matrix]
    thinking: true
    input: asset_inventory
    output: control_mapping
  - id: evidence
    persona: evidence-collector
    tools: [list_security_events, list_waf_security_events, list_vulnerabilities, get_ram_credential_report]
    thinking: true
    input: control_mapping
    output: audit_evidence
  - id: report
    persona: audit-reporter
    tools: [generate_incident_report, store_incident_memory]
    thinking: false
    input: [control_mapping, audit_evidence]
    output: gap_analysis
---
# Compliance Audit Workflow

Compliance gap analysis across Alibaba Cloud environment.
Executes 4 phases: inventory → map → evidence → report.

## Phase: inventory

Enumerate all assets, IAM entities, policies, and response automation:

1. Call `get_account_context` to establish region and edition.
2. Call `list_assets` to discover cloud assets dynamically.
   Tag each asset by compliance scope:
   - "SOC 2 scope" or "sensitive" assets are high-priority
   - Note asset types (ECS, RDS, SLB, OSS, etc.)
3. Call `list_ram_users` to enumerate all RAM users.
4. Call `list_ram_roles` to enumerate all RAM roles.
5. Call `list_ram_policies` to enumerate all policies (system + custom).
6. Call `list_response_policies` to identify automated response rules.

Produce a structured inventory including:
- Asset count by type and compliance scope
- IAM entity count (users, roles, policies)
- Response automation coverage (how many policy rules exist)
- Any assets without associated response policies

## Phase: map

Map controls against NIST CSF functions and SOC 2 trust service criteria:

1. Call `list_knowledge_documents` to see available compliance guidance.
2. Call `get_knowledge_document` for NIST CSF and SOC 2 reference docs:
   - nist-csf.md for control definitions
   - soc2-cc6.md for trust service criteria
3. Call `analyze_trust_relationships` to assess IAM trust configurations.
4. Call `score_risk_matrix` to identify risk findings.

For each control, assess implementation status:

**NIST CSF Functions:**
- **PR.PT-4 (Network Bounding)**: Is WAF deployed? Are IP blacklists active?
  Are trusted networks defined?
- **DE.AE-2 (Anomaly Detection)**: Are security events being detected?
  Is alert correlation working? Are WAF rules triggering?
- **RS.RP-1 (Response Planning)**: Are response policies configured?
  Is HITL approval enforced? Is rollback capability documented?

**SOC 2 Trust Service Criteria:**
- **CC6.1 (Boundary Protection)**: WAF coverage, network segmentation,
  trusted network definitions.
- **CC6.8 (Unauthorized Activity Triage)**: Event detection rates,
  alert response times, investigation procedures.

Produce a control-by-control mapping with status:
- **Implemented**: Control is active and configured
- **Partial**: Control exists but has gaps
- **Gap**: Control is missing or not configured

## Phase: evidence

Gather time-windowed evidence of control effectiveness:

1. Call `list_security_events` to assess detection coverage:
   - How many events detected in the time window?
   - Severity distribution (CRITICAL/HIGH/MEDIUM/LOW)?
   - Are events being correlated across sources?
2. If Security Center events are empty, call `list_waf_security_events`:
   - WAF events demonstrate perimeter control effectiveness
   - Note: Basic/Advanced editions don't generate Security Center events
3. Call `list_vulnerabilities` to assess vulnerability management:
   - How many open vulnerabilities?
   - Are critical vulnerabilities being remediated within SLA?
   - Patch coverage percentage.
4. Call `get_ram_credential_report` to assess credential hygiene:
   - Stale access keys (>90 days old)?
   - Users without MFA?
   - Over-privileged roles?

Evidence collection should demonstrate:
- **Detection effectiveness**: Are controls actually catching threats?
- **Response readiness**: Can the organization respond to incidents?
- **Credential hygiene**: Are IAM best practices followed?
- **Vulnerability management**: Is patching keeping up with discoveries?

## Phase: report

Produce a comprehensive gap analysis report:

Call `generate_incident_report` with all audit evidence as
additional_context for comprehensive synthesis.

Produce a compliance audit report with these sections:

1. **Executive Summary** — Overall compliance posture (Compliant/Partial/Non-Compliant),
   key findings in 2-3 sentences, audit scope and time window.
2. **Control Status Matrix** — Table of all controls with status (Implemented/Partial/Gap),
   evidence reference, and risk rating.
3. **NIST CSF Assessment** — Control-by-control analysis for PR.PT-4, DE.AE-2, RS.RP-1
   with evidence and findings.
4. **SOC 2 Assessment** — Control-by-control analysis for CC6.1, CC6.8 with evidence
   and findings.
5. **IAM Posture** — Credential hygiene findings, trust relationship risks,
   over-privileged entities, stale credentials.
6. **Vulnerability Management** — Patch coverage, SLA compliance, critical exposure,
   remediation trends.
7. **Gap Analysis** — Prioritized list of gaps with:
   - Control reference (NIST CSF / SOC 2)
   - Current state vs. expected state
   - Risk rating (Critical/High/Medium/Low)
   - Remediation recommendation
   - Effort estimate (Low/Medium/High)
8. **Remediation Roadmap** — Prioritized action plan:
   - Immediate: Address critical gaps (e.g., missing WAF, no response policies)
   - Short-term: Fix partial controls (e.g., improve detection coverage)
   - Long-term: Enhance maturity (e.g., implement continuous monitoring)
9. **Audit Trail** — All tools called, data sources consulted, time window,
   evidence collected.

Map all findings to compliance controls:
- WAF deployment and rules -> NIST CSF PR.PT-4, SOC 2 CC6.1
- Event detection and correlation -> NIST CSF DE.AE-2, SOC 2 CC6.8
- Response policy configuration -> NIST CSF RS.RP-1, SOC 2 CC6.8
- IAM credential management -> SOC 2 CC6.1, CC6.8
- Vulnerability remediation -> NIST CSF RS.RP-1

After generating the report, call `store_incident_memory` with a concise
summary of the compliance gaps found (control references, risk ratings)
to build institutional memory for future similarity search.
