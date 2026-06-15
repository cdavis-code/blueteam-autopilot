// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Alert _$AlertFromJson(Map<String, dynamic> json) => Alert(
  alertId: json['alertId'] as String,
  ruleId: json['ruleId'] as String?,
  severity: json['severity'] as String,
  message: json['message'] as String,
  source: json['source'] as String?,
  timestamp: json['timestamp'] as String?,
);

Map<String, dynamic> _$AlertToJson(Alert instance) => <String, dynamic>{
  'alertId': instance.alertId,
  'ruleId': instance.ruleId,
  'severity': instance.severity,
  'message': instance.message,
  'source': instance.source,
  'timestamp': instance.timestamp,
};

AlertsForEvent _$AlertsForEventFromJson(Map<String, dynamic> json) =>
    AlertsForEvent(
      eventId: json['eventId'] as String,
      alertsBySource:
          (json['alertsBySource'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
              k,
              (e as List<dynamic>)
                  .map((e) => Alert.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ),
          ) ??
          const {},
    );

Map<String, dynamic> _$AlertsForEventToJson(AlertsForEvent instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'alertsBySource': instance.alertsBySource.map(
        (k, e) => MapEntry(k, e.map((e) => e.toJson()).toList()),
      ),
    };
