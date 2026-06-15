import '../models/action_proposal.dart';
import '../models/incident_report.dart';
import '../models/vulnerability_prioritization.dart';

/// Markdown report rendering functions for the Qwen Autopilot agent's
/// structured outputs.
class ReportTemplates {
  ReportTemplates._();

  /// Renders a full incident report as Markdown.
  static String renderIncidentReport(IncidentReport report) {
    final buf = StringBuffer();

    buf.writeln('# Incident Report: ${report.title}');
    buf.writeln();
    buf.writeln('| Field | Value |');
    buf.writeln('|-------|-------|');
    buf.writeln('| **Event ID** | `${report.eventId}` |');
    buf.writeln('| **Severity** | ${report.severity} |');
    buf.writeln('| **Generated** | ${report.generatedAt ?? 'N/A'} |');
    buf.writeln();

    // AI Summary
    buf.writeln('## AI Summary');
    buf.writeln();
    buf.writeln(report.aiSummary);
    buf.writeln();

    // Root Cause
    buf.writeln('## Root Cause');
    buf.writeln();
    buf.writeln(report.rootCause);
    buf.writeln();

    // Business Impact
    buf.writeln('## Business Impact');
    buf.writeln();
    buf.writeln(report.businessImpact);
    buf.writeln();

    // Attack Chain
    if (report.attackChain.isNotEmpty) {
      buf.writeln('## Attack Chain');
      buf.writeln();
      for (final stage in report.attackChain) {
        buf.writeln('### ${stage.stage}');
        buf.writeln(stage.description);
        buf.writeln();
      }
    }

    // Affected Assets
    if (report.affectedAssets.isNotEmpty) {
      buf.writeln('## Affected Assets');
      buf.writeln();
      for (final asset in report.affectedAssets) {
        buf.writeln('- $asset');
      }
      buf.writeln();
    }

    // Source IPs
    if (report.sourceIps.isNotEmpty) {
      buf.writeln('## Source IPs');
      buf.writeln();
      for (final ip in report.sourceIps) {
        buf.writeln('- `$ip`');
      }
      buf.writeln();
    }

    // Related CVEs
    if (report.relatedCves.isNotEmpty) {
      buf.writeln('## Related CVEs');
      buf.writeln();
      for (final cve in report.relatedCves) {
        buf.writeln('- $cve');
      }
      buf.writeln();
    }

    // Compliance Controls
    if (report.complianceControls.isNotEmpty) {
      buf.writeln('## Compliance Controls');
      buf.writeln();
      for (final control in report.complianceControls) {
        buf.writeln('- $control');
      }
      buf.writeln();
    }

    return buf.toString();
  }

  /// Renders a vulnerability prioritization as Markdown with export-ready
  /// format (spec 9.3 — "Export to Markdown" for ticket creation).
  static String renderVulnerabilityTriage(
    VulnerabilityPrioritization prioritization,
  ) {
    final buf = StringBuffer();

    buf.writeln('# Vulnerability Prioritization Report');
    buf.writeln();
    buf.writeln('| Field | Value |');
    buf.writeln('|-------|-------|');
    buf.writeln('| **Total Analyzed** | ${prioritization.totalAnalyzed} |');
    buf.writeln('| **Ranked** | ${prioritization.rankedVulns.length} |');
    buf.writeln('| **Generated** | ${prioritization.generatedAt ?? 'N/A'} |');
    buf.writeln();

    // Overall Strategy
    buf.writeln('## Remediation Strategy');
    buf.writeln();
    buf.writeln(prioritization.remediationSteps);
    buf.writeln();

    // Ranked Table
    buf.writeln('## Ranked Vulnerabilities');
    buf.writeln();
    buf.writeln(
      '| Rank | Vul ID | Name | Severity | CVE | Asset | Remediation |',
    );
    buf.writeln(
      '|------|--------|------|----------|-----|-------|-------------|',
    );
    for (final v in prioritization.rankedVulns) {
      buf.writeln(
        '| ${v.rank} | `${v.vulId}` | ${v.name} | ${v.severity} '
        '| ${v.cveId ?? 'N/A'} | ${v.assetId ?? 'N/A'} '
        '| ${v.remediationSteps} |',
      );
    }
    buf.writeln();

    // Asset Grouping
    if (prioritization.assetGrouping.isNotEmpty) {
      buf.writeln('## Vulnerabilities by Asset');
      buf.writeln();
      for (final entry in prioritization.assetGrouping.entries) {
        buf.writeln('### ${entry.key}');
        for (final vulId in entry.value) {
          buf.writeln('- `$vulId`');
        }
        buf.writeln();
      }
    }

    return buf.toString();
  }

  /// Renders an action proposal as Markdown for human review.
  static String renderActionProposal(ActionProposal proposal) {
    final buf = StringBuffer();

    buf.writeln('# Action Proposal');
    buf.writeln();

    // Approval warning
    if (proposal.trustedNetworkMatch) {
      buf.writeln('> **WARNING: Source IP matched a trusted network.**');
      buf.writeln(
        '> This may indicate a compromised internal asset rather than '
        'an external attacker. Escalate to the security team before '
        'proceeding.',
      );
      buf.writeln();
    }

    buf.writeln('> **Human approval is REQUIRED before execution.**');
    buf.writeln(
      '> Per SOC 2 CC6.8.3 and the Change Management Policy, all '
      'state-changing actions must be authorized by a verified security '
      'engineer.',
    );
    buf.writeln();

    buf.writeln('| Field | Value |');
    buf.writeln('|-------|-------|');
    buf.writeln('| **Policy ID** | `${proposal.recommendedPolicyId}` |');
    buf.writeln('| **Risk Level** | ${proposal.riskLevel} |');
    buf.writeln(
      '| **Event ID** | ${proposal.eventId != null ? '`${proposal.eventId}`' : 'N/A'} |',
    );
    buf.writeln('| **Dry-Run** | Recommended first |');
    buf.writeln();

    // Reasoning
    buf.writeln('## Reasoning');
    buf.writeln();
    buf.writeln(proposal.reasoning);
    buf.writeln();

    // Expected Effects
    buf.writeln('## Expected Effects');
    buf.writeln();
    buf.writeln(proposal.expectedEffects);
    buf.writeln();

    // Rollback Plan
    buf.writeln('## Rollback Plan');
    buf.writeln();
    buf.writeln(proposal.rollbackPlan);
    buf.writeln();

    // Compliance Controls
    if (proposal.complianceControls.isNotEmpty) {
      buf.writeln('## Compliance Controls');
      buf.writeln();
      for (final control in proposal.complianceControls) {
        buf.writeln('- $control');
      }
      buf.writeln();
    }

    // Approval section
    buf.writeln('---');
    buf.writeln();
    buf.writeln('**[ ] APPROVED** — I authorize execution of this action.');
    buf.writeln();
    buf.writeln('Approver: ________________');
    buf.writeln('Date: ________________');
    buf.writeln();

    return buf.toString();
  }

  /// Renders a runbook-aligned checklist for an incident report.
  ///
  /// Produces a step-by-step checklist matching the WAF triage runbook
  /// (RUN-SEC-042) structure.
  static String renderRunbookChecklist(IncidentReport report) {
    final buf = StringBuffer();

    buf.writeln('# WAF Triage Runbook Checklist');
    buf.writeln('**Runbook:** RUN-SEC-042 | **Event:** `${report.eventId}`');
    buf.writeln();

    buf.writeln('## Step 1: Contextual Discovery');
    buf.writeln('- [ ] Identified targeted asset and domain name');
    buf.writeln('- [ ] Extracted source IP and geographic flags');
    buf.writeln('- [ ] Confirmed exploit vector from incident payloads');
    buf.writeln('- [ ] Cross-referenced against trusted networks');
    buf.writeln();

    buf.writeln('## Step 2: Attack Chain Verification');
    for (final stage in report.attackChain) {
      buf.writeln('- [ ] ${stage.stage}: ${stage.description}');
    }
    buf.writeln();

    buf.writeln('## Step 3: Mitigation Execution');
    buf.writeln('- [ ] Verified active response policy exists');
    buf.writeln('- [ ] Staged temporary network block for source IP');
    buf.writeln('- [ ] **Human analyst approved mitigation**');
    buf.writeln();

    buf.writeln('## Step 4: Rollback & Logging');
    buf.writeln('- [ ] Documented mitigation actions and blocked count');
    buf.writeln('- [ ] Exported ticket for audit evidence');
    buf.writeln();

    buf.writeln('## Compliance Evidence');
    for (final control in report.complianceControls) {
      buf.writeln('- [x] $control');
    }
    buf.writeln();

    return buf.toString();
  }
}
