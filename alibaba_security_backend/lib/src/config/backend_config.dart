import 'dart:io';

/// Configuration for the BlueTeam Autopilot backend service.
///
/// Reads all configuration from environment variables with sensible defaults
/// for local development and hackathon use.
class BackendConfig {
  /// HTTP port the Shelf server listens on.
  final int port;

  /// Alibaba Cloud region (e.g. `ap-southeast-1`).
  final String region;

  /// TableStore instance name.
  final String tablestoreInstance;

  /// TableStore endpoint host
  /// (e.g. `https://{instance}.{region}.tablestore.aliyuncs.com`).
  final String tablestoreEndpoint;

  /// TableStore table names.
  final String incidentsTable;
  final String recommendationsTable;

  /// DashScope (Qwen Cloud) API key.
  final String qwenApiKey;

  /// DashScope endpoint URL.
  final String qwenEndpoint;

  /// Qwen model identifier (e.g. `qwen-plus`, `qwen-max`).
  final String qwenModel;

  /// Whether to default to dry-run mode for response policy execution.
  final bool defaultDryRun;

  /// Default time range shortcut for incident analysis.
  final String defaultTimeRange;

  /// Maximum number of incidents to analyze per batch request.
  final int maxIncidentsPerBatch;

  /// Request timeout for Qwen API calls.
  final Duration qwenTimeout;

  const BackendConfig({
    required this.port,
    required this.region,
    required this.tablestoreInstance,
    required this.tablestoreEndpoint,
    this.incidentsTable = 'incidents',
    this.recommendationsTable = 'recommendations',
    required this.qwenApiKey,
    this.qwenEndpoint = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.qwenModel = 'qwen-plus',
    this.defaultDryRun = true,
    this.defaultTimeRange = 'lastHour',
    this.maxIncidentsPerBatch = 10,
    this.qwenTimeout = const Duration(seconds: 60),
  });

  /// Creates a [BackendConfig] from environment variables.
  ///
  /// Environment variables:
  /// - `PORT` — server port (default: 8080)
  /// - `ALIBABA_REGION` — cloud region (default: ap-southeast-1)
  /// - `TABLESTORE_INSTANCE` — TableStore instance name (required)
  /// - `TABLESTORE_ENDPOINT` — override endpoint URL (auto-generated if absent)
  /// - `INCIDENTS_TABLE` — table name (default: incidents)
  /// - `RECOMMENDATIONS_TABLE` — table name (default: recommendations)
  /// - `QWEN_API_KEY` — DashScope API key (required)
  /// - `QWEN_ENDPOINT` — DashScope URL (default: dashscope.aliyuncs.com)
  /// - `QWEN_MODEL` — model ID (default: qwen-plus)
  /// - `DEFAULT_DRY_RUN` — "true" or "false" (default: true)
  /// - `DEFAULT_TIME_RANGE` — time range shortcut (default: lastHour)
  /// - `MAX_INCIDENTS_PER_BATCH` — integer (default: 10)
  factory BackendConfig.fromEnvironment() {
    final region = Platform.environment['ALIBABA_REGION'] ?? 'ap-southeast-1';
    final instance = Platform.environment['TABLESTORE_INSTANCE'] ?? '';
    final endpoint = Platform.environment['TABLESTORE_ENDPOINT'] ??
        'https://$instance.$region.tablestore.aliyuncs.com';

    return BackendConfig(
      port: int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080,
      region: region,
      tablestoreInstance: instance,
      tablestoreEndpoint: endpoint,
      incidentsTable:
          Platform.environment['INCIDENTS_TABLE'] ?? 'incidents',
      recommendationsTable:
          Platform.environment['RECOMMENDATIONS_TABLE'] ?? 'recommendations',
      qwenApiKey: Platform.environment['QWEN_API_KEY'] ?? '',
      qwenEndpoint: Platform.environment['QWEN_ENDPOINT'] ??
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
      qwenModel: Platform.environment['QWEN_MODEL'] ?? 'qwen-plus',
      defaultDryRun:
          Platform.environment['DEFAULT_DRY_RUN']?.toLowerCase() != 'false',
      defaultTimeRange:
          Platform.environment['DEFAULT_TIME_RANGE'] ?? 'lastHour',
      maxIncidentsPerBatch:
          int.tryParse(Platform.environment['MAX_INCIDENTS_PER_BATCH'] ?? '') ??
              10,
    );
  }

  /// Whether TableStore persistence is configured.
  bool get hasTableStore =>
      tablestoreInstance.isNotEmpty && tablestoreEndpoint.isNotEmpty;

  /// Whether Qwen Cloud API is configured.
  bool get hasQwen => qwenApiKey.isNotEmpty;
}
