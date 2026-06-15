import 'dart:convert';

import '../client/alibaba_api_client.dart';
import '../models/waf_security_event.dart';

/// Wraps Alibaba Cloud WAF 3.0 (waf-openapi 2021-10-01) APIs.
///
/// Provides methods for discovering WAF instances, querying security event
/// logs (attack traffic), and retrieving rule hit statistics.
class WafService {
  final AlibabaApiClient _client;

  /// The WAF instance ID. Discovered automatically if not provided.
  String? _instanceId;

  WafService(this._client, {String? instanceId}) : _instanceId = instanceId;

  /// The currently known WAF instance ID (null until discovered).
  String? get instanceId => _instanceId;

  // ---------------------------------------------------------------------------
  // Instance discovery
  // ---------------------------------------------------------------------------

  /// Discover the WAF instance for the configured region.
  ///
  /// Calls `DescribeInstance` **without** an InstanceId — the API returns
  /// the instance belonging to the authenticated account automatically.
  /// The discovered InstanceId is cached for subsequent calls.
  ///
  /// Returns instance info including status, features, and limits.
  Future<WafInstanceInfo> discoverInstance() async {
    final response = await _client.callWafApi('DescribeInstance');

    final id = response['InstanceId']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError(
        'WAF DescribeInstance returned no InstanceId. '
        'Ensure a WAF instance exists in the configured region.',
      );
    }

    _instanceId = id;
    return WafInstanceInfo.fromApi(id, response);
  }

  /// Get instance info for a known or previously discovered instance.
  ///
  /// If no [instanceId] is provided and none was previously discovered,
  /// falls back to [discoverInstance] for automatic discovery.
  Future<WafInstanceInfo> getInstanceInfo({String? instanceId}) async {
    final id = instanceId ?? _instanceId;
    if (id == null) {
      // Auto-discover
      return discoverInstance();
    }

    final response = await _client.callWafApi(
      'DescribeInstance',
      params: {'InstanceId': id},
    );

    _instanceId = id;
    return WafInstanceInfo.fromApi(id, response);
  }

  // ---------------------------------------------------------------------------
  // Security event logs (attack traffic)
  // ---------------------------------------------------------------------------

  /// Query detailed WAF security event logs within a time window.
  ///
  /// Calls `DescribeSecurityEventLogs` which returns each request that
  /// matched a protection rule and was identified as a threat.
  ///
  /// [startDate] and [endDate] are Unix timestamps in seconds.
  /// [pageSize] max is 100 per the API.
  /// [conditions] are optional filter conditions (e.g., filter by IP, host).
  Future<({List<WafSecurityEvent> events, int totalCount})>
  listSecurityEventLogs({
    required int startDate,
    required int endDate,
    int page = 1,
    int pageSize = 20,
    List<WafFilterCondition>? conditions,
  }) async {
    final id = await _ensureInstanceId();

    final filter = <String, dynamic>{
      'DateRange': {'StartDate': startDate, 'EndDate': endDate},
    };

    if (conditions != null && conditions.isNotEmpty) {
      filter['Conditions'] = conditions
          .map((c) => {'Key': c.key, 'OpValue': c.opValue, 'Values': c.values})
          .toList();
    }

    final response = await _client.callWafApi(
      'DescribeSecurityEventLogs',
      params: {
        'InstanceId': id,
        'Filter': json.encode(filter),
        'PageSize': '$pageSize',
        'PageNumber': '$page',
      },
    );

    final totalCount = response['SecurityEventLogsTotalCount'] as int? ?? 0;
    final logs = response['SecurityEventLogs'] as List<dynamic>? ?? [];

    final events = logs.map((item) {
      if (item is Map<String, dynamic>) {
        return WafSecurityEvent.fromApiLog(item);
      }
      // Sometimes logs come as JSON strings
      if (item is String) {
        return WafSecurityEvent.fromApiLog(
          jsonDecode(item) as Map<String, dynamic>,
        );
      }
      return WafSecurityEvent.fromApiLog(item as Map<String, dynamic>);
    }).toList();

    return (events: events, totalCount: totalCount);
  }

  /// Convenience method: list security event logs for the last N minutes.
  Future<({List<WafSecurityEvent> events, int totalCount})>
  listRecentSecurityEvents({
    int minutes = 60,
    int page = 1,
    int pageSize = 20,
  }) {
    final now = DateTime.now().toUtc();
    final endDate = now.millisecondsSinceEpoch ~/ 1000;
    final startDate =
        now.subtract(Duration(minutes: minutes)).millisecondsSinceEpoch ~/ 1000;

    return listSecurityEventLogs(
      startDate: startDate,
      endDate: endDate,
      page: page,
      pageSize: pageSize,
    );
  }

  /// Fetch all security event logs across pages.
  Future<List<WafSecurityEvent>> listAllSecurityEventLogs({
    required int startDate,
    required int endDate,
    int maxPages = 50,
  }) async {
    final allEvents = <WafSecurityEvent>[];
    var page = 1;

    while (page <= maxPages) {
      final result = await listSecurityEventLogs(
        startDate: startDate,
        endDate: endDate,
        page: page,
        pageSize: 100, // Max page size
      );
      allEvents.addAll(result.events);

      if (allEvents.length >= result.totalCount || result.events.isEmpty) {
        break;
      }
      page++;
    }

    return allEvents;
  }

  // ---------------------------------------------------------------------------
  // Threat events (notable security events)
  // ---------------------------------------------------------------------------

  /// Query notable threat events from WAF.
  ///
  /// Calls `DescribeThreatEvent` for a paginated list of notable events.
  Future<({List<Map<String, dynamic>> events, int totalCount})>
  listThreatEvents({
    required int startTime,
    required int endTime,
    int page = 1,
    int pageSize = 20,
  }) async {
    final id = await _ensureInstanceId();

    final response = await _client.callWafApi(
      'DescribeThreatEvent',
      params: {
        'InstanceId': id,
        'StartTime': '$startTime',
        'EndTime': '$endTime',
        'PageNumber': '$page',
        'PageSize': '$pageSize',
      },
    );

    final totalCount = response['TotalCount'] as int? ?? 0;
    final events = response['ThreatEvents'] as List<dynamic>? ?? [];

    return (
      events: events.cast<Map<String, dynamic>>(),
      totalCount: totalCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Rule hit statistics
  // ---------------------------------------------------------------------------

  /// Query the top 10 rule IDs triggered most frequently.
  ///
  /// Calls `DescribeRuleHitsTopRuleId`.
  Future<List<WafRuleHit>> getTopRuleHits({
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final id = await _ensureInstanceId();

    final response = await _client.callWafApi(
      'DescribeRuleHitsTopRuleId',
      params: {
        'InstanceId': id,
        'StartTimestamp': '$startTimestamp',
        'EndTimestamp': '$endTimestamp',
      },
    );

    final list = response['RuleHitsTopRuleId'] as List<dynamic>? ?? [];
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return WafRuleHit(
        ruleId: map['RuleId']?.toString() ?? '',
        count: map['Count'] as int? ?? 0,
        resource: map['Resource']?.toString(),
      );
    }).toList();
  }

  /// Query the top 10 source IPs by attack count.
  ///
  /// Calls `DescribeRuleHitsTopClientIp`.
  Future<List<Map<String, dynamic>>> getTopAttackerIps({
    required int startTimestamp,
    required int endTimestamp,
  }) async {
    final id = await _ensureInstanceId();

    final response = await _client.callWafApi(
      'DescribeRuleHitsTopClientIp',
      params: {
        'InstanceId': id,
        'StartTimestamp': '$startTimestamp',
        'EndTimestamp': '$endTimestamp',
      },
    );

    return (response['RuleHitsTopClientIp'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  /// Query traffic flow statistics (blocks, requests) as a time series.
  ///
  /// Calls `DescribeFlowChart` with the specified interval.
  Future<List<Map<String, dynamic>>> getFlowChart({
    required int startTimestamp,
    required int endTimestamp,
    int interval = 3600,
  }) async {
    final id = await _ensureInstanceId();

    final response = await _client.callWafApi(
      'DescribeFlowChart',
      params: {
        'InstanceId': id,
        'StartTimestamp': '$startTimestamp',
        'EndTimestamp': '$endTimestamp',
        'Interval': '$interval',
      },
    );

    return (response['FlowChart'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Alarm info
  // ---------------------------------------------------------------------------

  /// Query the WAF alarm list.
  ///
  /// Calls `DescribeAlarmList`.
  Future<({List<Map<String, dynamic>> alarms, int totalCount})> listAlarms({
    required int startTime,
    required int endTime,
    int page = 1,
    int pageSize = 20,
  }) async {
    final id = await _ensureInstanceId();

    final response = await _client.callWafApi(
      'DescribeAlarmList',
      params: {
        'InstanceId': id,
        'StartTime': '$startTime',
        'EndTime': '$endTime',
        'PageNumber': '$page',
        'PageSize': '$pageSize',
      },
    );

    final alarms = response['Alarms'] as List<dynamic>? ?? [];
    final totalCount = response['TotalCount'] as int? ?? alarms.length;

    return (
      alarms: alarms.cast<Map<String, dynamic>>(),
      totalCount: totalCount,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _ensureInstanceId() async {
    if (_instanceId == null) {
      await discoverInstance();
    }
    return _instanceId!;
  }
}

/// A filter condition for WAF security event log queries.
///
/// Supported keys: action, cluster, defense_scene, host, http_cookie,
/// http_user_agent, matched_host, real_client_ip, remote_country_id,
/// remote_region_id, request_method, request_path, request_traceid, rule_id.
///
/// Supported operators: eq, ne, contain, not-contain, match-one,
/// all-not-match, prefix-match, suffix-match.
class WafFilterCondition {
  final String key;
  final String opValue;
  final dynamic values;

  const WafFilterCondition({
    required this.key,
    required this.opValue,
    required this.values,
  });
}
