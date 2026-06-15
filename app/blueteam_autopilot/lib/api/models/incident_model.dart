/// Maps to the JSON shape returned by the backend's `StoredIncident.toJson()`.
///
/// The nested `report` field contains an [IncidentReportModel] which mirrors
/// the `IncidentReport` from `alibaba_security_agent`.
class IncidentModel {
  final String incidentId;
  final String accountId;
  final String status;
  final int createdAt;
  final int updatedAt;
  final IncidentReportModel report;

  const IncidentModel({
    required this.incidentId,
    required this.accountId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.report,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      incidentId: json['incidentId'] as String? ?? '',
      accountId: json['accountId'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      createdAt: json['createdAt'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      report: IncidentReportModel.fromJson(
        json['report'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  DateTime get createdAtDt => DateTime.fromMillisecondsSinceEpoch(createdAt);
  DateTime get updatedAtDt => DateTime.fromMillisecondsSinceEpoch(updatedAt);
}

/// Mirrors `IncidentReport` JSON from alibaba_security_agent.
class IncidentReportModel {
  final String eventId;
  final String title;
  final String severity;
  final String aiSummary;
  final String rootCause;
  final String businessImpact;
  final List<AttackChainEntryModel> attackChain;
  final List<String> affectedAssets;
  final List<String> sourceIps;
  final List<String> relatedCves;
  final List<String> complianceControls;
  final String? generatedAt;

  const IncidentReportModel({
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

  factory IncidentReportModel.fromJson(Map<String, dynamic> json) {
    return IncidentReportModel(
      eventId: json['eventId'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      severity: json['severity'] as String? ?? 'MEDIUM',
      aiSummary: json['aiSummary'] as String? ?? '',
      rootCause: json['rootCause'] as String? ?? '',
      businessImpact: json['businessImpact'] as String? ?? '',
      attackChain:
          (json['attackChain'] as List<dynamic>?)
              ?.map(
                (e) =>
                    AttackChainEntryModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      affectedAssets:
          (json['affectedAssets'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sourceIps:
          (json['sourceIps'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      relatedCves:
          (json['relatedCves'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      complianceControls:
          (json['complianceControls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      generatedAt: json['generatedAt'] as String?,
    );
  }

  /// Whether AI analysis has been performed (non-empty summary).
  bool get hasAiAnalysis => aiSummary.isNotEmpty;
}

class AttackChainEntryModel {
  final String stage;
  final String description;

  const AttackChainEntryModel({required this.stage, required this.description});

  factory AttackChainEntryModel.fromJson(Map<String, dynamic> json) {
    return AttackChainEntryModel(
      stage: json['stage'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}
