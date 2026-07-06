---
name: threat-hunt
description: Proactive threat hunting — collect security data, analyze attack patterns, correlate with knowledge base, and produce risk-scored threat assessment
version: 1.0
requires-hitl: false
phases:
  - id: collect
    persona: data-collector
    tools: [get_account_context, list_assets, list_security_events, get_waf_instance_info, list_waf_security_events, verify_log_delivery]
    thinking: true
    output: raw_security_data
  - id: analyze
    persona: threat-analyst
    tools: [list_waf_top_ips, list_waf_top_rules, get_security_event_detail, list_alerts_for_event]
    thinking: true
    input: raw_security_data
    output: attack_patterns
  - id: correlate
    persona: intelligence-analyst
    tools: [get_knowledge_document, list_knowledge_documents, list_vulnerabilities, get_vulnerability_detail]
    thinking: true
    input: attack_patterns
    output: correlated_threats
  - id: report
    persona: threat-reporter
    tools: [generate_incident_report, store_incident_memory]
    thinking: false
    input: correlated_threats
    output: threat_assessment
---
# Threat Hunt Workflow

Proactive threat hunting across cloud security data.
Executes 4 phases: collect → analyze → correlate → report.

## Cloud Provider Awareness

This workflow supports both Alibaba Cloud and AWS. Use provider-appropriate tools:
- Alibaba Cloud: `list_security_events`, `list_waf_security_events`, `list_waf_top_ips`
- AWS: `aws_list_findings`, `aws_list_guardduty_findings`, `aws_list_waf_events`, `aws_list_cloudtrail_events`

## Phase: collect

Gather all available security data from every source:

1. Call `get_account_context` to establish region and edition.
2. Call `list_assets` to discover cloud assets dynamically.
3. Call `list_security_events` with appropriate time range and severity filter.
4. If Security Center events are empty (Basic/Advanced edition), fall back to WAF:
   - Call `get_waf_instance_info` to confirm WAF is active.
   - Call `list_waf_security_events` with the same time range.
   - Call `verify_log_delivery` to confirm the logging pipeline is healthy.
5. Note the data sources available for subsequent phases.

Produce a structured inventory of all raw security data including:
- Total event count by severity
- Asset inventory with compliance scope tags
- Data source availability (Security Center vs. WAF vs. both)
- Time window covered by the data

## Phase: analyze

Identify attack patterns from the collected data:

1. Call `list_waf_top_ips` to identify most active attacker IPs.
2. Call `list_waf_top_rules` to identify most-triggered WAF rules.
3. For high-severity events, call `get_security_event_detail` to extract:
   - Attack chain stages
   - Source IP geolocation
   - Exploit vectors and CVEs
4. Call `list_alerts_for_event` for underlying alert grouping.

Analyze patterns across the dataset:
- **Attack type distribution**: SQLi, XSS, LFI, SSRF, brute force, etc.
- **Frequency analysis**: Are attacks increasing, sustained, or sporadic?
- **Geo-clustering**: Are attacks originating from specific regions?
- **Target concentration**: Are specific assets being targeted disproportionately?
- **Temporal patterns**: Time-of-day or day-of-week attack trends.

Produce a structured attack pattern analysis with categorized findings.

## Phase: correlate

Cross-reference attack patterns against knowledge base and vulnerability data:

1. Call `list_knowledge_documents` to see available guidance.
2. Call `get_knowledge_document` for relevant threat intel or compliance docs:
   - Trusted network definitions (to exclude internal IPs from threat list)
   - NIST CSF guidance (for control mapping)
   - SOC 2 requirements (for audit relevance)
3. Call `list_vulnerabilities` to identify unpatched systems.
4. For critical/high vulnerabilities, call `get_vulnerability_detail`.

Correlation logic:
- **Attack-to-vulnerability mapping**: Do observed attack patterns target
  known vulnerabilities in the environment?
- **Threat intel matching**: Do attacker IPs or techniques match known
  threat actor TTPs documented in knowledge base?
- **Insider threat detection**: Do any attack source IPs match trusted
  networks? Flag as potential compromised internal assets.
- **Control effectiveness**: Are WAF rules and response policies catching
  the attacks, or are gaps visible?

Produce a correlated threat assessment with:
- Confirmed threats (attack + vulnerability + no mitigation)
- Potential threats (attack observed but mitigated)
- Insider threat indicators (trusted network matches)
- Control gaps (attack types not covered by current rules)

## Phase: report

Synthesize findings into a risk-scored threat assessment:

Call `generate_incident_report` with all correlated findings as
additional_context for comprehensive synthesis.

Produce a threat assessment report with these sections:

1. **Executive Summary** — Overall threat posture rating (Critical/High/Medium/Low),
   key findings in 2-3 sentences.
2. **Threat Landscape** — Attack type distribution, top attacker IPs, geographic
   origins, temporal trends.
3. **Vulnerability Exposure** — Unpatched systems targeted by observed attacks,
   CVSS scores, remediation priority.
4. **Control Effectiveness** — Which controls are working, which have gaps,
   WAF rule coverage analysis.
5. **Insider Threat Indicators** — Trusted network IP matches, anomalous
   internal activity patterns.
6. **Risk-Scored Findings** — Table of findings with risk scores (0.0-1.0),
   affected assets, and recommended mitigations.
7. **Recommended Actions** — Prioritized remediation roadmap:
   - Immediate: Block active threats, patch critical vulnerabilities
   - Short-term: Add WAF rules for uncovered attack types
   - Long-term: Improve detection coverage, review trusted networks
8. **Audit Trail** — All tools called, data sources consulted, time window.

Map findings to compliance controls:
- WAF blocking effectiveness -> NIST CSF PR.PT-4, SOC 2 CC6.1
- Anomaly detection coverage -> NIST CSF DE.AE-2, SOC 2 CC6.8
- Response readiness -> NIST CSF RS.RP-1, SOC 2 CC6.8

After generating the report, call `store_incident_memory` with a concise
summary of the threat patterns discovered (attack types, top IPs, risk level)
to build institutional memory for future similarity search.
