import 'package:alibaba_security_api/alibaba_security_api.dart';
import 'package:easy_api_annotations/mcp_annotations.dart';

import 'knowledge/knowledge_store.dart';

/// MCP server exposing Alibaba Cloud Security Center and Agentic SOC
/// capabilities as tools for AI agents.
///
/// Provides tools for discovering and inspecting security events, alerts,
/// vulnerabilities, WAF attack logs, and response policies. Supports both
/// real and dry-run execution modes.
///
/// Configuration is read from environment variables:
/// - `ALIBABA_ACCESS_KEY_ID` / `ALIBABA_ACCESS_KEY_SECRET`
/// - `ALIBABA_REGION` (default: cn-hangzhou)
/// - `SECURITY_CENTER_MODE` ("real" or "dry-run", default: dry-run)
@Server(
  transport: McpTransport.stdio,
  generateJson: true,
  annotationsDefault: ToolAnnotations(openWorldHint: true),
)
class AlibabaSecurityServer {
  late final AlibabaApiClient _client;
  late final SecurityCenterService _securityCenter;
  late final CloudSiemService _cloudSiem;
  late final WafService _waf;
  late final KnowledgeStore _knowledgeStore;

  AlibabaSecurityServer() {
    _client = AlibabaApiClient.fromEnvironment();
    _securityCenter = SecurityCenterService(_client);
    _cloudSiem = CloudSiemService(_client);
    _waf = WafService(_client);
    _knowledgeStore = KnowledgeStore();
  }

  /// Health check returning server status, region, and execution mode.
  @Tool(
    name: 'ping',
    description:
        'Health check for the Alibaba Security MCP server. '
        'Returns server status, configured region, and execution mode.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Map<String, dynamic> ping() {
    return {'ok': true, 'region': _client.region, 'mode': _client.mode.name};
  }

  /// List security events from Agentic SOC within a time window.
  @Tool(
    name: 'list_security_events',
    description:
        'List security events from Alibaba Cloud Agentic SOC. '
        'Events are higher-level incidents that may aggregate multiple alerts '
        'from different sources (WAF, CWPP, Cloud Firewall, etc.). '
        'Returns events with IDs, severity, affected assets, and timestamps.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> listSecurityEvents({
    @Parameter(
      title: 'Time Range Shortcut',
      description:
          'Pre-baked time window shortcut. Dart computes exact boundaries. '
          'Options: last15Min, lastHour, last4Hours, last24Hours, last7Days, '
          'last30Days. Ignored if startIso and endIso are provided.',
      enumValues: [
        'last15Min',
        'lastHour',
        'last4Hours',
        'last24Hours',
        'last7Days',
        'last30Days',
        'custom',
      ],
      example: 'lastHour',
    )
    String? timeRange,
    @Parameter(
      title: 'Start Time (ISO 8601)',
      description:
          'Custom start time in ISO 8601 format (e.g., 2026-06-11T00:00:00Z). '
          'Only used when timeRange is "custom" or not provided.',
    )
    String? startIso,
    @Parameter(
      title: 'End Time (ISO 8601)',
      description:
          'Custom end time in ISO 8601 format (e.g., 2026-06-12T00:00:00Z). '
          'Only used when timeRange is "custom" or not provided.',
    )
    String? endIso,
    @Parameter(
      title: 'Minimum Severity',
      description:
          'Minimum severity filter. Only events at or above this level '
          'are returned.',
      enumValues: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'],
      example: 'HIGH',
    )
    String? minSeverity,
    @Parameter(
      title: 'Status',
      description: 'Filter events by their investigation status.',
      enumValues: ['NEW', 'IN_PROGRESS', 'RESOLVED'],
    )
    String? status,
  }) async {
    final range = TimeRange.fromString(timeRange);
    final window = TimeWindow.resolve(
      range: range,
      startIso: startIso,
      endIso: endIso,
    );

    final severity = minSeverity != null
        ? Severity.fromString(minSeverity)
        : null;
    final eventStatus = status != null ? EventStatus.fromString(status) : null;

    final events = await _securityCenter.listSecurityEvents(
      window: window,
      minSeverity: severity,
      status: eventStatus,
    );

    return {
      'timeWindow': window.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
    };
  }

  /// Get full details of a security event by ID.
  @Tool(
    name: 'get_security_event_detail',
    description:
        'Get full details of a security event including attack chain stages, '
        'source product, attacker IPs, related alerts, and associated '
        'vulnerabilities. Wraps the GetAttackEventDetail API.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> getSecurityEventDetail(
    @Parameter(
      title: 'Event ID',
      description: 'The unique identifier of the security event.',
      example: 'evt-abc123',
    )
    String eventId,
  ) async {
    final detail = await _securityCenter.getSecurityEventDetail(eventId);
    return detail.toJson();
  }

  /// List alerts grouped by source product for a given event.
  @Tool(
    name: 'list_alerts_for_event',
    description:
        'Retrieve the underlying alerts for a security event, grouped by '
        'data source (e.g., WAF, SecurityCenter, CWPP, Cloud Firewall). '
        'Each alert includes its ID, rule ID, severity, and message.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> listAlertsForEvent(
    @Parameter(
      title: 'Event ID',
      description: 'The security event ID to retrieve alerts for.',
      example: 'evt-abc123',
    )
    String eventId,
  ) async {
    final alerts = await _securityCenter.listAlertsForEvent(eventId);
    return alerts.toJson();
  }

  /// List vulnerabilities detected by Security Center.
  @Tool(
    name: 'list_vulnerabilities',
    description:
        'List vulnerabilities detected on cloud assets by Alibaba Cloud '
        'Security Center. Supports filtering by severity, asset, and '
        'vulnerability type. Wraps the DescribeVulList API.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<List<Map<String, dynamic>>> listVulnerabilities({
    @Parameter(
      title: 'Severity',
      description: 'Filter by vulnerability severity level.',
      enumValues: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'],
    )
    String? severity,
    @Parameter(
      title: 'Asset ID',
      description: 'Filter by specific asset identifier.',
    )
    String? assetId,
    @Parameter(
      title: 'Vulnerability Type',
      description: 'Filter by vulnerability type category.',
      enumValues: ['CVE', 'WEB_CMS', 'APP', 'SYSTEM'],
    )
    String? vulType,
    @Parameter(
      title: 'Page',
      description: 'Page number for paginated results.',
      minimum: 1,
      example: 1,
    )
    int page = 1,
    @Parameter(
      title: 'Page Size',
      description: 'Number of results per page.',
      minimum: 1,
      maximum: 100,
      example: 20,
    )
    int pageSize = 20,
  }) async {
    final sev = severity != null ? Severity.fromString(severity) : null;
    final vType = vulType != null ? VulType.fromString(vulType) : null;

    final vulns = await _securityCenter.listVulnerabilities(
      severity: sev,
      assetId: assetId,
      vulType: vType,
      page: page,
      pageSize: pageSize,
    );

    return vulns.map((v) => v.toJson()).toList();
  }

  /// Get detailed information about a specific vulnerability.
  @Tool(
    name: 'get_vulnerability_detail',
    description:
        'Get detailed information about a specific vulnerability including '
        'CVE identifier, description, affected versions, and remediation '
        'advice. Wraps the DescribeVulDetails API.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> getVulnerabilityDetail(
    @Parameter(
      title: 'Vulnerability ID',
      description: 'The unique identifier of the vulnerability.',
      example: 'vul-abc123',
    )
    String vulId,
  ) async {
    final detail = await _securityCenter.getVulnerabilityDetail(vulId);
    return detail.toJson();
  }

  /// List response policies configured in Agentic SOC.
  @Tool(
    name: 'list_response_policies',
    description:
        'List automated response policies configured in Agentic SOC. '
        'These policies define actions taken in response to security events, '
        'such as blocking attacker IPs via WAF or quarantining hosts.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<List<Map<String, dynamic>>> listResponsePolicies({
    @Parameter(
      title: 'Scope',
      description:
          'Filter policies by scope. WAF returns only WAF-related policies.',
      enumValues: ['WAF', 'ALL'],
      example: 'ALL',
    )
    String scope = 'ALL',
  }) async {
    final policyScope = PolicyScope.fromString(scope);
    final policies = await _cloudSiem.listResponsePolicies(scope: policyScope);
    return policies.map((p) => p.toJson()).toList();
  }

  /// Execute a response policy against an event or IP list.
  @Tool(
    name: 'execute_response_policy',
    description:
        'Execute an Agentic SOC response policy. In dry-run mode, returns '
        'what would happen without making any changes. In real mode, '
        'actually triggers the policy action (e.g., blocking an IP via WAF). '
        'Use with caution in production environments.',
    annotations: ToolAnnotations(destructiveHint: true),
  )
  Future<Map<String, dynamic>> executeResponsePolicy(
    @Parameter(
      title: 'Policy ID',
      description: 'The response policy to execute.',
      example: 'pol-abc123',
    )
    String policyId, {
    @Parameter(
      title: 'Event ID',
      description: 'Optional event ID to associate with the policy execution.',
    )
    String? eventId,
    @Parameter(
      title: 'Dry Run',
      description:
          'If true, simulate execution without making changes. '
          'Defaults to the server SECURITY_CENTER_MODE setting.',
    )
    bool? dryRun,
  }) async {
    final result = await _cloudSiem.executeResponsePolicy(
      policyId: policyId,
      eventId: eventId,
      dryRun: dryRun,
    );
    return result.toJson();
  }

  /// Get account and region context.
  @Tool(
    name: 'get_account_context',
    description:
        'Get account context metadata including the configured region, '
        'Security Center edition, whether Agentic SOC is enabled, '
        'and the current execution mode. Call this first to establish '
        'environmental awareness before querying security data.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> getAccountContext() async {
    return _securityCenter.getAccountContext();
  }

  // ---------------------------------------------------------------------------
  // WAF (Web Application Firewall) tools
  // ---------------------------------------------------------------------------

  /// Discover the WAF instance in the configured region.
  @Tool(
    name: 'get_waf_instance_info',
    description:
        'Discover the WAF (Web Application Firewall) instance in the '
        'configured region and return its details including status, edition, '
        'features, and limits. This tool auto-discovers the instance ID — '
        'no manual configuration needed. Call this first to confirm WAF '
        'is provisioned before querying WAF security events.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> getWafInstanceInfo() async {
    final info = await _waf.discoverInstance();
    return info.toJson();
  }

  /// List WAF security event logs (attack traffic).
  @Tool(
    name: 'list_waf_security_events',
    description:
        'List WAF security event logs — individual attack requests that '
        'matched WAF protection rules. Returns detailed attack entries '
        'including attack type, source IP, target host, request path, '
        'and action taken (block/monitor). '
        '\n\nUse the timeRange shortcut for common windows (e.g., "last24Hours") '
        'or pass custom startIso/endIso for specific periods. '
        '\n\nThis is the primary tool for investigating web application attacks '
        'such as SQL injection, XSS, path traversal, and scanner activity.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> listWafSecurityEvents({
    @Parameter(
      title: 'Time Range Shortcut',
      description:
          'Pre-baked time window shortcut. Dart computes exact boundaries. '
          'Options: last15Min, lastHour, last4Hours, last24Hours, last7Days, '
          'last30Days. Ignored if startIso and endIso are provided.',
      enumValues: [
        'last15Min',
        'lastHour',
        'last4Hours',
        'last24Hours',
        'last7Days',
        'last30Days',
        'custom',
      ],
      example: 'last24Hours',
    )
    String? timeRange,
    @Parameter(
      title: 'Start Time (ISO 8601)',
      description:
          'Custom start time in ISO 8601 format (e.g., 2026-06-11T00:00:00Z). '
          'Only used when timeRange is "custom" or not provided.',
    )
    String? startIso,
    @Parameter(
      title: 'End Time (ISO 8601)',
      description:
          'Custom end time in ISO 8601 format (e.g., 2026-06-12T00:00:00Z). '
          'Only used when timeRange is "custom" or not provided.',
    )
    String? endIso,
    @Parameter(
      title: 'Page Size',
      description: 'Number of events per page (max 100).',
      minimum: 1,
      maximum: 100,
      example: 20,
    )
    int pageSize = 20,
    @Parameter(
      title: 'Page Number',
      description: 'Page number for paginated results.',
      minimum: 1,
      example: 1,
    )
    int page = 1,
  }) async {
    final range = TimeRange.fromString(timeRange);
    final window = TimeWindow.resolve(
      range: range,
      startIso: startIso,
      endIso: endIso,
    );

    final result = await _waf.listSecurityEventLogs(
      startDate: window.startEpochSeconds,
      endDate: window.endEpochSeconds,
      page: page,
      pageSize: pageSize,
    );

    return {
      'timeWindow': window.toJson(),
      'totalCount': result.totalCount,
      'page': page,
      'pageSize': pageSize,
      'events': result.events.map((e) => e.toJson()).toList(),
    };
  }

  /// List top triggered WAF rules.
  @Tool(
    name: 'list_waf_top_rules',
    description:
        'List the top 10 most frequently triggered WAF protection rules '
        'within a time window. Returns rule IDs and hit counts. '
        'Useful for identifying which attack patterns are most prevalent.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> listWafTopRules({
    @Parameter(
      title: 'Time Range Shortcut',
      description:
          'Pre-baked time window shortcut. Options: last15Min, lastHour, '
          'last4Hours, last24Hours, last7Days, last30Days.',
      enumValues: [
        'last15Min',
        'lastHour',
        'last4Hours',
        'last24Hours',
        'last7Days',
        'last30Days',
      ],
      example: 'last7Days',
    )
    String? timeRange,
  }) async {
    final range = TimeRange.fromString(timeRange);
    final window = TimeWindow.fromRange(
      range == TimeRange.custom ? TimeRange.last7Days : range,
    );

    final ruleHits = await _waf.getTopRuleHits(
      startTimestamp: window.startEpochSeconds,
      endTimestamp: window.endEpochSeconds,
    );

    return {
      'timeWindow': window.toJson(),
      'rules': ruleHits.map((r) => r.toJson()).toList(),
    };
  }

  /// List top attacker IPs by WAF hit count.
  @Tool(
    name: 'list_waf_top_ips',
    description:
        'List the top 10 source IPs by attack count from WAF logs. '
        'Returns IP addresses and their hit counts. Useful for identifying '
        'persistent attackers and informing IP blocking decisions.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> listWafTopIps({
    @Parameter(
      title: 'Time Range Shortcut',
      description:
          'Pre-baked time window shortcut. Options: last15Min, lastHour, '
          'last4Hours, last24Hours, last7Days, last30Days.',
      enumValues: [
        'last15Min',
        'lastHour',
        'last4Hours',
        'last24Hours',
        'last7Days',
        'last30Days',
      ],
      example: 'last7Days',
    )
    String? timeRange,
  }) async {
    final range = TimeRange.fromString(timeRange);
    final window = TimeWindow.fromRange(
      range == TimeRange.custom ? TimeRange.last7Days : range,
    );

    final topIps = await _waf.getTopAttackerIps(
      startTimestamp: window.startEpochSeconds,
      endTimestamp: window.endEpochSeconds,
    );

    return {'timeWindow': window.toJson(), 'topIps': topIps};
  }

  /// List cloud assets registered in Security Center.
  @Tool(
    name: 'list_assets',
    description:
        'List cloud assets (ECS instances, etc.) registered in Security '
        'Center. Returns each asset\'s UUID, instance name, public/private '
        'IPs, region, asset type, and OS. Use this to dynamically discover '
        'the environment\'s asset inventory instead of relying on hardcoded '
        'hostnames. Supports an optional search criteria to filter results.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<List<Map<String, dynamic>>> listAssets({
    @Parameter(
      title: 'Search Criteria',
      description:
          'Optional search string to filter assets by instance name, IP, '
          'or other attributes.',
    )
    String? criteria,
    @Parameter(
      title: 'Page',
      description: 'Page number for paginated results.',
      minimum: 1,
      example: 1,
    )
    int page = 1,
    @Parameter(
      title: 'Page Size',
      description: 'Number of results per page.',
      minimum: 1,
      maximum: 100,
      example: 20,
    )
    int pageSize = 20,
  }) async {
    return _securityCenter.listAssets(
      criteria: criteria,
      page: page,
      pageSize: pageSize,
    );
  }

  /// List all available knowledge documents.
  @Tool(
    name: 'list_knowledge_documents',
    description:
        'List all available operational knowledge documents. '
        'Returns each document type, title, and source (file or embedded) '
        'so the caller can discover what is available before requesting '
        'a specific document with get_knowledge_document.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<List<Map<String, dynamic>>> listKnowledgeDocuments() async {
    return _knowledgeStore.list();
  }

  /// Retrieve a SecOps knowledge document by type.
  @Tool(
    name: 'get_knowledge_document',
    description:
        'Retrieve an operational knowledge document such as compliance '
        'controls (NIST CSF, SOC 2), mitigation runbooks, change management '
        'policies, asset inventory, or trusted network definitions. '
        'Call this tool when you need compliance context for decision-making '
        'or runbook steps for mitigation execution.',
    annotations: ToolAnnotations(readOnlyHint: true),
  )
  Future<Map<String, dynamic>> getKnowledgeDocument({
    @Parameter(
      title: 'Document Type',
      description:
          'The knowledge document to retrieve. Options: '
          'asset_inventory (network topology), '
          'trusted_networks (IP whitelist & escalation rules), '
          'compliance_nist (NIST CSF Detect & Respond controls), '
          'compliance_soc2 (SOC 2 CC6 Logical Access Controls), '
          'runbook_waf_triage (WAF threat triage RUN-SEC-042), '
          'policy_change_mgmt (firewall/ACL change approval gates).',
      enumValues: [
        'asset_inventory',
        'trusted_networks',
        'compliance_nist',
        'compliance_soc2',
        'runbook_waf_triage',
        'policy_change_mgmt',
      ],
      example: 'compliance_nist',
    )
    required String documentType,
  }) async {
    return _knowledgeStore.load(documentType);
  }
}
