// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountContext _$AccountContextFromJson(Map<String, dynamic> json) =>
    AccountContext(
      region: json['region'] as String,
      securityCenterEdition: json['securityCenterEdition'] as String?,
      agenticSocEnabled: json['agenticSocEnabled'] as bool? ?? false,
      mode: json['mode'] as String,
    );

Map<String, dynamic> _$AccountContextToJson(AccountContext instance) =>
    <String, dynamic>{
      'region': instance.region,
      'securityCenterEdition': instance.securityCenterEdition,
      'agenticSocEnabled': instance.agenticSocEnabled,
      'mode': instance.mode,
    };
