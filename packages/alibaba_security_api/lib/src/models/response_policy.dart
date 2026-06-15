import 'package:json_annotation/json_annotation.dart';

part 'response_policy.g.dart';

/// An Agentic SOC response policy / automation rule.
///
/// Response policies define automated actions taken in response to security
/// events, such as blocking attacker IPs via WAF or quarantining hosts.
@JsonSerializable()
class ResponsePolicy {
  /// Unique identifier of the policy.
  final String policyId;

  /// Human-readable name of the policy.
  final String name;

  /// Description of what the policy does.
  final String? description;

  /// Type of trigger that activates this policy (e.g., "SECURITY_EVENT").
  final String? triggerType;

  /// Type of action the policy performs (e.g., "BLOCK_IP", "QUARANTINE").
  final String? actionType;

  /// Whether the policy is currently enabled.
  final bool isEnabled;

  const ResponsePolicy({
    required this.policyId,
    required this.name,
    this.description,
    this.triggerType,
    this.actionType,
    this.isEnabled = false,
  });

  factory ResponsePolicy.fromJson(Map<String, dynamic> json) =>
      _$ResponsePolicyFromJson(json);

  Map<String, dynamic> toJson() => _$ResponsePolicyToJson(this);
}

/// Result of executing a response policy.
@JsonSerializable()
class ExecuteResponseResult {
  /// The policy that was executed.
  final String policyId;

  /// The event the policy was applied to, if applicable.
  final String? eventId;

  /// Execution mode: "real" or "dry-run".
  final String mode;

  /// Human-readable summary of what happened.
  final String result;

  /// Raw API response or simulated payload (opaque JSON).
  final Map<String, dynamic>? raw;

  const ExecuteResponseResult({
    required this.policyId,
    this.eventId,
    required this.mode,
    required this.result,
    this.raw,
  });

  factory ExecuteResponseResult.fromJson(Map<String, dynamic> json) =>
      _$ExecuteResponseResultFromJson(json);

  Map<String, dynamic> toJson() => _$ExecuteResponseResultToJson(this);
}
