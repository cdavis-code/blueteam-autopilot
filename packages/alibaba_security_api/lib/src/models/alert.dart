import 'package:json_annotation/json_annotation.dart';

part 'alert.g.dart';

/// A single security alert from a specific source product.
@JsonSerializable()
class Alert {
  /// Unique identifier of the alert.
  final String alertId;

  /// Rule identifier that triggered this alert.
  final String? ruleId;

  /// Severity of the alert.
  final String severity;

  /// Human-readable message describing the alert.
  final String message;

  /// Source product that generated this alert (e.g., WAF, SecurityCenter).
  final String? source;

  /// ISO-8601 timestamp when the alert was created.
  final String? timestamp;

  const Alert({
    required this.alertId,
    this.ruleId,
    required this.severity,
    required this.message,
    this.source,
    this.timestamp,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => _$AlertFromJson(json);

  Map<String, dynamic> toJson() => _$AlertToJson(this);
}

/// Alerts grouped by their source product name.
///
/// Example:
/// ```json
/// {
///   "eventId": "evt-123",
///   "alertsBySource": {
///     "WAF": [{ "alertId": "...", "ruleId": "...", "severity": "HIGH", "message": "SQLi attempt" }],
///     "SecurityCenter": [...]
///   }
/// }
/// ```
@JsonSerializable(explicitToJson: true)
class AlertsForEvent {
  /// The event ID these alerts belong to.
  final String eventId;

  /// Alerts keyed by source product name.
  final Map<String, List<Alert>> alertsBySource;

  const AlertsForEvent({
    required this.eventId,
    this.alertsBySource = const {},
  });

  factory AlertsForEvent.fromJson(Map<String, dynamic> json) =>
      _$AlertsForEventFromJson(json);

  Map<String, dynamic> toJson() => _$AlertsForEventToJson(this);
}
