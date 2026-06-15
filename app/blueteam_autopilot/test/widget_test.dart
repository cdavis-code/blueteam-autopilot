import 'package:flutter_test/flutter_test.dart';

import 'package:blueteam_autopilot/api/models/incident_model.dart';
import 'package:blueteam_autopilot/api/models/recommendation_model.dart';
import 'package:blueteam_autopilot/api/models/api_response.dart';

void main() {
  group('IncidentModel', () {
    test('fromJson parses StoredIncident shape', () {
      final json = {
        'incidentId': 'inc-001',
        'accountId': 'acc-001',
        'status': 'OPEN',
        'createdAt': 1718107200000,
        'updatedAt': 1718107200000,
        'report': {
          'eventId': 'evt-001',
          'title': 'WAF SQLi Attack',
          'severity': 'HIGH',
          'aiSummary': 'SQL injection detected.',
          'rootCause': 'Unpatched web app',
          'businessImpact': 'Data breach risk',
          'attackChain': [
            {'stage': 'Exploit', 'description': 'SQLi on /api/login'},
          ],
          'affectedAssets': ['ecs.example.com'],
          'sourceIps': ['1.2.3.4'],
          'relatedCves': ['CVE-2024-1234'],
          'complianceControls': ['NIST CSF DE.AE-2'],
          'generatedAt': '2026-06-11T12:00:00Z',
        },
      };

      final model = IncidentModel.fromJson(json);
      expect(model.incidentId, 'inc-001');
      expect(model.status, 'OPEN');
      expect(model.report.title, 'WAF SQLi Attack');
      expect(model.report.severity, 'HIGH');
      expect(model.report.hasAiAnalysis, isTrue);
      expect(model.report.attackChain, hasLength(1));
      expect(model.report.sourceIps, ['1.2.3.4']);
    });

    test('fromJson handles missing fields gracefully', () {
      final model = IncidentModel.fromJson({});
      expect(model.incidentId, '');
      expect(model.status, 'OPEN');
      expect(model.report.title, 'Unknown');
      expect(model.report.hasAiAnalysis, isFalse);
    });
  });

  group('RecommendationModel', () {
    test('fromJson parses StoredRecommendation shape', () {
      final json = {
        'recommendationId': 'rec-001',
        'incidentId': 'inc-001',
        'status': 'PENDING',
        'executionLog': null,
        'createdAt': 1718107200000,
        'proposal': {
          'reasoning': 'Block attacker IP',
          'recommendedPolicyId': 'pol-001',
          'expectedEffects': 'Block IP 1.2.3.4 for 24h',
          'rollbackPlan': 'Remove from blocklist',
          'riskLevel': 'LOW',
          'requiresApproval': true,
          'complianceControls': ['SOC 2 CC6.8'],
          'eventId': 'evt-001',
          'trustedNetworkMatch': false,
        },
      };

      final model = RecommendationModel.fromJson(json);
      expect(model.recommendationId, 'rec-001');
      expect(model.status, 'PENDING');
      expect(model.proposal.reasoning, 'Block attacker IP');
      expect(model.proposal.requiresApproval, isTrue);
      expect(model.proposal.trustedNetworkMatch, isFalse);
    });
  });

  group('ApiResponse', () {
    test('parses success envelope', () {
      final json = {
        'data': [
          {'key': 'value'},
        ],
        'error': null,
        'meta': {'total': 1},
      };

      final response = ApiResponse<List<dynamic>>.fromJson(
        json,
        (data) => data as List<dynamic>,
      );
      expect(response.isSuccess, isTrue);
      expect(response.data, hasLength(1));
      expect(response.meta?.total, 1);
    });

    test('parses error envelope', () {
      final json = {
        'data': null,
        'error': {'code': 'NOT_FOUND', 'message': 'Incident not found'},
        'meta': null,
      };

      final response = ApiResponse<dynamic>.fromJson(json, (data) => data);
      expect(response.isSuccess, isFalse);
      expect(response.error?.code, 'NOT_FOUND');
    });
  });

  group('AnalysisResultModel', () {
    test('fromJson parses analysis result', () {
      final json = {
        'incidentIds': ['inc-001', 'inc-002'],
        'skippedEventIds': ['evt-skip'],
        'errors': {'evt-fail': 'timeout'},
      };

      final model = AnalysisResultModel.fromJson(json);
      expect(model.incidentIds, hasLength(2));
      expect(model.skippedEventIds, ['evt-skip']);
      expect(model.errors, containsPair('evt-fail', 'timeout'));
    });
  });
}
