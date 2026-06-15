import '../client/alibaba_api_client.dart';
import '../enums.dart';
import '../models/alert.dart';
import '../models/security_event.dart';
import '../models/vulnerability.dart';
import '../util/time_window.dart';

/// Wraps Alibaba Cloud Security Center (SAS 2018-12-03) APIs.
///
/// Provides methods for listing security events, getting event details,
/// listing alerts, and managing vulnerabilities.
class SecurityCenterService {
  final AlibabaApiClient _client;

  SecurityCenterService(this._client);

  /// List security events from Agentic SOC within a time window.
  ///
  /// Maps to the Agentic SOC event listing APIs.
  /// [window] defines the time boundaries (defaults to [TimeRange.lastHour]).
  /// [minSeverity] filters by minimum severity level.
  /// [status] filters by event status.
  Future<List<SecurityEvent>> listSecurityEvents({
    TimeWindow? window,
    Severity? minSeverity,
    EventStatus? status,
  }) async {
    final effectiveWindow = window ?? TimeWindow.fromRange(TimeRange.lastHour);
    final startTime = effectiveWindow.startEpochMillis;
    final endTime = effectiveWindow.endEpochMillis;

    final params = <String, String>{
      'StartTime': startTime.toString(),
      'EndTime': endTime.toString(),
      'CurrentPage': '1',
      'PageSize': '20',
    };

    if (minSeverity != null) {
      params['Level'] = minSeverity.name.toUpperCase();
    }
    if (status != null) {
      params['Dealed'] = status == EventStatus.resolved ? 'Y' : 'N';
    }

    final response = await _client.callSasApi(
      'DescribeAlarmEventList',
      params: params,
    );

    // DescribeAlarmEventList returns SuspEvents at root level
    // (not nested under Data.AlarmEventList as older docs suggest).
    final list =
        response['SuspEvents'] as List<dynamic>? ??
        (response['Data'] as Map<String, dynamic>?)?['AlarmEventList']
            as List<dynamic>? ??
        [];

    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return SecurityEvent(
        eventId:
            map['UniqueInfo']?.toString() ??
            map['AlarmEventId']?.toString() ??
            '',
        title:
            map['AlarmEventName']?.toString() ??
            map['EventName']?.toString() ??
            'Unknown Event',
        severity: map['Level']?.toString() ?? 'MEDIUM',
        sourceProducts: _extractSourceProducts(map),
        affectedAssets: _extractAffectedAssets(map),
        firstSeen: _formatTimestamp(map['StartTime'] ?? map['GmtCreate']),
        lastSeen: _formatTimestamp(map['EndTime'] ?? map['GmtModified']),
      );
    }).toList();
  }

  /// Get full details of a security event by ID.
  ///
  /// Wraps the `GetAttackEventDetail` API.
  Future<SecurityEventDetail> getSecurityEventDetail(String eventId) async {
    final response = await _client.callSasApi(
      'GetAttackEventDetail',
      params: {'AlarmEventId': eventId},
    );

    final data = response['Data'] as Map<String, dynamic>? ?? {};

    return SecurityEventDetail(
      eventId: eventId,
      title: data['AlarmEventName']?.toString() ?? 'Unknown Event',
      severity: data['Level']?.toString() ?? 'MEDIUM',
      attackChain: _extractAttackChain(data),
      source: data['DataSource']?.toString(),
      relatedAlerts: _extractStringList(data, 'RelatedAlertIds'),
      attackers: _extractStringList(data, 'Attackers'),
      attackerCountries: _extractStringList(data, 'AttackerCountries'),
      relatedVulnerabilities: _extractStringList(data, 'RelatedVulIds'),
      raw: data,
    );
  }

  /// List alerts grouped by source for a given event.
  ///
  /// Returns alerts organized by their source product (WAF, CWPP, etc.).
  Future<AlertsForEvent> listAlertsForEvent(String eventId) async {
    final response = await _client.callSasApi(
      'DescribeAlarmEventDetail',
      params: {'AlarmEventId': eventId},
    );

    final data = response['Data'] as Map<String, dynamic>? ?? {};
    final alertList = data['AlertList'] as List<dynamic>? ?? [];

    final alertsBySource = <String, List<Alert>>{};

    for (final item in alertList) {
      final map = item as Map<String, dynamic>;
      final source = map['DataSource']?.toString() ?? 'Unknown';
      final alert = Alert(
        alertId: map['AlertId']?.toString() ?? '',
        ruleId: map['RuleId']?.toString(),
        severity: map['Level']?.toString() ?? 'MEDIUM',
        message: map['AlertName']?.toString() ?? 'Unknown alert',
        source: source,
        timestamp: _formatTimestamp(map['GmtModified']),
      );

      alertsBySource.putIfAbsent(source, () => []).add(alert);
    }

    return AlertsForEvent(eventId: eventId, alertsBySource: alertsBySource);
  }

  /// List vulnerabilities detected by Security Center.
  ///
  /// Wraps the `DescribeVulList` API with automatic pagination.
  Future<List<Vulnerability>> listVulnerabilities({
    Severity? severity,
    String? assetId,
    VulType? vulType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'CurrentPage': page.toString(),
      'PageSize': pageSize.toString(),
      // 'Type' is required by DescribeVulList; default to 'cve'.
      'Type': vulType != null ? _vulTypeToApiString(vulType) : 'cve',
    };

    if (severity != null) {
      params['Level'] = severity.name.toLowerCase();
    }
    if (assetId != null) {
      params['Uuid'] = assetId;
    }

    final response = await _client.callSasApi(
      'DescribeVulList',
      params: params,
    );

    final vulList = response['VulList'] as List<dynamic>? ?? [];

    return vulList.map((item) {
      final map = item as Map<String, dynamic>;
      return Vulnerability(
        vulId: map['VulId']?.toString() ?? '',
        name: map['Name']?.toString() ?? 'Unknown Vulnerability',
        severity: map['Level']?.toString() ?? 'MEDIUM',
        vulType: map['Type']?.toString() ?? 'cve',
        assetId: map['Uuid']?.toString(),
        assetType: map['AssetType']?.toString(),
        firstFound: _formatTimestamp(map['FirstTs']),
        lastFound: _formatTimestamp(map['LastTs']),
        status: map['Status']?.toString(),
      );
    }).toList();
  }

  /// Get detailed information about a specific vulnerability.
  ///
  /// Wraps the `DescribeVulDetails` API.
  Future<VulnerabilityDetail> getVulnerabilityDetail(String vulId) async {
    final response = await _client.callSasApi(
      'DescribeVulDetails',
      params: {'VulId': vulId},
    );

    return VulnerabilityDetail(
      vulId: vulId,
      name: response['Name']?.toString() ?? 'Unknown Vulnerability',
      severity: response['Level']?.toString() ?? 'MEDIUM',
      vulType: response['Type']?.toString() ?? 'cve',
      cveId: response['CveId']?.toString(),
      description: response['Description']?.toString(),
      affectedVersions: _extractStringList(response, 'AffectedVersions'),
      fixSuggestion:
          response['FixSuggestion']?.toString() ??
          response['Solution']?.toString(),
    );
  }

  /// List cloud assets (instances) registered in Security Center.
  ///
  /// Wraps the `DescribeCloudCenterInstances` API to discover assets
  /// dynamically rather than relying on hardcoded hostnames.
  ///
  /// Returns a list of maps each containing at minimum:
  /// `uuid`, `instanceName`, `internetIp`, `intranetIp`, `regionId`,
  /// `assetType`, and `os`.
  Future<List<Map<String, dynamic>>> listAssets({
    String? criteria,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'CurrentPage': page.toString(),
      'PageSize': pageSize.toString(),
    };
    if (criteria != null && criteria.isNotEmpty) {
      params['Criteria'] = criteria;
    }

    final response = await _client.callSasApi(
      'DescribeCloudCenterInstances',
      params: params,
    );

    final list =
        response['Instances'] as List<dynamic>? ??
        (response['PageInfo'] as Map<String, dynamic>?)?['Instances']
            as List<dynamic>? ??
        [];

    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return {
        'uuid': m['Uuid']?.toString() ?? '',
        'instanceId': m['InstanceId']?.toString() ?? '',
        'instanceName': m['InstanceName']?.toString() ?? 'Unknown',
        'internetIp': m['InternetIp']?.toString(),
        'intranetIp': m['IntranetIp']?.toString(),
        'regionId': m['RegionId']?.toString(),
        'assetType': m['AssetType']?.toString() ?? 'Unknown',
        'os': m['Os']?.toString() ?? m['OsName']?.toString(),
        'clientStatus': m['ClientStatus']?.toString(),
      };
    }).toList();
  }

  /// Get minimal account context for the configured region.
  Future<Map<String, dynamic>> getAccountContext() async {
    try {
      final response = await _client.callSasApi('DescribeVersionConfig');
      return {
        'region': _client.region,
        'securityCenterEdition': response['Version']?.toString() ?? 'Unknown',
        'agenticSocEnabled': (response['IsAgenticSoc'] as bool?) ?? false,
        'mode': _client.mode.name,
      };
    } catch (_) {
      // If the API call fails, return minimal context
      return {
        'region': _client.region,
        'securityCenterEdition': 'Unknown',
        'agenticSocEnabled': false,
        'mode': _client.mode.name,
      };
    }
  }

  // --- Private helpers ---

  List<String> _extractSourceProducts(Map<String, dynamic> map) {
    final sources = map['DataSources'] as List<dynamic>?;
    if (sources == null) {
      final single = map['DataSource']?.toString();
      return single != null ? [single] : [];
    }
    return sources.map((s) => s.toString()).toList();
  }

  List<AffectedAsset> _extractAffectedAssets(Map<String, dynamic> map) {
    final assets =
        map['AffectedAssets'] as List<dynamic>? ??
        map['InstanceList'] as List<dynamic>?;
    if (assets == null) return [];

    return assets.map((item) {
      final m = item as Map<String, dynamic>;
      return AffectedAsset(
        assetId: m['Uuid']?.toString() ?? m['InstanceId']?.toString() ?? '',
        assetType:
            m['AssetType']?.toString() ??
            m['InstanceType']?.toString() ??
            'Unknown',
        region: m['RegionId']?.toString(),
      );
    }).toList();
  }

  List<AttackChainStage> _extractAttackChain(Map<String, dynamic> data) {
    final chain = data['AttackChain'] as List<dynamic>? ?? [];
    return chain.map((item) {
      final m = item as Map<String, dynamic>;
      return AttackChainStage(
        stage: m['Stage']?.toString() ?? 'Unknown',
        description: m['Description']?.toString() ?? '',
      );
    }).toList();
  }

  List<String> _extractStringList(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((s) => s.trim()).toList();
    }
    return [];
  }

  String? _formatTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    return value.toString();
  }

  String _vulTypeToApiString(VulType type) {
    return switch (type) {
      VulType.cve => 'cve',
      VulType.webCms => 'web_cms',
      VulType.app => 'app',
      VulType.system => 'sys',
    };
  }
}
