import 'dart:convert';

import 'package:alibaba_security_agent/alibaba_security_agent.dart';
import 'package:alibaba_security_backend/alibaba_security_backend.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('BackendConfig', () {
    test('has default values', () {
      const config = BackendConfig(
        port: 8080,
        region: 'ap-southeast-1',
        tablestoreInstance: '',
        tablestoreEndpoint: '',
        qwenApiKey: '',
      );

      expect(config.port, 8080);
      expect(config.incidentsTable, 'incidents');
      expect(config.recommendationsTable, 'recommendations');
      expect(config.defaultDryRun, isTrue);
      expect(config.defaultTimeRange, 'lastHour');
      expect(config.maxIncidentsPerBatch, 10);
      expect(config.hasTableStore, isFalse);
      expect(config.hasQwen, isFalse);
    });

    test('detects TableStore configuration', () {
      const config = BackendConfig(
        port: 8080,
        region: 'ap-southeast-1',
        tablestoreInstance: 'my-instance',
        tablestoreEndpoint: 'https://my-instance.ap-southeast-1.tablestore.aliyuncs.com',
        qwenApiKey: 'sk-test',
      );

      expect(config.hasTableStore, isTrue);
      expect(config.hasQwen, isTrue);
    });
  });

  group('IncidentRepository (in-memory)', () {
    late IncidentRepository repo;

    setUp(() {
      const config = BackendConfig(
        port: 8080,
        region: 'ap-southeast-1',
        tablestoreInstance: '',
        tablestoreEndpoint: '',
        qwenApiKey: '',
      );
      repo = IncidentRepository(config: config);
    });

    test('creates and retrieves an incident', () async {
      final report = IncidentReport(
        eventId: 'evt-001',
        title: 'WAF SQLi attempt',
        severity: 'HIGH',
        aiSummary: 'SQL injection attempt from 1.2.3.4',
        rootCause: 'Unpatched web application',
        businessImpact: 'Potential data breach',
      );

      final id = await repo.create(report);
      expect(id, isNotEmpty);

      final stored = await repo.getById(id);
      expect(stored, isNotNull);
      expect(stored!.report.eventId, 'evt-001');
      expect(stored.report.title, 'WAF SQLi attempt');
      expect(stored.status, 'OPEN');
    });

    test('lists incidents with severity filter', () async {
      await repo.create(IncidentReport(
        eventId: 'evt-001',
        title: 'Low severity',
        severity: 'LOW',
        aiSummary: '',
        rootCause: '',
        businessImpact: '',
      ));
      await repo.create(IncidentReport(
        eventId: 'evt-002',
        title: 'High severity',
        severity: 'HIGH',
        aiSummary: '',
        rootCause: '',
        businessImpact: '',
      ));

      final highOnly = await repo.list(severity: 'HIGH');
      expect(highOnly, hasLength(1));
      expect(highOnly.first.report.eventId, 'evt-002');
    });

    test('updates incident status', () async {
      final id = await repo.create(IncidentReport(
        eventId: 'evt-003',
        title: 'Test',
        severity: 'MEDIUM',
        aiSummary: '',
        rootCause: '',
        businessImpact: '',
      ));

      await repo.updateStatus(id, 'RESOLVED');
      final stored = await repo.getById(id);
      expect(stored!.status, 'RESOLVED');
    });

    test('finds incident by event ID', () async {
      await repo.create(IncidentReport(
        eventId: 'evt-dup',
        title: 'Duplicate check',
        severity: 'LOW',
        aiSummary: '',
        rootCause: '',
        businessImpact: '',
      ));

      final found = await repo.findByEventId('evt-dup');
      expect(found, isNotNull);
      expect(found!.report.title, 'Duplicate check');

      final notFound = await repo.findByEventId('evt-nonexistent');
      expect(notFound, isNull);
    });
  });

  group('RecommendationRepository (in-memory)', () {
    late RecommendationRepository repo;

    setUp(() {
      const config = BackendConfig(
        port: 8080,
        region: 'ap-southeast-1',
        tablestoreInstance: '',
        tablestoreEndpoint: '',
        qwenApiKey: '',
      );
      repo = RecommendationRepository(config: config);
    });

    test('creates and retrieves a recommendation', () async {
      const proposal = ActionProposal(
        reasoning: 'Block attacker IP',
        recommendedPolicyId: 'pol-001',
        expectedEffects: 'Block IP 1.2.3.4 for 24h',
        rollbackPlan: 'Remove IP from blocklist',
        riskLevel: 'LOW',
      );

      final id = await repo.create(proposal, 'inc-001');
      expect(id, isNotEmpty);

      final stored = await repo.getById(id);
      expect(stored, isNotNull);
      expect(stored!.proposal.reasoning, 'Block attacker IP');
      expect(stored.incidentId, 'inc-001');
      expect(stored.status, 'PENDING');
    });

    test('lists recommendations for an incident', () async {
      await repo.create(
        const ActionProposal(
          reasoning: 'Action 1',
          recommendedPolicyId: 'pol-001',
          expectedEffects: '',
          rollbackPlan: '',
          riskLevel: 'LOW',
        ),
        'inc-100',
      );
      await repo.create(
        const ActionProposal(
          reasoning: 'Action 2',
          recommendedPolicyId: 'pol-002',
          expectedEffects: '',
          rollbackPlan: '',
          riskLevel: 'MEDIUM',
        ),
        'inc-100',
      );

      final recs = await repo.listForIncident('inc-100');
      expect(recs, hasLength(2));
    });

    test('updates recommendation status', () async {
      final id = await repo.create(
        const ActionProposal(
          reasoning: 'Test',
          recommendedPolicyId: 'pol-001',
          expectedEffects: '',
          rollbackPlan: '',
          riskLevel: 'LOW',
        ),
        'inc-200',
      );

      await repo.updateStatus(id, 'APPROVED');
      final stored = await repo.getById(id);
      expect(stored!.status, 'APPROVED');
    });
  });

  group('HealthHandler', () {
    test('returns ok status', () async {
      const config = BackendConfig(
        port: 8080,
        region: 'ap-southeast-1',
        tablestoreInstance: '',
        tablestoreEndpoint: '',
        qwenApiKey: '',
      );
      final handler = HealthHandler(config);
      final router = handler.router;

      final request = Request('GET', Uri.parse('http://localhost/health'));
      final response = await router.call(request);

      expect(response.statusCode, 200);
      final body = json.decode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['data']['status'], 'ok');
      expect(body['data']['region'], 'ap-southeast-1');
      expect(body['data']['tablestore'], 'in-memory');
      expect(body['data']['qwen'], 'not configured');
    });
  });

  group('IncidentHandler', () {
    late IncidentRepository incidentRepo;
    late RecommendationRepository recRepo;
    late IncidentHandler handler;

    setUp(() {
      const config = BackendConfig(
        port: 8080,
        region: 'ap-southeast-1',
        tablestoreInstance: '',
        tablestoreEndpoint: '',
        qwenApiKey: '',
      );
      incidentRepo = IncidentRepository(config: config);
      recRepo = RecommendationRepository(config: config);
      handler = IncidentHandler(incidentRepo, recRepo);
    });

    test('GET /api/v1/incidents returns empty list initially', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/incidents'),
      );
      final response = await handler.router.call(request);
      expect(response.statusCode, 200);

      final body = json.decode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['data'], isEmpty);
      expect(body['meta']['total'], 0);
    });

    test('GET /api/v1/incidents/<id> returns 404 for unknown', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/incidents/unknown-id'),
      );
      final response = await handler.router.call(request);
      expect(response.statusCode, 404);
    });

    test('GET /api/v1/incidents returns created incidents', () async {
      await incidentRepo.create(IncidentReport(
        eventId: 'evt-api',
        title: 'API test',
        severity: 'HIGH',
        aiSummary: '',
        rootCause: '',
        businessImpact: '',
      ));

      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/v1/incidents'),
      );
      final response = await handler.router.call(request);
      final body = json.decode(await response.readAsString()) as Map<String, dynamic>;
      expect((body['data'] as List), hasLength(1));
    });
  });

  group('CORS middleware', () {
    test('adds CORS headers to responses', () async {
      final handler = corsMiddleware()(
        (request) => Response.ok('hello'),
      );

      final request = Request('GET', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers['access-control-allow-methods'],
        contains('GET'),
      );
    });

    test('handles OPTIONS preflight requests', () async {
      final handler = corsMiddleware()(
        (request) => Response.ok('should not reach'),
      );

      final request = Request('OPTIONS', Uri.parse('http://localhost/test'));
      final response = await handler(request);

      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], '*');
    });
  });

  group('StoredIncident serialization', () {
    test('toJson includes all fields', () {
      final stored = StoredIncident(
        incidentId: 'inc-001',
        accountId: 'acc-001',
        report: const IncidentReport(
          eventId: 'evt-001',
          title: 'Test',
          severity: 'HIGH',
          aiSummary: 'Summary',
          rootCause: 'Root',
          businessImpact: 'Impact',
        ),
        status: 'OPEN',
        createdAt: 1000,
        updatedAt: 2000,
      );

      final json = stored.toJson();
      expect(json['incidentId'], 'inc-001');
      expect(json['status'], 'OPEN');
      expect(json['report']['eventId'], 'evt-001');
    });
  });

  group('StoredRecommendation serialization', () {
    test('toJson includes all fields', () {
      final stored = StoredRecommendation(
        recommendationId: 'rec-001',
        accountId: 'acc-001',
        incidentId: 'inc-001',
        proposal: const ActionProposal(
          reasoning: 'Block IP',
          recommendedPolicyId: 'pol-001',
          expectedEffects: 'Block 1.2.3.4',
          rollbackPlan: 'Unblock',
          riskLevel: 'LOW',
        ),
        status: 'PENDING',
        createdAt: 1000,
      );

      final json = stored.toJson();
      expect(json['recommendationId'], 'rec-001');
      expect(json['incidentId'], 'inc-001');
      expect(json['proposal']['reasoning'], 'Block IP');
    });
  });
}
