import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/backend_client.dart';
import 'incident_list_state.dart';

class IncidentListCubit extends Cubit<IncidentListState> {
  final BackendClient _client;

  IncidentListCubit(this._client) : super(const IncidentListInitial());

  /// Load incidents, optionally filtered.
  Future<void> load({String? severity, String? status}) async {
    emit(const IncidentListLoading());
    try {
      final incidents = await _client.listIncidents(
        severity: severity,
        status: status,
      );
      emit(
        IncidentListLoaded(
          incidents: incidents,
          severityFilter: severity,
          statusFilter: status,
        ),
      );
    } on ApiException catch (e) {
      emit(IncidentListError(e.message));
    } catch (e) {
      emit(IncidentListError(e.toString()));
    }
  }

  /// Re-fetch with current filters (pull-to-refresh).
  Future<void> refresh() async {
    final current = state;
    if (current is IncidentListLoaded) {
      await load(
        severity: current.severityFilter,
        status: current.statusFilter,
      );
    } else {
      await load();
    }
  }

  /// Update severity filter and reload.
  Future<void> setSeverityFilter(String? severity) async {
    final current = state;
    final statusFilter = current is IncidentListLoaded
        ? current.statusFilter
        : null;
    await load(severity: severity, status: statusFilter);
  }

  /// Update status filter and reload.
  Future<void> setStatusFilter(String? status) async {
    final current = state;
    final severityFilter = current is IncidentListLoaded
        ? current.severityFilter
        : null;
    await load(severity: severityFilter, status: status);
  }
}
