import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:blueteam_autopilot/api/backend_client.dart';
import 'package:blueteam_autopilot/api/models/incident_model.dart';
import 'package:blueteam_autopilot/cubits/incident_list/incident_list_cubit.dart';
import 'package:blueteam_autopilot/cubits/incident_list/incident_list_state.dart';

class MockBackendClient extends Mock implements BackendClient {}

void main() {
  late MockBackendClient mockClient;

  setUp(() {
    mockClient = MockBackendClient();
  });

  final sampleIncidents = [
    IncidentModel(
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
    IncidentModel(
      incidentId: 'inc-002',
      accountId: 'acc-001',
      status: 'RESOLVED',
      createdAt: 1718107200000,
      updatedAt: 1718107200000,
      report: IncidentReportModel(
        eventId: 'evt-002',
        title: 'Port Scan',
        severity: 'LOW',
        aiSummary: '',
        rootCause: '',
        businessImpact: '',
        attackChain: [],
        affectedAssets: [],
        sourceIps: [],
        relatedCves: [],
        complianceControls: [],
      ),
    ),
  ];

  group('IncidentListCubit', () {
    test('initial state is IncidentListInitial', () {
      final cubit = IncidentListCubit(mockClient);
      expect(cubit.state, isA<IncidentListInitial>());
      cubit.close();
    });

    blocTest<IncidentListCubit, IncidentListState>(
      'load emits [Loading, Loaded] on success',
      build: () {
        when(
          () => mockClient.listIncidents(
            severity: any(named: 'severity'),
            status: any(named: 'status'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => sampleIncidents);
        return IncidentListCubit(mockClient);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<IncidentListLoading>(),
        isA<IncidentListLoaded>().having(
          (s) => s.incidents.length,
          'incidents count',
          2,
        ),
      ],
    );

    blocTest<IncidentListCubit, IncidentListState>(
      'load emits [Loading, Error] on failure',
      build: () {
        when(
          () => mockClient.listIncidents(
            severity: any(named: 'severity'),
            status: any(named: 'status'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const ApiException('Network error'));
        return IncidentListCubit(mockClient);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<IncidentListLoading>(),
        isA<IncidentListError>().having(
          (s) => s.message,
          'message',
          'Network error',
        ),
      ],
    );

    blocTest<IncidentListCubit, IncidentListState>(
      'load with severity filter passes filter to client',
      build: () {
        when(
          () => mockClient.listIncidents(
            severity: any(named: 'severity'),
            status: any(named: 'status'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [sampleIncidents.first]);
        return IncidentListCubit(mockClient);
      },
      act: (cubit) => cubit.load(severity: 'HIGH'),
      verify: (_) {
        verify(
          () => mockClient.listIncidents(severity: 'HIGH', status: null),
        ).called(1);
      },
      expect: () => [
        isA<IncidentListLoading>(),
        isA<IncidentListLoaded>().having(
          (s) => s.severityFilter,
          'severityFilter',
          'HIGH',
        ),
      ],
    );

    blocTest<IncidentListCubit, IncidentListState>(
      'setSeverityFilter reloads with filter',
      build: () {
        when(
          () => mockClient.listIncidents(
            severity: any(named: 'severity'),
            status: any(named: 'status'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => sampleIncidents);
        return IncidentListCubit(mockClient);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.setSeverityFilter('CRITICAL');
      },
      skip: 2, // skip initial load
      expect: () => [
        isA<IncidentListLoading>(),
        isA<IncidentListLoaded>().having(
          (s) => s.severityFilter,
          'severityFilter',
          'CRITICAL',
        ),
      ],
    );

    blocTest<IncidentListCubit, IncidentListState>(
      'refresh preserves current filters',
      build: () {
        when(
          () => mockClient.listIncidents(
            severity: any(named: 'severity'),
            status: any(named: 'status'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => sampleIncidents);
        return IncidentListCubit(mockClient);
      },
      act: (cubit) async {
        await cubit.load(severity: 'HIGH', status: 'OPEN');
        await cubit.refresh();
      },
      skip: 2,
      expect: () => [
        isA<IncidentListLoading>(),
        isA<IncidentListLoaded>()
            .having((s) => s.severityFilter, 'severity', 'HIGH')
            .having((s) => s.statusFilter, 'status', 'OPEN'),
      ],
    );
  });
}
