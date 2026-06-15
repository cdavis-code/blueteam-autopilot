// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incident_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttackChainEntry _$AttackChainEntryFromJson(Map<String, dynamic> json) =>
    AttackChainEntry(
      stage: json['stage'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$AttackChainEntryToJson(AttackChainEntry instance) =>
    <String, dynamic>{
      'stage': instance.stage,
      'description': instance.description,
    };

IncidentReport _$IncidentReportFromJson(Map<String, dynamic> json) =>
    IncidentReport(
      eventId: json['eventId'] as String,
      title: json['title'] as String,
      severity: json['severity'] as String,
      aiSummary: json['aiSummary'] as String,
      rootCause: json['rootCause'] as String,
      businessImpact: json['businessImpact'] as String,
      attackChain:
          (json['attackChain'] as List<dynamic>?)
              ?.map((e) => AttackChainEntry.fromJson(e as Map<String, dynamic>))
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

Map<String, dynamic> _$IncidentReportToJson(IncidentReport instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'title': instance.title,
      'severity': instance.severity,
      'aiSummary': instance.aiSummary,
      'rootCause': instance.rootCause,
      'businessImpact': instance.businessImpact,
      'attackChain': instance.attackChain.map((e) => e.toJson()).toList(),
      'affectedAssets': instance.affectedAssets,
      'sourceIps': instance.sourceIps,
      'relatedCves': instance.relatedCves,
      'complianceControls': instance.complianceControls,
      'generatedAt': instance.generatedAt,
    };
