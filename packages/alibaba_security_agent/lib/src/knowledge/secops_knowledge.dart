/// Lean SecOps knowledge embedded in the agent system prompt.
///
/// Only the smallest, most-referenced fragments are embedded at prompt-build
/// time. All detailed compliance controls, runbooks, and policies are fetched
/// on-demand via the MCP `get_knowledge_document` tool.
///
/// Asset information is NOT hardcoded here. Instead, the agent discovers
/// assets dynamically at runtime via the `list_assets` MCP tool which queries
/// Security Center's `DescribeCloudCenterInstances` API.
class SecOpsKnowledge {
  SecOpsKnowledge._();

  /// Condensed operational context always present in the system prompt.
  static String summary() => '''
## Operational Context (Condensed)

**Assets:** Discovered dynamically via `list_assets` at session start.
Assets tagged as SOC 2 scope or hosting sensitive workloads elevate events
to HIGH or above regardless of initial severity scoring.
**Compliance:** NIST CSF (PR.PT-4, DE.AE-2, RS.RP-1) + SOC 2 CC6.1/CC6.8.
**Change Mgmt:** Firewall/ACL changes require human authorization.
**Trusted Networks:** Corporate VPN + monitoring IPs must be flagged as
"potentially compromised" — never blindly blocked.
**Runbook:** WAF triage = discover context → verify attack chain → stage
block with human approval → log for audit.
''';

  /// Short asset reasoning framework always present in the system prompt.
  ///
  /// No specific hostnames are embedded — the agent discovers assets
  /// dynamically via `list_assets`.
  static const String assetSummary =
      'Asset inventory is discovered dynamically via `list_assets`. '
      'Any event targeting assets tagged SOC 2 scope or hosting sensitive '
      'workloads → minimum HIGH severity. '
      'Call `list_assets` at session start to build the asset context.';

  /// Short trusted-network reminder always present in the system prompt.
  static const String trustedNetworkReminder =
      'Corporate VPN + monitoring service IPs are trusted. '
      'Flag as "Potentially Compromised Internal Asset" — never blindly block.';
}
