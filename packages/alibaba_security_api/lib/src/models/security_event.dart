import 'package:json_annotation/json_annotation.dart';

part 'security_event.g.dart';

/// An asset affected by a security event.
@JsonSerializable()
class AffectedAsset {
  /// Unique identifier of the asset.
  final String assetId;

  /// Type of asset (e.g., ECS, SLB, RDS).
  final String assetType;

  /// Alibaba Cloud region where the asset resides.
  final String? region;

  const AffectedAsset({
    required this.assetId,
    required this.assetType,
    this.region,
  });

  factory AffectedAsset.fromJson(Map<String, dynamic> json) =>
      _$AffectedAssetFromJson(json);

  Map<String, dynamic> toJson() => _$AffectedAssetToJson(this);
}

/// A security event produced by Agentic SOC.
///
/// Security events are higher-level incident objects that may aggregate
/// multiple alerts from different sources (WAF, CWPP, Cloud Firewall, etc.).
@JsonSerializable(explicitToJson: true)
class SecurityEvent {
  /// Unique identifier of the event.
  final String eventId;

  /// Human-readable title summarizing the event.
  final String title;

  /// Severity level: LOW, MEDIUM, HIGH, or CRITICAL.
  final String severity;

  /// Source products that contributed to this event.
  final List<String> sourceProducts;

  /// Assets affected by this event.
  final List<AffectedAsset> affectedAssets;

  /// ISO-8601 timestamp of when the event was first observed.
  final String? firstSeen;

  /// ISO-8601 timestamp of when the event was last updated.
  final String? lastSeen;

  const SecurityEvent({
    required this.eventId,
    required this.title,
    required this.severity,
    this.sourceProducts = const [],
    this.affectedAssets = const [],
    this.firstSeen,
    this.lastSeen,
  });

  factory SecurityEvent.fromJson(Map<String, dynamic> json) =>
      _$SecurityEventFromJson(json);

  Map<String, dynamic> toJson() => _$SecurityEventToJson(this);
}

/// A stage in an attack chain, representing a phase of the attack lifecycle.
@JsonSerializable()
class AttackChainStage {
  /// Name of the attack stage (e.g., "Reconnaissance", "Exploitation").
  final String stage;

  /// Human-readable description of what occurred at this stage.
  final String description;

  const AttackChainStage({required this.stage, required this.description});

  factory AttackChainStage.fromJson(Map<String, dynamic> json) =>
      _$AttackChainStageFromJson(json);

  Map<String, dynamic> toJson() => _$AttackChainStageToJson(this);
}

/// Detailed information about a security event, including attack chain,
/// attacker info, and related alerts/vulnerabilities.
@JsonSerializable(explicitToJson: true)
class SecurityEventDetail {
  /// Unique identifier of the event.
  final String eventId;

  /// Human-readable title.
  final String title;

  /// Severity level.
  final String severity;

  /// Ordered attack chain stages.
  final List<AttackChainStage> attackChain;

  /// Source product that generated the primary alert (e.g., WAF, HostDefense).
  final String? source;

  /// IDs or summaries of related alerts.
  final List<String> relatedAlerts;

  /// Attacker IP addresses.
  final List<String> attackers;

  /// Countries or regions of attacker IPs, if available.
  final List<String> attackerCountries;

  /// Related vulnerability IDs or CVE identifiers.
  final List<String> relatedVulnerabilities;

  /// Raw opaque JSON from the underlying API for advanced consumers.
  final Map<String, dynamic>? raw;

  const SecurityEventDetail({
    required this.eventId,
    required this.title,
    required this.severity,
    this.attackChain = const [],
    this.source,
    this.relatedAlerts = const [],
    this.attackers = const [],
    this.attackerCountries = const [],
    this.relatedVulnerabilities = const [],
    this.raw,
  });

  factory SecurityEventDetail.fromJson(Map<String, dynamic> json) =>
      _$SecurityEventDetailFromJson(json);

  Map<String, dynamic> toJson() => _$SecurityEventDetailToJson(this);
}
