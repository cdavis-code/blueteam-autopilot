/// Maps to the JSON shape returned by the backend's `StoredRecommendation.toJson()`.
///
/// The nested `proposal` field mirrors `ActionProposal` from
/// `alibaba_security_agent`.
class RecommendationModel {
  final String recommendationId;
  final String incidentId;
  final String status; // PENDING, APPROVED, REJECTED, APPLIED, FAILED
  final String? executionLog;
  final int createdAt;
  final ActionProposalModel proposal;

  const RecommendationModel({
    required this.recommendationId,
    required this.incidentId,
    required this.status,
    this.executionLog,
    required this.createdAt,
    required this.proposal,
  });

  factory RecommendationModel.fromJson(Map<String, dynamic> json) {
    return RecommendationModel(
      recommendationId: json['recommendationId'] as String? ?? '',
      incidentId: json['incidentId'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      executionLog: json['executionLog'] as String?,
      createdAt: json['createdAt'] as int? ?? 0,
      proposal: ActionProposalModel.fromJson(
        json['proposal'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Mirrors `ActionProposal` JSON from alibaba_security_agent.
class ActionProposalModel {
  final String reasoning;
  final String recommendedPolicyId;
  final String expectedEffects;
  final String rollbackPlan;
  final String riskLevel;
  final bool requiresApproval;
  final List<String> complianceControls;
  final String? eventId;
  final bool trustedNetworkMatch;

  const ActionProposalModel({
    required this.reasoning,
    required this.recommendedPolicyId,
    required this.expectedEffects,
    required this.rollbackPlan,
    required this.riskLevel,
    this.requiresApproval = true,
    this.complianceControls = const [],
    this.eventId,
    this.trustedNetworkMatch = false,
  });

  factory ActionProposalModel.fromJson(Map<String, dynamic> json) {
    return ActionProposalModel(
      reasoning: json['reasoning'] as String? ?? '',
      recommendedPolicyId: json['recommendedPolicyId'] as String? ?? '',
      expectedEffects: json['expectedEffects'] as String? ?? '',
      rollbackPlan: json['rollbackPlan'] as String? ?? '',
      riskLevel: json['riskLevel'] as String? ?? 'MEDIUM',
      requiresApproval: json['requiresApproval'] as bool? ?? true,
      complianceControls:
          (json['complianceControls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      eventId: json['eventId'] as String?,
      trustedNetworkMatch: json['trustedNetworkMatch'] as bool? ?? false,
    );
  }
}

/// Response from the analyze endpoint.
class AnalysisResultModel {
  final List<String> incidentIds;
  final List<String> skippedEventIds;
  final Map<String, dynamic> errors;

  const AnalysisResultModel({
    this.incidentIds = const [],
    this.skippedEventIds = const [],
    this.errors = const {},
  });

  factory AnalysisResultModel.fromJson(Map<String, dynamic> json) {
    return AnalysisResultModel(
      incidentIds:
          (json['incidentIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      skippedEventIds:
          (json['skippedEventIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      errors: json['errors'] as Map<String, dynamic>? ?? const {},
    );
  }
}

/// Response from the execute recommendation endpoint.
class ExecutionResultModel {
  final String recommendationId;
  final String status;
  final String? log;

  const ExecutionResultModel({
    required this.recommendationId,
    required this.status,
    this.log,
  });

  factory ExecutionResultModel.fromJson(Map<String, dynamic> json) {
    return ExecutionResultModel(
      recommendationId: json['recommendationId'] as String? ?? '',
      status: json['status'] as String? ?? 'UNKNOWN',
      log: json['log'] as String?,
    );
  }
}
