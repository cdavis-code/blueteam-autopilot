import 'package:json_annotation/json_annotation.dart';

part 'incident_report.g.dart';

/// A stage in the attack chain within an incident report.
@JsonSerializable()
class AttackChainEntry {
  /// Attack stage name (e.g., "Reconnaissance", "Exploitation").
  final String stage;

  /// Description of what occurred at this stage.
  final String description;

  const AttackChainEntry({required this.stage, required this.description});

  factory AttackChainEntry.fromJson(Map<String, dynamic> json) =>
      _$AttackChainEntryFromJson(json);

  Map<String, dynamic> toJson() => _$AttackChainEntryToJson(this);
}

/// AI-generated incident report combining event data, analysis, and
/// compliance context.
@JsonSerializable(explicitToJson: true)
class IncidentReport {
  /// The security event ID this report covers.
  final String eventId;

  /// Human-readable incident title.
  final String title;

  /// Severity level (LOW, MEDIUM, HIGH, CRITICAL).
  final String severity;

  /// Full AI summary in Markdown format.
  final String aiSummary;

  /// Identified root cause of the incident.
  final String rootCause;

  /// Business impact assessment.
  final String businessImpact;

  /// Ordered attack chain stages.
  final List<AttackChainEntry> attackChain;

  /// Affected asset identifiers and descriptions.
  final List<String> affectedAssets;

  /// Source/attacker IP addresses.
  final List<String> sourceIps;

  /// Related CVE identifiers.
  final List<String> relatedCves;

  /// Compliance controls referenced (e.g., "NIST CSF DE.AE-2").
  final List<String> complianceControls;

  /// ISO-8601 timestamp when the report was generated.
  final String? generatedAt;

  const IncidentReport({
    required this.eventId,
    required this.title,
    required this.severity,
    required this.aiSummary,
    required this.rootCause,
    required this.businessImpact,
    this.attackChain = const [],
    this.affectedAssets = const [],
    this.sourceIps = const [],
    this.relatedCves = const [],
    this.complianceControls = const [],
    this.generatedAt,
  });

  factory IncidentReport.fromJson(Map<String, dynamic> json) =>
      _$IncidentReportFromJson(json);

  Map<String, dynamic> toJson() => _$IncidentReportToJson(this);
}
