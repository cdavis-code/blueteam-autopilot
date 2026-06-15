import 'dart:io';

/// Loads knowledge documents from disk or embedded defaults.
///
/// Documents are resolved lazily on each call (always fresh).
/// The knowledge directory is configured via the `KNOWLEDGE_DIR` environment
/// variable, defaulting to `./knowledge/` relative to the MCP server process.
///
/// If a file is not found on disk, the store falls back to embedded defaults
/// so the tool always returns valid content out-of-the-box.
class KnowledgeStore {
  /// Base directory for knowledge document files.
  final String knowledgeDir;

  KnowledgeStore({String? knowledgeDir})
    : knowledgeDir =
          knowledgeDir ??
          Platform.environment['KNOWLEDGE_DIR'] ??
          './knowledge';

  /// Map of document type identifiers to filenames and titles.
  static const Map<String, ({String filename, String title})> _registry = {
    'asset_inventory': (
      filename: 'asset_inventory.md',
      title: 'Asset Inventory — Network Topology',
    ),
    'trusted_networks': (
      filename: 'trusted_networks.md',
      title: 'Trusted Networks / IP Whitelist',
    ),
    'compliance_nist': (
      filename: 'compliance_nist.md',
      title: 'NIST CSF Controls (Detect & Respond)',
    ),
    'compliance_soc2': (
      filename: 'compliance_soc2.md',
      title: 'SOC 2 Type II — CC6.0 Logical Access Controls',
    ),
    'runbook_waf_triage': (
      filename: 'runbook_waf_triage.md',
      title: 'Runbook: WAF Perimeter Threat Triage (RUN-SEC-042)',
    ),
    'policy_change_mgmt': (
      filename: 'policy_change_mgmt.md',
      title: 'Change Management Guidelines',
    ),
  };

  /// All valid document type identifiers.
  static List<String> get documentTypes => _registry.keys.toList()..sort();

  /// List all available knowledge documents with metadata.
  ///
  /// Returns a list of maps each containing `documentType`, `title`, and
  /// `source` (either `file` or `embedded`) so callers can discover what
  /// is available before requesting a specific document.
  List<Map<String, dynamic>> list() {
    return _registry.entries.map((e) {
      final filePath = '$knowledgeDir/${e.value.filename}';
      final hasFile = File(filePath).existsSync();
      return {
        'documentType': e.key,
        'title': e.value.title,
        'source': hasFile ? 'file' : 'embedded',
      };
    }).toList();
  }

  /// Load a knowledge document by type identifier.
  ///
  /// Returns a structured map with `documentType`, `title`, `content`,
  /// `source`, and `lastModified` fields.
  ///
  /// Throws [ArgumentError] if [documentType] is not in the registry.
  Map<String, dynamic> load(String documentType) {
    final entry = _registry[documentType];
    if (entry == null) {
      throw ArgumentError(
        'Unknown knowledge document type: "$documentType". '
        'Valid types: ${documentTypes.join(', ')}',
      );
    }

    final filePath = '$knowledgeDir/${entry.filename}';
    final file = File(filePath);

    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final stat = file.statSync();
      return {
        'documentType': documentType,
        'title': entry.title,
        'content': content.trim(),
        'source': 'file://$filePath',
        'lastModified': stat.modified.toUtc().toIso8601String(),
      };
    }

    // Fall back to embedded defaults
    return {
      'documentType': documentType,
      'title': entry.title,
      'content': _embeddedDefaults[documentType] ?? '',
      'source': 'embedded',
      'lastModified': null,
    };
  }

  /// Embedded fallback content — mirrors the original SecOpsKnowledge
  /// constants. Used only when the knowledge directory files are missing.
  static const Map<String, String> _embeddedDefaults = {
    'asset_inventory': '''
Asset inventory is sourced dynamically from Security Center via the
`list_assets` MCP tool (DescribeCloudCenterInstances API). Call `list_assets`
at session start or during incident discovery to build a live view of the
environment's cloud assets.

## How to Classify Assets

After calling `list_assets`, classify each returned asset by:
1. **SOC 2 Scope** — assets hosting sensitive workloads (payment APIs,
   customer data stores, auth services) are SOC 2 strict scope.
2. **Severity Elevation** — any event targeting SOC 2 scoped assets
   is elevated to HIGH or above regardless of initial severity scoring.
3. **Region Awareness** — cross-reference asset `regionId` with the
   configured region to identify cross-region events.

Place a file named `asset_inventory.md` in the knowledge directory to
override this default with environment-specific asset metadata (hostnames,
ownership, compliance tags, etc.).''',

    'trusted_networks': '''
Corporate office IP ranges and uptime monitoring services are considered
trusted. If an attack originates from a corporate VPN IP or known monitoring
endpoint, the agent MUST flag it as a "Potentially Compromised Internal Asset"
rather than simply blacklisting it.

Trusted sources: Corporate VPN egress IPs, uptime monitoring service IPs
(e.g., Pingdom, Datadog Synthetics), CI/CD runner IPs.

Before proposing any IP block, cross-reference the source IP against this
trusted network list. If a match is found, escalate as a potential insider
threat rather than executing a perimeter block.''',

    'compliance_nist': '''
PR.PT-4: All public endpoints must tunnel through WAF in Block mode.
DE.AE-2: Correlate independent telemetry signals before containment.
RS.RP-1: Mitigation must balance availability against data risk.''',

    'compliance_soc2': '''
CC6.1: Public apps must be fronted by active WAF. Log all blocked attempts.
CC6.8: Continuous threat detection. Automated blocking for scanning behavior.
CC6.8.3: All state-changing actions require explicit human approval.''',

    'runbook_waf_triage': '''
RUN-SEC-042: WAF Perimeter Threat Triage.
Step 2.1: Identify asset, source IP, geographic flags, exploit vector.
Step 2.2: Verify attack chain, stage block, require human approval.
Step 3: Document actions, export ticket for audit.''',

    'policy_change_mgmt': '''
Firewall/ACL changes require emergency change record + human authorization.
Change record must include: justification, scope, rollback plan, approval.
SOC 2 CC6.8.3 mandates administrative validation window.''',
  };
}
