import 'dart:io';

import 'package:yaml/yaml.dart';

import 'package:alibaba_security_api/alibaba_security_api.dart';

/// Configuration for the CLI application.
///
/// Loads credentials and settings from environment variables or an optional
/// YAML configuration file (~/.alibaba_security.yaml).
class CliConfig {
  /// The resolved Alibaba Cloud credentials.
  final AlibabaCredentials credentials;

  /// The target region (e.g., "cn-hangzhou").
  final String region;

  /// Execution mode: real or dry-run.
  final SecurityCenterMode mode;

  /// Whether to output JSON instead of table format.
  final bool jsonOutput;

  /// Optional WAF instance ID override. If null, WafService will
  /// auto-discover the instance via DescribeInstance.
  final String? wafInstanceId;

  const CliConfig({
    required this.credentials,
    required this.region,
    this.mode = SecurityCenterMode.dryRun,
    this.jsonOutput = false,
    this.wafInstanceId,
  });

  /// Load configuration from environment variables and optional config file.
  ///
  /// Priority (highest to lowest):
  /// 1. Environment variables
  /// 2. Config file (~/.alibaba_security.yaml)
  /// 3. Defaults
  factory CliConfig.load({bool jsonOutput = false}) {
    // Try environment variables first
    final envKeyId = Platform.environment['ALIBABA_ACCESS_KEY_ID'];
    final envKeySecret = Platform.environment['ALIBABA_ACCESS_KEY_SECRET'];
    final envToken = Platform.environment['ALIBABA_SECURITY_TOKEN'];
    final envRegion = Platform.environment['ALIBABA_REGION'];
    final envMode = Platform.environment['SECURITY_CENTER_MODE'];

    if (envKeyId != null &&
        envKeyId.isNotEmpty &&
        envKeySecret != null &&
        envKeySecret.isNotEmpty) {
      return CliConfig(
        credentials: AlibabaCredentials(
          accessKeyId: envKeyId,
          accessKeySecret: envKeySecret,
          securityToken: envToken,
        ),
        region: envRegion ?? 'cn-hangzhou',
        mode: SecurityCenterMode.fromString(envMode ?? 'dry-run'),
        jsonOutput: jsonOutput,
      );
    }

    // Try config file
    final configFile = File(_configFilePath);
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final yaml = loadYaml(content) as Map<dynamic, dynamic>?;

        if (yaml != null) {
          final keyId = yaml['access_key_id']?.toString();
          final keySecret = yaml['access_key_secret']?.toString();
          final token = yaml['security_token']?.toString();
          final region = yaml['region']?.toString() ?? 'cn-hangzhou';
          final mode = yaml['mode']?.toString() ?? 'dry-run';
          final wafInstanceId = yaml['waf_instance_id']?.toString();
          if (keyId != null &&
              keyId.isNotEmpty &&
              keySecret != null &&
              keySecret.isNotEmpty) {
            return CliConfig(
              credentials: AlibabaCredentials(
                accessKeyId: keyId,
                accessKeySecret: keySecret,
                securityToken: token,
              ),
              region: region,
              mode: SecurityCenterMode.fromString(mode),
              jsonOutput: jsonOutput,
              wafInstanceId: wafInstanceId,
            );
          }
        }
      } catch (_) {
        // Fall through to error
      }
    }

    throw StateError(
      'No credentials found. Set ALIBABA_ACCESS_KEY_ID and '
      'ALIBABA_ACCESS_KEY_SECRET environment variables, or create a config '
      'file at $_configFilePath with access_key_id and access_key_secret.',
    );
  }

  /// Path to the optional YAML config file.
  static String get _configFilePath {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/.alibaba_security.yaml';
  }

  /// Create an [AlibabaApiClient] from this configuration.
  AlibabaApiClient createClient() {
    return AlibabaApiClient(
      credentials: credentials,
      region: region,
      mode: mode,
    );
  }
}
