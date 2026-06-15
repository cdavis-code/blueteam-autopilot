// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'response_policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResponsePolicy _$ResponsePolicyFromJson(Map<String, dynamic> json) =>
    ResponsePolicy(
      policyId: json['policyId'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      triggerType: json['triggerType'] as String?,
      actionType: json['actionType'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$ResponsePolicyToJson(ResponsePolicy instance) =>
    <String, dynamic>{
      'policyId': instance.policyId,
      'name': instance.name,
      'description': instance.description,
      'triggerType': instance.triggerType,
      'actionType': instance.actionType,
      'isEnabled': instance.isEnabled,
    };

ExecuteResponseResult _$ExecuteResponseResultFromJson(
  Map<String, dynamic> json,
) => ExecuteResponseResult(
  policyId: json['policyId'] as String,
  eventId: json['eventId'] as String?,
  mode: json['mode'] as String,
  result: json['result'] as String,
  raw: json['raw'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ExecuteResponseResultToJson(
  ExecuteResponseResult instance,
) => <String, dynamic>{
  'policyId': instance.policyId,
  'eventId': instance.eventId,
  'mode': instance.mode,
  'result': instance.result,
  'raw': instance.raw,
};
