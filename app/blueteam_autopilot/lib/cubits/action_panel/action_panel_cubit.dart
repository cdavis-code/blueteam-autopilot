import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/backend_client.dart';
import 'action_panel_state.dart';

class ActionPanelCubit extends Cubit<ActionPanelState> {
  final BackendClient _client;

  ActionPanelCubit(this._client) : super(const ActionPanelInitial());

  Future<void> approve(String incidentId, String recId) async {
    emit(ActionPanelOperating(recommendationId: recId, operation: 'approve'));
    try {
      await _client.approveRecommendation(incidentId, recId);
      emit(ActionPanelSuccess(recommendationId: recId, newStatus: 'APPROVED'));
    } on ApiException catch (e) {
      emit(ActionPanelError(recommendationId: recId, message: e.message));
    } catch (e) {
      emit(ActionPanelError(recommendationId: recId, message: e.toString()));
    }
  }

  Future<void> reject(String incidentId, String recId) async {
    emit(ActionPanelOperating(recommendationId: recId, operation: 'reject'));
    try {
      await _client.rejectRecommendation(incidentId, recId);
      emit(ActionPanelSuccess(recommendationId: recId, newStatus: 'REJECTED'));
    } on ApiException catch (e) {
      emit(ActionPanelError(recommendationId: recId, message: e.message));
    } catch (e) {
      emit(ActionPanelError(recommendationId: recId, message: e.toString()));
    }
  }

  Future<void> execute(
    String incidentId,
    String recId, {
    bool dryRun = false,
  }) async {
    emit(ActionPanelOperating(recommendationId: recId, operation: 'execute'));
    try {
      final result = await _client.executeRecommendation(
        incidentId,
        recId,
        dryRun: dryRun,
      );
      emit(
        ActionPanelSuccess(
          recommendationId: recId,
          newStatus: result.status,
          executionLog: result.log,
        ),
      );
    } on ApiException catch (e) {
      emit(ActionPanelError(recommendationId: recId, message: e.message));
    } catch (e) {
      emit(ActionPanelError(recommendationId: recId, message: e.toString()));
    }
  }
}
