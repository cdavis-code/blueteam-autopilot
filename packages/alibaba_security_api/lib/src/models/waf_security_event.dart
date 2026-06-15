import 'dart:convert';

/// A WAF security event log entry from DescribeSecurityEventLogs.
///
/// Each entry represents a single request that matched a WAF protection rule
/// and was identified as a threat (blocked or monitored).
class WafSecurityEvent {
  /// Unique request trace ID assigned by WAF.
  final String requestTraceId;

  /// ISO-8601 timestamp of when the request was processed.
  final String timestamp;

  /// Source IP address of the attacker.
  final String sourceIp;

  /// Country code of the source IP (e.g., "CA", "US", "CN").
  final String? countryCode;

  /// HTTP method used (GET, POST, etc.).
  final String requestMethod;

  /// Request path (URL without query string).
  final String requestPath;

  /// Query string of the request, if any.
  final String? queryString;

  /// Target host header value.
  final String? host;

  /// WAF protected object that matched (e.g., domain-443-ecs).
  final String? matchedHost;

  /// Destination port.
  final String? dstPort;

  /// User-Agent string from the request.
  final String? userAgent;

  /// Protection action taken: "block", "monitor", etc.
  final String action;

  /// Defense scene that triggered (e.g., "waf_base").
  final String? defenseScene;

  /// Rule type that matched (e.g., "sqli", "lfi", "scanner").
  final String? ruleType;

  /// Rule ID that triggered the block/monitor action.
  final String? ruleId;

  /// Human-readable attack description derived from rule details.
  final String attackType;

  /// Bot behavior classification (e.g., "suspicious").
  final String? botBehavior;

  /// Raw JSON from the API for advanced consumers.
  final Map<String, dynamic> raw;

  const WafSecurityEvent({
    required this.requestTraceId,
    required this.timestamp,
    required this.sourceIp,
    this.countryCode,
    required this.requestMethod,
    required this.requestPath,
    this.queryString,
    this.host,
    this.matchedHost,
    this.dstPort,
    this.userAgent,
    required this.action,
    this.defenseScene,
    this.ruleType,
    this.ruleId,
    required this.attackType,
    this.botBehavior,
    required this.raw,
  });

  /// Parse from the raw API response log entry.
  factory WafSecurityEvent.fromApiLog(Map<String, dynamic> log) {
    String? ruleId;
    String? defenseScene;
    String? ruleType;
    String action = 'block';

    // Parse block rule detail to extract rule info
    final blockDetailStr = log['plugin_matched_block_rule_detail']?.toString();
    if (blockDetailStr != null && blockDetailStr != '[]') {
      try {
        final blockDetails = jsonDecode(blockDetailStr) as List<dynamic>;
        if (blockDetails.isNotEmpty) {
          final first = blockDetails.first as Map<String, dynamic>;
          ruleId = first['RuleId']?.toString();
          defenseScene = first['DefenseScene']?.toString();
          ruleType = first['RuleType']?.toString();
          action = first['Action']?.toString() ?? 'block';
        }
      } catch (_) {}
    }

    // If no block rule detail, check test (monitor) rules
    if (ruleId == null) {
      final testDetailStr = log['plugin_matched_test_rule_detail']?.toString();
      if (testDetailStr != null && testDetailStr != '[]') {
        try {
          final testDetails = jsonDecode(testDetailStr) as List<dynamic>;
          if (testDetails.isNotEmpty) {
            final first = testDetails.first as Map<String, dynamic>;
            ruleId = first['RuleId']?.toString();
            defenseScene = first['DefenseScene']?.toString();
            ruleType = first['RuleType']?.toString();
            action = first['Action']?.toString() ?? 'monitor';
          }
        } catch (_) {}
      }
    }

    final attackType = _deriveAttackType(ruleType, defenseScene, log);

    // Parse Unix timestamp (seconds) to ISO-8601
    final tsStr = log['timestamp']?.toString();
    final timestamp = tsStr != null
        ? DateTime.fromMillisecondsSinceEpoch(
            int.parse(tsStr) * 1000,
            isUtc: true,
          ).toIso8601String()
        : DateTime.now().toUtc().toIso8601String();

    return WafSecurityEvent(
      requestTraceId: log['request_traceid']?.toString() ?? '',
      timestamp: timestamp,
      sourceIp: log['real_client_ip']?.toString() ?? 'unknown',
      countryCode: log['remote_country_id']?.toString(),
      requestMethod: log['request_method']?.toString() ?? 'GET',
      requestPath: log['request_path']?.toString() ?? '/',
      queryString: _dashToNull(log['querystring']?.toString()),
      host: _dashToNull(log['host']?.toString()),
      matchedHost: log['matched_host']?.toString(),
      dstPort: log['dst_port']?.toString(),
      userAgent: _dashToNull(log['http_user_agent']?.toString()),
      action: action,
      defenseScene: defenseScene,
      ruleType: ruleType,
      ruleId: ruleId,
      attackType: attackType,
      botBehavior: _dashToNull(log['bot_behavior']?.toString()),
      raw: log,
    );
  }

  Map<String, dynamic> toJson() => {
    'requestTraceId': requestTraceId,
    'timestamp': timestamp,
    'sourceIp': sourceIp,
    'countryCode': countryCode,
    'requestMethod': requestMethod,
    'requestPath': requestPath,
    'queryString': queryString,
    'host': host,
    'matchedHost': matchedHost,
    'action': action,
    'defenseScene': defenseScene,
    'ruleType': ruleType,
    'ruleId': ruleId,
    'attackType': attackType,
    'botBehavior': botBehavior,
  };

  static String? _dashToNull(String? value) {
    if (value == null || value == '-' || value.isEmpty) return null;
    return value;
  }

  static String _deriveAttackType(
    String? ruleType,
    String? defenseScene,
    Map<String, dynamic> log,
  ) {
    return switch (ruleType) {
      'sqli' => 'SQL Injection',
      'xss' => 'Cross-Site Scripting (XSS)',
      'lfi' => 'Local File Inclusion',
      'rfi' => 'Remote File Inclusion',
      'rce' => 'Remote Code Execution',
      'scanner' => 'Malicious Scanner',
      'other' => _inferFromWafGroup(log),
      _ => defenseScene ?? 'WAF Rule Hit',
    };
  }

  static String _inferFromWafGroup(Map<String, dynamic> log) {
    final groupDetail = log['plugin_matched_detail_waf_group']?.toString();
    if (groupDetail == null) return 'WAF Rule Hit';
    if (groupDetail.contains('..') || groupDetail.contains('/etc/')) {
      return 'Path Traversal';
    }
    if (groupDetail.contains('<script') ||
        groupDetail.contains('javascript:')) {
      return 'Cross-Site Scripting (XSS)';
    }
    if (groupDetail.contains('.git') || groupDetail.contains('.env')) {
      return 'Sensitive File Access';
    }
    return 'WAF Rule Hit';
  }
}

/// Minimal WAF instance information from DescribeInstance.
class WafInstanceInfo {
  /// The WAF instance ID.
  final String instanceId;

  /// Instance status (1 = active).
  final int status;

  /// Whether log service (SLS) is enabled.
  final bool logServiceEnabled;

  /// Whether bot management is enabled.
  final bool botEnabled;

  /// Whether anti-scan protection is enabled.
  final bool antiScanEnabled;

  const WafInstanceInfo({
    required this.instanceId,
    required this.status,
    this.logServiceEnabled = false,
    this.botEnabled = false,
    this.antiScanEnabled = false,
  });

  factory WafInstanceInfo.fromApi(
    String instanceId,
    Map<String, dynamic> response,
  ) {
    final details = response['Details'] as Map<String, dynamic>? ?? {};
    return WafInstanceInfo(
      instanceId: instanceId,
      status: response['Status'] as int? ?? 0,
      logServiceEnabled: details['LogService'] == true,
      botEnabled: details['Bot'] == true,
      antiScanEnabled: details['AntiScan'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'instanceId': instanceId,
    'status': status,
    'logServiceEnabled': logServiceEnabled,
    'botEnabled': botEnabled,
    'antiScanEnabled': antiScanEnabled,
  };
}

/// Aggregated WAF rule hit statistics.
class WafRuleHit {
  /// Rule ID that was triggered.
  final String ruleId;

  /// Number of times this rule was triggered.
  final int count;

  /// The protected resource, if available.
  final String? resource;

  const WafRuleHit({required this.ruleId, required this.count, this.resource});

  Map<String, dynamic> toJson() => {
    'ruleId': ruleId,
    'count': count,
    'resource': resource,
  };
}
