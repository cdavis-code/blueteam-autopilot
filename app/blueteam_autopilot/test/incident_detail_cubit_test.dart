import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:blueteam_autopilot/api/backend_client.dart';
import 'package:blueteam_autopilot/api/models/incident_model.dart';
import 'package:blueteam_autopilot/api/models/recommendation_model.dart';
import 'package:blueteam_autopilot/cubits/incident_detail/incident_detail_cubit.dart';
import 'package:blueteam_autopilot/cubits/incident_detail/incident_detail_state.dart';

class MockBackendClient extends Mock implements BackendClient {}

void main() {
  late MockBackendClient mockClient;

  setUp(() {
    mockClient = MockBackendClient();
  });

  final sampleDetail = IncidentDetailModel(
    incident: IncidentModel(
      incidentId: 'inc-001',
      accountId: 'acc-001',
      status: 'OPEN',
      createdAt: 1718107200000,
      updatedAt: 1718107200000,
      report: IncidentReportModel(
        eventId: 'evt-001',
        title: 'WAF SQLi Attack',
        severity: 'HIGH',
        aiSummary: 'SQL injection detected.',
        rootCause: 'Unpatched web app',
        businessImpact: 'Data breach risk',
        attackChain: [],
        affectedAssets: ['ecs.example.com'],
        sourceIps: ['1.2.3.4'],
        relatedCves: [],
        complianceControls: [],
      ),
    ),
    recommendations: [
      RecommendationModel(
        recommendationId: 'rec-001',
        incidentId: 'inc-001',
        status: 'PENDING',
        createdAt: 1718107200000,
        proposal: ActionProposalModel(
          reasoning: 'Block attacker IP',
          recommendedPolicyId: 'pol-001',
          expectedEffects: 'Block IP 1.2.3.4',
          rollbackPlan: 'Unblock IP',
          riskLevel: 'LOW',
        ),
      ),
    ],
  );

  group('IncidentDetailCubit', () {
    test('initial state is IncidentDetailInitial', () {
      final cubit = IncidentDetailCubit(mockClient);
      expect(cubit.state, isA<IncidentDetailInitial>());
      cubit.close();
    });

    blocTest<IncidentDetailCubit, IncidentDetailState>(
      'load emits [Loading, Loaded] on success',
      build: () {
        when(
          () => mockClient.getIncident('inc-001'),
        ).thenAnswer((_) async => sampleDetail);
        return IncidentDetailCubit(mockClient);
      },
      act: (cubit) => cubit.load('inc-001'),
      expect: () => [
        isA<IncidentDetailLoading>(),
        isA<IncidentDetailLoaded>().having(
          (s) => s.detail.incident.incidentId,
          'incidentId',
          'inc-001',
        ),
      ],
    );

    blocTest<IncidentDetailCubit, IncidentDetailState>(
      'load emits [Loading, Error] when not found',
      build: () {
        when(
          () => mockClient.getIncident('inc-999'),
        ).thenThrow(const ApiException('Incident not found'));
        return IncidentDetailCubit(mockClient);
      },
      act: (cubit) => cubit.load('inc-999'),
      expect: () => [
        isA<IncidentDetailLoading>(),
        isA<IncidentDetailError>().having(
          (s) => s.message,
          'message',
          'Incident not found',
        ),
      ],
    );

    blocTest<IncidentDetailCubit, IncidentDetailState>(
      'loaded state includes recommendations',
      build: () {
        when(
          () => mockClient.getIncident('inc-001'),
        ).thenAnswer((_) async => sampleDetail);
        return IncidentDetailCubit(mockClient);
      },
      act: (cubit) => cubit.load('inc-001'),
      expect: () => [
        isA<IncidentDetailLoading>(),
        isA<IncidentDetailLoaded>().having(
          (s) => s.detail.recommendations.length,
          'recommendations count',
          1,
        ),
      ],
    );

    blocTest<IncidentDetailCubit, IncidentDetailState>(
      'refresh reloads current incident',
      build: () {
        when(
          () => mockClient.getIncident('inc-001'),
        ).thenAnswer((_) async => sampleDetail);
        return IncidentDetailCubit(mockClient);
      },
      act: (cubit) async {
        await cubit.load('inc-001');
        await cubit.refresh();
      },
      skip: 2,
      expect: () => [isA<IncidentDetailLoading>(), isA<IncidentDetailLoaded>()],
      verify: (_) {
        verify(() => mockClient.getIncident('inc-001')).called(2);
      },
    );
  });
}
