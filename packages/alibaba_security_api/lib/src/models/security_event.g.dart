// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'security_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AffectedAsset _$AffectedAssetFromJson(Map<String, dynamic> json) =>
    AffectedAsset(
      assetId: json['assetId'] as String,
      assetType: json['assetType'] as String,
      region: json['region'] as String?,
    );

Map<String, dynamic> _$AffectedAssetToJson(AffectedAsset instance) =>
    <String, dynamic>{
      'assetId': instance.assetId,
      'assetType': instance.assetType,
      'region': instance.region,
    };

SecurityEvent _$SecurityEventFromJson(Map<String, dynamic> json) =>
    SecurityEvent(
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      severity: json['severity'] as String,
      sourceProducts:
          (json['sourceProducts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      affectedAssets:
          (json['affectedAssets'] as List<dynamic>?)
              ?.map((e) => AffectedAsset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      firstSeen: json['firstSeen'] as String?,
      lastSeen: json['lastSeen'] as String?,
    );

Map<String, dynamic> _$SecurityEventToJson(SecurityEvent instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'title': instance.title,
      'severity': instance.severity,
      'sourceProducts': instance.sourceProducts,
      'affectedAssets': instance.affectedAssets.map((e) => e.toJson()).toList(),
      'firstSeen': instance.firstSeen,
      'lastSeen': instance.lastSeen,
    };

AttackChainStage _$AttackChainStageFromJson(Map<String, dynamic> json) =>
    AttackChainStage(
      stage: json['stage'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$AttackChainStageToJson(AttackChainStage instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'description': instance.description,
    };

SecurityEventDetail _$SecurityEventDetailFromJson(Map<String, dynamic> json) =>
    SecurityEventDetail(
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      severity: json['severity'] as String,
      attackChain:
          (json['attackChain'] as List<dynamic>?)
              ?.map((e) => AttackChainStage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      source: json['source'] as String?,
      relatedAlerts:
          (json['relatedAlerts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      attackers:
          (json['attackers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      attackerCountries:
          (json['attackerCountries'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      relatedVulnerabilities:
          (json['relatedVulnerabilities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      raw: json['raw'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$SecurityEventDetailToJson(
  SecurityEventDetail instance,
) => <String, dynamic>{
  'eventId': instance.eventId,
  'title': instance.title,
  'severity': instance.severity,
  'attackChain': instance.attackChain.map((e) => e.toJson()).toList(),
  'source': instance.source,
  'relatedAlerts': instance.relatedAlerts,
  'attackers': instance.attackers,
  'attackerCountries': instance.attackerCountries,
  'relatedVulnerabilities': instance.relatedVulnerabilities,
  'raw': instance.raw,
};
