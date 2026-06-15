import 'dart:convert';
import 'dart:io';

import '../prompts/system_prompt.dart';

/// Configuration for the Qwen Autopilot Agent.
///
/// Holds MCP server endpoint, system prompt, and operational parameters.
/// Can generate a Qwen Cloud deployment manifest.
class AgentConfig {
  /// MCP server endpoint URL (stdio or HTTP).
  final String mcpServerEndpoint;

  /// The full system prompt for the agent.
  final String systemPrompt;

  /// Default time range shortcut for incident discovery.
  ///
  /// Must be a valid [TimeRange] name (e.g., 'lastHour', 'last4Hours',
  /// 'last24Hours', 'last7Days'). Defaults to 'lastHour'.
  final String defaultTimeRange;

  /// Whether to default to dry-run mode for response policy execution.
  final bool defaultDryRun;

  /// Maximum number of incidents to analyze per agent run.
  final int maxIncidentsPerRun;

  const AgentConfig({
    required this.mcpServerEndpoint,
    required this.systemPrompt,
    this.defaultTimeRange = 'lastHour',
    this.defaultDryRun = true,
    this.maxIncidentsPerRun = 10,
  });

  /// Creates an [AgentConfig] from environment variables.
  ///
  /// Environment variables:
  /// - `MCP_ENDPOINT` — MCP server URL (default: `stdio`)
  /// - `AGENT_TIME_RANGE` — time range shortcut (default: lastHour)
  /// - `AGENT_DRY_RUN` — "true" or "false" (default: true)
  /// - `AGENT_MAX_INCIDENTS` — max incidents per run (default: 10)
  factory AgentConfig.fromEnvironment() {
    return AgentConfig(
      mcpServerEndpoint: Platform.environment['MCP_ENDPOINT'] ?? 'stdio',
      systemPrompt: SystemPrompt.build(),
      defaultTimeRange: Platform.environment['AGENT_TIME_RANGE'] ?? 'lastHour',
      defaultDryRun:
          Platform.environment['AGENT_DRY_RUN']?.toLowerCase() != 'false',
      maxIncidentsPerRun:
          int.tryParse(Platform.environment['AGENT_MAX_INCIDENTS'] ?? '') ?? 10,
    );
  }

  /// Generates a JSON manifest suitable for Qwen Cloud agent configuration.
  Map<String, dynamic> toQwenCloudManifest() {
    return {
      'name': 'BlueTeam Autopilot',
      'version': '0.1.0',
      'description':
          'AI-powered SecOps copilot for Alibaba Cloud Security Center '
          'and Agentic SOC.',
      'systemPrompt': systemPrompt,
      'mcpServers': [
        {
          'name': 'alibaba-security-mcp',
          'endpoint': mcpServerEndpoint,
          'transport': mcpServerEndpoint == 'stdio' ? 'stdio' : 'http',
        },
      ],
      'parameters': {
        'defaultTimeRange': defaultTimeRange,
        'defaultDryRun': defaultDryRun,
        'maxIncidentsPerRun': maxIncidentsPerRun,
      },
    };
  }

  /// Serializes the Qwen Cloud manifest to a pretty-printed JSON string.
  String toManifestJson() {
    return const JsonEncoder.withIndent('  ').convert(toQwenCloudManifest());
  }
}
