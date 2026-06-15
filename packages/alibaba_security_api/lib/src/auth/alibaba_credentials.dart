import 'dart:io';

/// Alibaba Cloud RAM credentials used for API authentication.
///
/// Credentials can be provided explicitly, loaded from environment variables,
/// or loaded from a configuration file.
class AlibabaCredentials {
  /// The AccessKey ID for API authentication.
  final String accessKeyId;

  /// The AccessKey Secret for API signing.
  final String accessKeySecret;

  /// Optional Security Token for STS (temporary credentials).
  final String? securityToken;

  const AlibabaCredentials({
    required this.accessKeyId,
    required this.accessKeySecret,
    this.securityToken,
  });

  /// Load credentials from environment variables.
  ///
  /// Reads:
  /// - `ALIBABA_ACCESS_KEY_ID`
  /// - `ALIBABA_ACCESS_KEY_SECRET`
  /// - `ALIBABA_SECURITY_TOKEN` (optional, for STS)
  factory AlibabaCredentials.fromEnvironment() {
    final keyId = Platform.environment['ALIBABA_ACCESS_KEY_ID'];
    final keySecret = Platform.environment['ALIBABA_ACCESS_KEY_SECRET'];

    if (keyId == null || keyId.isEmpty) {
      throw StateError(
        'ALIBABA_ACCESS_KEY_ID environment variable is not set or empty.',
      );
    }
    if (keySecret == null || keySecret.isEmpty) {
      throw StateError(
        'ALIBABA_ACCESS_KEY_SECRET environment variable is not set or empty.',
      );
    }

    return AlibabaCredentials(
      accessKeyId: keyId,
      accessKeySecret: keySecret,
      securityToken: Platform.environment['ALIBABA_SECURITY_TOKEN'],
    );
  }

  /// Whether these credentials include a temporary security token.
  bool get isStsCredential =>
      securityToken != null && securityToken!.isNotEmpty;
}
