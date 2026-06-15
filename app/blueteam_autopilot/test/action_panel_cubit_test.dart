import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:blueteam_autopilot/api/backend_client.dart';
import 'package:blueteam_autopilot/api/models/recommendation_model.dart';
import 'package:blueteam_autopilot/cubits/action_panel/action_panel_cubit.dart';
import 'package:blueteam_autopilot/cubits/action_panel/action_panel_state.dart';

class MockBackendClient extends Mock implements BackendClient {}

void main() {
  late MockBackendClient mockClient;

  setUp(() {
    mockClient = MockBackendClient();
  });

  group('ActionPanelCubit', () {
    test('initial state is ActionPanelInitial', () {
      final cubit = ActionPanelCubit(mockClient);
      expect(cubit.state, isA<ActionPanelInitial>());
      cubit.close();
    });

    // -----------------------------------------------------------------------
    // Approve
    // -----------------------------------------------------------------------
    blocTest<ActionPanelCubit, ActionPanelState>(
      'approve emits [Operating, Success(APPROVED)]',
      build: () {
        when(
          () => mockClient.approveRecommendation('inc-001', 'rec-001'),
        ).thenAnswer((_) async {});
        return ActionPanelCubit(mockClient);
      },
      act: (cubit) => cubit.approve('inc-001', 'rec-001'),
      expect: () => [
        isA<ActionPanelOperating>()
            .having((s) => s.operation, 'op', 'approve')
            .having((s) => s.recommendationId, 'recId', 'rec-001'),
        isA<ActionPanelSuccess>()
            .having((s) => s.newStatus, 'status', 'APPROVED')
            .having((s) => s.recommendationId, 'recId', 'rec-001'),
      ],
    );

    blocTest<ActionPanelCubit, ActionPanelState>(
      'approve emits [Operating, Error] on failure',
      build: () {
        when(
          () => mockClient.approveRecommendation('inc-001', 'rec-001'),
        ).thenThrow(const ApiException('Already approved'));
        return ActionPanelCubit(mockClient);
      },
      act: (cubit) => cubit.approve('inc-001', 'rec-001'),
      expect: () => [
        isA<ActionPanelOperating>(),
        isA<ActionPanelError>().having(
          (s) => s.message,
          'message',
          'Already approved',
        ),
      ],
    );

    // -----------------------------------------------------------------------
    // Reject
    // -----------------------------------------------------------------------
    blocTest<ActionPanelCubit, ActionPanelState>(
      'reject emits [Operating, Success(REJECTED)]',
      build: () {
        when(
          () => mockClient.rejectRecommendation('inc-001', 'rec-001'),
        ).thenAnswer((_) async {});
        return ActionPanelCubit(mockClient);
      },
      act: (cubit) => cubit.reject('inc-001', 'rec-001'),
      expect: () => [
        isA<ActionPanelOperating>().having((s) => s.operation, 'op', 'reject'),
        isA<ActionPanelSuccess>().having(
          (s) => s.newStatus,
          'status',
          'REJECTED',
        ),
      ],
    );

    // -----------------------------------------------------------------------
    // Execute
    // -----------------------------------------------------------------------
    blocTest<ActionPanelCubit, ActionPanelState>(
      'execute emits [Operating, Success(APPLIED)] with log',
      build: () {
        when(
          () => mockClient.executeRecommendation(
            'inc-001',
            'rec-001',
            dryRun: false,
          ),
        ).thenAnswer(
          (_) async => const ExecutionResultModel(
            recommendationId: 'rec-001',
            status: 'APPLIED',
            log: 'IP 1.2.3.4 blocked successfully.',
          ),
        );
        return ActionPanelCubit(mockClient);
      },
      act: (cubit) => cubit.execute('inc-001', 'rec-001'),
      expect: () => [
        isA<ActionPanelOperating>().having((s) => s.operation, 'op', 'execute'),
        isA<ActionPanelSuccess>()
            .having((s) => s.newStatus, 'status', 'APPLIED')
            .having((s) => s.executionLog, 'log', isNotNull),
      ],
    );

    blocTest<ActionPanelCubit, ActionPanelState>(
      'execute with dryRun passes dryRun=true to client',
      build: () {
        when(
          () => mockClient.executeRecommendation(
            'inc-001',
            'rec-001',
            dryRun: true,
          ),
        ).thenAnswer(
          (_) async => const ExecutionResultModel(
            recommendationId: 'rec-001',
            status: 'DRY_RUN_OK',
            log: 'Dry run succeeded.',
          ),
        );
        return ActionPanelCubit(mockClient);
      },
      act: (cubit) => cubit.execute('inc-001', 'rec-001', dryRun: true),
      verify: (_) {
        verify(
          () => mockClient.executeRecommendation(
            'inc-001',
            'rec-001',
            dryRun: true,
          ),
        ).called(1);
      },
      expect: () => [
        isA<ActionPanelOperating>(),
        isA<ActionPanelSuccess>().having(
          (s) => s.newStatus,
          'status',
          'DRY_RUN_OK',
        ),
      ],
    );

    blocTest<ActionPanelCubit, ActionPanelState>(
      'execute emits [Operating, Error] when not approved',
      build: () {
        when(
          () => mockClient.executeRecommendation(
            'inc-001',
            'rec-001',
            dryRun: false,
          ),
        ).thenThrow(const ApiException('Not approved yet'));
        return ActionPanelCubit(mockClient);
      },
      act: (cubit) => cubit.execute('inc-001', 'rec-001'),
      expect: () => [
        isA<ActionPanelOperating>(),
        isA<ActionPanelError>().having(
          (s) => s.message,
          'message',
          'Not approved yet',
        ),
      ],
    );
  });
}
