import 'package:alibaba_security_api/alibaba_security_api.dart';
import 'package:test/test.dart';

void main() {
  group('TimeRange', () {
    test('fromString parses shortcuts', () {
      expect(TimeRange.fromString('last15Min'), TimeRange.last15Min);
      expect(TimeRange.fromString('15m'), TimeRange.last15Min);
      expect(TimeRange.fromString('lastHour'), TimeRange.lastHour);
      expect(TimeRange.fromString('1h'), TimeRange.lastHour);
      expect(TimeRange.fromString('4h'), TimeRange.last4Hours);
      expect(TimeRange.fromString('24h'), TimeRange.last24Hours);
      expect(TimeRange.fromString('7d'), TimeRange.last7Days);
      expect(TimeRange.fromString('1w'), TimeRange.last7Days);
      expect(TimeRange.fromString('30d'), TimeRange.last30Days);
      expect(TimeRange.fromString('custom'), TimeRange.custom);
    });

    test('fromString defaults to lastHour for unknown values', () {
      expect(TimeRange.fromString('garbage'), TimeRange.lastHour);
      expect(TimeRange.fromString(null), TimeRange.lastHour);
      expect(TimeRange.fromString(''), TimeRange.lastHour);
    });
  });

  group('TimeWindow', () {
    test('fromRange computes correct boundaries', () {
      final now = DateTime.utc(2026, 6, 11, 12, 0, 0);
      final window = TimeWindow.fromRange(TimeRange.lastHour, now: now);

      expect(window.start, DateTime.utc(2026, 6, 11, 11, 0, 0));
      expect(window.end, now);
      expect(window.range, TimeRange.lastHour);
      expect(window.durationMinutes, 60);
    });

    test('fromRange rejects custom range', () {
      expect(() => TimeWindow.fromRange(TimeRange.custom), throwsArgumentError);
    });

    test('fromIso8601 parses custom range', () {
      final window = TimeWindow.fromIso8601(
        '2026-06-11T00:00:00Z',
        '2026-06-11T12:00:00Z',
      );

      expect(window.range, TimeRange.custom);
      expect(window.durationMinutes, 720);
      expect(window.startEpochSeconds, isNonZero);
    });

    test('enforceGuardrails clamps to 30 days', () {
      final now = DateTime.utc(2026, 6, 11, 12, 0, 0);
      final wideWindow = TimeWindow.fromIso8601(
        '2026-04-01T00:00:00Z',
        '2026-06-11T12:00:00Z',
        maxLookbackDays: 90, // allow wide window
      );
      final clamped = wideWindow.enforceGuardrails(
        maxLookbackDays: 30,
        now: now,
      );

      // Start should be clamped to now - 30 days
      expect(clamped.start, now.subtract(const Duration(days: 30)));
      expect(clamped.end, now);
    });

    test('resolve prefers shortcut over ISO', () {
      final window = TimeWindow.resolve(
        range: TimeRange.last4Hours,
        startIso: '2026-06-01T00:00:00Z',
        endIso: '2026-06-02T00:00:00Z',
      );

      expect(window.range, TimeRange.last4Hours);
    });

    test('resolve falls back to ISO when custom', () {
      final window = TimeWindow.resolve(
        range: TimeRange.custom,
        startIso: '2026-06-11T00:00:00Z',
        endIso: '2026-06-11T12:00:00Z',
      );

      expect(window.range, TimeRange.custom);
      expect(window.durationMinutes, 720);
    });

    test('resolve defaults to lastHour when no args', () {
      final window = TimeWindow.resolve();
      expect(window.range, TimeRange.lastHour);
    });

    test('toJson includes all expected fields', () {
      final window = TimeWindow.fromRange(TimeRange.last24Hours);
      final json = window.toJson();

      expect(json, containsPair('start', isA<String>()));
      expect(json, containsPair('end', isA<String>()));
      expect(json, containsPair('startEpochSeconds', isA<int>()));
      expect(json, containsPair('endEpochSeconds', isA<int>()));
      expect(json, containsPair('range', 'last24Hours'));
      expect(json, containsPair('durationMinutes', isA<int>()));
    });

    test('fromEpoch creates window from Unix seconds', () {
      final start = DateTime.utc(2026, 6, 11, 0, 0, 0);
      final end = DateTime.utc(2026, 6, 11, 12, 0, 0);
      final window = TimeWindow.fromEpoch(
        start.millisecondsSinceEpoch ~/ 1000,
        end.millisecondsSinceEpoch ~/ 1000,
      );

      expect(window.start, start);
      expect(window.end, end);
    });
  });

  group('Enums', () {
    test('Severity.fromString parses case-insensitively', () {
      expect(Severity.fromString('HIGH'), Severity.high);
      expect(Severity.fromString('low'), Severity.low);
      expect(Severity.fromString('Critical'), Severity.critical);
      expect(Severity.fromString('unknown'), Severity.medium);
    });

    test('EventStatus.fromString parses variants', () {
      expect(EventStatus.fromString('NEW'), EventStatus.newEvent);
      expect(EventStatus.fromString('in_progress'), EventStatus.inProgress);
      expect(EventStatus.fromString('resolved'), EventStatus.resolved);
    });

    test('VulType.fromString parses variants', () {
      expect(VulType.fromString('CVE'), VulType.cve);
      expect(VulType.fromString('WEB_CMS'), VulType.webCms);
      expect(VulType.fromString('app'), VulType.app);
      expect(VulType.fromString('system'), VulType.system);
    });

    test('SecurityCenterMode.fromString parses correctly', () {
      expect(SecurityCenterMode.fromString('real'), SecurityCenterMode.real);
      expect(
        SecurityCenterMode.fromString('dry-run'),
        SecurityCenterMode.dryRun,
      );
      expect(
        SecurityCenterMode.fromString('dry_run'),
        SecurityCenterMode.dryRun,
      );
      expect(
        SecurityCenterMode.fromString('anything'),
        SecurityCenterMode.dryRun,
      );
    });

    test('PolicyScope.fromString parses correctly', () {
      expect(PolicyScope.fromString('waf'), PolicyScope.waf);
      expect(PolicyScope.fromString('WAF'), PolicyScope.waf);
      expect(PolicyScope.fromString('all'), PolicyScope.all);
      expect(PolicyScope.fromString('anything'), PolicyScope.all);
    });
  });

  group('Models', () {
    test('SecurityEvent serializes to/from JSON', () {
      const event = SecurityEvent(
        eventId: 'evt-123',
        title: 'SQL Injection Attempt',
        severity: 'HIGH',
        sourceProducts: ['WAF'],
        affectedAssets: [
          AffectedAsset(
            assetId: 'i-abc',
            assetType: 'ECS',
            region: 'cn-hangzhou',
          ),
        ],
        firstSeen: '2024-01-01T00:00:00Z',
        lastSeen: '2024-01-01T01:00:00Z',
      );

      final json = event.toJson();
      expect(json['eventId'], 'evt-123');
      expect(json['severity'], 'HIGH');

      final restored = SecurityEvent.fromJson(json);
      expect(restored.eventId, event.eventId);
      expect(restored.title, event.title);
      expect(restored.affectedAssets.length, 1);
    });

    test('Alert serializes to/from JSON', () {
      const alert = Alert(
        alertId: 'alert-1',
        ruleId: 'rule-42',
        severity: 'HIGH',
        message: 'SQLi attempt detected',
        source: 'WAF',
      );

      final json = alert.toJson();
      final restored = Alert.fromJson(json);
      expect(restored.alertId, alert.alertId);
      expect(restored.ruleId, 'rule-42');
    });

    test('Vulnerability serializes to/from JSON', () {
      const vuln = Vulnerability(
        vulId: 'vul-1',
        name: 'CVE-2024-1234',
        severity: 'CRITICAL',
        vulType: 'cve',
        assetId: 'i-abc',
        status: 'PENDING',
      );

      final json = vuln.toJson();
      final restored = Vulnerability.fromJson(json);
      expect(restored.vulId, 'vul-1');
      expect(restored.severity, 'CRITICAL');
    });

    test('ResponsePolicy serializes to/from JSON', () {
      const policy = ResponsePolicy(
        policyId: 'pol-1',
        name: 'Block Attacker IP',
        actionType: 'BLOCK_IP',
        isEnabled: true,
      );

      final json = policy.toJson();
      final restored = ResponsePolicy.fromJson(json);
      expect(restored.policyId, 'pol-1');
      expect(restored.actionType, 'BLOCK_IP');
      expect(restored.isEnabled, true);
    });

    test('ExecuteResponseResult serializes to/from JSON', () {
      const result = ExecuteResponseResult(
        policyId: 'pol-1',
        eventId: 'evt-123',
        mode: 'dry-run',
        result: 'Simulated execution',
      );

      final json = result.toJson();
      final restored = ExecuteResponseResult.fromJson(json);
      expect(restored.mode, 'dry-run');
      expect(restored.policyId, 'pol-1');
    });

    test('AccountContext serializes to/from JSON', () {
      const ctx = AccountContext(
        region: 'cn-hangzhou',
        securityCenterEdition: 'Advanced',
        agenticSocEnabled: true,
        mode: 'dry-run',
      );

      final json = ctx.toJson();
      final restored = AccountContext.fromJson(json);
      expect(restored.region, 'cn-hangzhou');
      expect(restored.agenticSocEnabled, true);
    });

    test('AlibabaApiError creates structured error envelopes', () {
      final error = AlibabaApiError.api(
        message: 'Forbidden',
        httpStatus: 403,
        api: 'DescribeVulList',
      );

      expect(error.error.code, 'ALIBABA_API_ERROR');
      expect(error.error.details?.httpStatus, 403);
      expect(error.error.details?.api, 'DescribeVulList');

      final json = error.toJson();
      expect(json['error']['code'], 'ALIBABA_API_ERROR');
    });

    test('AlibabaApiError.credentials creates credential errors', () {
      final error = AlibabaApiError.credentials(
        message: 'Missing ALIBABA_ACCESS_KEY_ID',
      );
      expect(error.error.code, 'CREDENTIALS_ERROR');
    });

    test('AlibabaApiError.validation creates validation errors', () {
      final error = AlibabaApiError.validation(
        message: 'eventId must not be empty',
      );
      expect(error.error.code, 'VALIDATION_ERROR');
    });
  });

  group('AlibabaCredentials', () {
    test('explicit credentials are created correctly', () {
      const creds = AlibabaCredentials(
        accessKeyId: 'test-key-id',
        accessKeySecret: 'test-key-secret',
      );
      expect(creds.accessKeyId, 'test-key-id');
      expect(creds.accessKeySecret, 'test-key-secret');
      expect(creds.isStsCredential, false);
    });

    test('STS credentials are detected', () {
      const creds = AlibabaCredentials(
        accessKeyId: 'test-key-id',
        accessKeySecret: 'test-key-secret',
        securityToken: 'test-token',
      );
      expect(creds.isStsCredential, true);
    });
  });

  group('AlibabaSigner', () {
    test('signRequest produces required headers', () {
      const creds = AlibabaCredentials(
        accessKeyId: 'test-key-id',
        accessKeySecret: 'test-key-secret',
      );

      final signer = AlibabaSigner(credentials: creds, region: 'cn-hangzhou');

      final headers = signer.signRequest(
        method: 'GET',
        uri: Uri.parse(
          'https://tds.cn-hangzhou.aliyuncs.com/?Action=DescribeVulList',
        ),
        action: 'DescribeVulList',
      );

      expect(headers.containsKey('Authorization'), true);
      expect(headers.containsKey('x-acs-date'), true);
      expect(headers.containsKey('x-acs-signature-nonce'), true);
      expect(headers['Authorization'], startsWith('ACS3-HMAC-SHA256'));
    });

    test('signRequest includes security token for STS credentials', () {
      const creds = AlibabaCredentials(
        accessKeyId: 'test-key-id',
        accessKeySecret: 'test-key-secret',
        securityToken: 'test-sts-token',
      );

      final signer = AlibabaSigner(credentials: creds, region: 'cn-hangzhou');

      final headers = signer.signRequest(
        method: 'GET',
        uri: Uri.parse('https://tds.cn-hangzhou.aliyuncs.com/'),
        action: 'DescribeAlarmEventList',
      );

      expect(headers.containsKey('x-acs-security-token'), true);
      expect(headers['x-acs-security-token'], 'test-sts-token');
    });
  });
}
