import 'dart:convert';

import 'package:alibaba_security_agent/alibaba_security_agent.dart';
import 'package:alibaba_security_api/alibaba_security_api.dart';
import 'package:dio/dio.dart';

import '../config/backend_config.dart';

/// Client for Qwen Cloud (DashScope) chat completions API.
///
/// Uses the OpenAI-compatible endpoint at DashScope to send security context
/// to the Qwen Autopilot agent and parse structured responses into
/// [IncidentReport], [ActionProposal], and [VulnerabilityPrioritization]
/// models.
class QwenClient {
  final String apiKey;
  final String endpoint;
  final String model;
  final Duration timeout;
  final Dio _dio;

  QwenClient({
    required this.apiKey,
    this.endpoint = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.model = 'qwen-plus',
    this.timeout = const Duration(seconds: 60),
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Create a [QwenClient] from backend configuration.
  factory QwenClient.fromConfig(BackendConfig config, {Dio? dio}) {
    return QwenClient(
      apiKey: config.qwenApiKey,
      endpoint: config.qwenEndpoint,
      model: config.qwenModel,
      timeout: config.qwenTimeout,
      dio: dio,
    );
  }

  /// Send security event data to Qwen and get an [IncidentReport] back.
  ///
  /// The system prompt from [SystemPrompt] defines the BlueTeam Autopilot
  /// persona and 5 core behaviors. The user message includes the serialized
  /// security event, alerts, available policies, and account context.
  Future<({IncidentReport report, List<ActionProposal> proposals})>
      analyzeIncident({
    required SecurityEvent event,
    required List<Alert> alerts,
    List<ResponsePolicy>? availablePolicies,
    Map<String, dynamic>? accountContext,
  }) async {
    final userMessage = _buildIncidentAnalysisPrompt(
      event: event,
      alerts: alerts,
      policies: availablePolicies,
      accountContext: accountContext,
    );

    final responseJson = await _chatCompletion(
      systemPrompt: SystemPrompt.build(),
      userMessage: userMessage,
      responseFormat: 'json_object',
    );

    // Parse the structured JSON response
    final report = _parseIncidentReport(responseJson, event.eventId);
    final proposals = _parseActionProposals(responseJson, event.eventId);

    return (report: report, proposals: proposals);
  }

  /// Send vulnerability data to Qwen and get a prioritization back.
  Future<VulnerabilityPrioritization> prioritizeVulnerabilities({
    required List<Vulnerability> vulnerabilities,
    Map<String, dynamic>? accountContext,
  }) async {
    final userMessage = _buildVulnTriagePrompt(
      vulnerabilities: vulnerabilities,
      accountContext: accountContext,
    );

    final responseJson = await _chatCompletion(
      systemPrompt: SystemPrompt.build(),
      userMessage: userMessage,
      responseFormat: 'json_object',
    );

    return _parseVulnPrioritization(responseJson, vulnerabilities.length);
  }

  // ---------------------------------------------------------------------------
  // Internal: DashScope API call
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _chatCompletion({
    required String systemPrompt,
    required String userMessage,
    String? responseFormat,
  }) async {
    if (apiKey.isEmpty) {
      throw QwenClientException('Qwen API key is not configured.');
    }

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ];

    final requestBody = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 4096,
    };

    if (responseFormat != null) {
      requestBody['response_format'] = {'type': responseFormat};
    }

    try {
      final response = await _dio.post(
        '$endpoint/chat/completions',
        data: json.encode(requestBody),
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );

      final body = response.data;
      if (body is String) {
        final parsed = json.decode(body) as Map<String, dynamic>;
        return _extractContent(parsed);
      }
      return _extractContent(body as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw QwenClientException(
          'Qwen API authentication failed. Check QWEN_API_KEY.',
          statusCode: e.response?.statusCode,
        );
      }
      throw QwenClientException(
        'Qwen API request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Map<String, dynamic> _extractContent(Map<String, dynamic> response) {
    final choices = response['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw QwenClientException('Qwen API returned no choices.');
    }

    final message = choices.first as Map<String, dynamic>;
    final content = (message['message'] as Map<String, dynamic>?)?['content'];
    if (content == null) {
      throw QwenClientException('Qwen API returned empty content.');
    }

    // Try to parse as JSON
    try {
      return json.decode(content.toString()) as Map<String, dynamic>;
    } catch (_) {
      // If not JSON, wrap the raw text
      return {'raw_response': content.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // Prompt builders
  // ---------------------------------------------------------------------------

  String _buildIncidentAnalysisPrompt({
    required SecurityEvent event,
    required List<Alert> alerts,
    List<ResponsePolicy>? policies,
    Map<String, dynamic>? accountContext,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Analyze the following security incident and provide:');
    buffer.writeln('1. An incident report (matching IncidentReport schema)');
    buffer.writeln(
        '2. Action proposals (matching ActionProposal schema) if applicable');
    buffer.writeln();
    buffer.writeln('## Security Event');
    buffer.writeln(json.encode(event.toJson()));
    buffer.writeln();
    buffer.writeln('## Alerts');
    buffer.writeln(
      json.encode(alerts.map((a) => a.toJson()).toList()),
    );

    if (policies != null && policies.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Available Response Policies');
      buffer.writeln(
        json.encode(policies.map((p) => p.toJson()).toList()),
      );
    }

    if (accountContext != null) {
      buffer.writeln();
      buffer.writeln('## Account Context');
      buffer.writeln(json.encode(accountContext));
    }

    buffer.writeln();
    buffer.writeln('Respond with a JSON object containing:');
    buffer.writeln(
      '- "report": an IncidentReport object',
    );
    buffer.writeln(
      '- "proposals": an array of ActionProposal objects (empty if none)',
    );

    return buffer.toString();
  }

  String _buildVulnTriagePrompt({
    required List<Vulnerability> vulnerabilities,
    Map<String, dynamic>? accountContext,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Prioritize the following vulnerabilities and provide a '
      'VulnerabilityPrioritization object as JSON.',
    );
    buffer.writeln();
    buffer.writeln('## Vulnerabilities');
    buffer.writeln(
      json.encode(vulnerabilities.map((v) => v.toJson()).toList()),
    );

    if (accountContext != null) {
      buffer.writeln();
      buffer.writeln('## Account Context');
      buffer.writeln(json.encode(accountContext));
    }

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Response parsers
  // ---------------------------------------------------------------------------

  IncidentReport _parseIncidentReport(
    Map<String, dynamic> json,
    String eventId,
  ) {
    // Try nested "report" key first, then top-level
    final reportJson = json['report'] as Map<String, dynamic>? ?? json;

    try {
      // Ensure eventId is set
      final merged = Map<String, dynamic>.from(reportJson);
      merged.putIfAbsent('eventId', () => eventId);
      merged.putIfAbsent('generatedAt', () => DateTime.now().toIso8601String());
      return IncidentReport.fromJson(merged);
    } catch (_) {
      // Fallback: create a minimal report from raw response
      return IncidentReport(
        eventId: eventId,
        title: reportJson['title']?.toString() ?? 'AI Analysis',
        severity: reportJson['severity']?.toString() ?? 'MEDIUM',
        aiSummary:
            reportJson['aiSummary']?.toString() ??
            reportJson['raw_response']?.toString() ??
            'Analysis completed but could not be parsed into structured format.',
        rootCause: reportJson['rootCause']?.toString() ?? '',
        businessImpact: reportJson['businessImpact']?.toString() ?? '',
        generatedAt: DateTime.now().toIso8601String(),
      );
    }
  }

  List<ActionProposal> _parseActionProposals(
    Map<String, dynamic> json,
    String eventId,
  ) {
    final proposalsJson = json['proposals'] as List<dynamic>?;
    if (proposalsJson == null) return [];

    return proposalsJson.map((item) {
      try {
        final map = item as Map<String, dynamic>;
        map.putIfAbsent('eventId', () => eventId);
        return ActionProposal.fromJson(map);
      } catch (_) {
        return ActionProposal(
          reasoning: item.toString(),
          recommendedPolicyId: '',
          expectedEffects: '',
          rollbackPlan: '',
          riskLevel: 'MEDIUM',
          eventId: eventId,
        );
      }
    }).toList();
  }

  VulnerabilityPrioritization _parseVulnPrioritization(
    Map<String, dynamic> json,
    int totalAnalyzed,
  ) {
    try {
      final merged = Map<String, dynamic>.from(json);
      merged.putIfAbsent('totalAnalyzed', () => totalAnalyzed);
      merged.putIfAbsent('generatedAt', () => DateTime.now().toIso8601String());
      return VulnerabilityPrioritization.fromJson(merged);
    } catch (_) {
      return VulnerabilityPrioritization(
        rankedVulns: [],
        remediationSteps:
            json['raw_response']?.toString() ??
            'Vulnerability analysis could not be parsed.',
        totalAnalyzed: totalAnalyzed,
        generatedAt: DateTime.now().toIso8601String(),
      );
    }
  }
}

/// Exception thrown when a Qwen Cloud API operation fails.
class QwenClientException implements Exception {
  final String message;
  final int? statusCode;

  const QwenClientException(this.message, {this.statusCode});

  @override
  String toString() => 'QwenClientException($message, status: $statusCode)';
}
