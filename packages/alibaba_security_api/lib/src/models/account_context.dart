import 'package:json_annotation/json_annotation.dart';

part 'account_context.g.dart';

/// Minimal account and region metadata to help agents reason about scope.
@JsonSerializable()
class AccountContext {
  /// The configured Alibaba Cloud region (e.g., "cn-hangzhou").
  final String region;

  /// Security Center edition if discoverable (e.g., Basic, Advanced).
  final String? securityCenterEdition;

  /// Whether Agentic SOC is enabled for this account.
  final bool agenticSocEnabled;

  /// The execution mode (real or dry-run).
  final String mode;

  const AccountContext({
    required this.region,
    this.securityCenterEdition,
    this.agenticSocEnabled = false,
    required this.mode,
  });

  factory AccountContext.fromJson(Map<String, dynamic> json) =>
      _$AccountContextFromJson(json);

  Map<String, dynamic> toJson() => _$AccountContextToJson(this);
}
