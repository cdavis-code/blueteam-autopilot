// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'action_proposal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActionProposal _$ActionProposalFromJson(Map<String, dynamic> json) =>
    ActionProposal(
      reasoning: json['reasoning'] as String,
      recommendedPolicyId: json['recommendedPolicyId'] as String,
      expectedEffects: json['expectedEffects'] as String,
      rollbackPlan: json['rollbackPlan'] as String,
      riskLevel: json['riskLevel'] as String,
      requiresApproval: json['requiresApproval'] as bool? ?? true,
      complianceControls:
          (json['complianceControls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      eventId: json['eventId'] as String?,
      trustedNetworkMatch: json['trustedNetworkMatch'] as bool? ?? false,
    );

Map<String, dynamic> _$ActionProposalToJson(ActionProposal instance) =>
    <String, dynamic>{
      'reasoning': instance.reasoning,
      'recommendedPolicyId': instance.recommendedPolicyId,
      'expectedEffects': instance.expectedEffects,
      'rollbackPlan': instance.rollbackPlan,
      'riskLevel': instance.riskLevel,
      'requiresApproval': instance.requiresApproval,
      'complianceControls': instance.complianceControls,
      'eventId': instance.eventId,
      'trustedNetworkMatch': instance.trustedNetworkMatch,
    };
