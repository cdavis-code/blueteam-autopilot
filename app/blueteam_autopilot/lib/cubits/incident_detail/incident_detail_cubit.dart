import 'package:flutter_bloc/flutter_bloc.dart';

import '../../api/backend_client.dart';
import 'incident_detail_state.dart';

class IncidentDetailCubit extends Cubit<IncidentDetailState> {
  final BackendClient _client;

  IncidentDetailCubit(this._client) : super(const IncidentDetailInitial());

  Future<void> load(String incidentId) async {
    emit(const IncidentDetailLoading());
    try {
      final detail = await _client.getIncident(incidentId);
      emit(IncidentDetailLoaded(detail: detail));
    } on ApiException catch (e) {
      emit(IncidentDetailError(e.message));
    } catch (e) {
      emit(IncidentDetailError(e.toString()));
    }
  }

  Future<void> refresh() async {
    final current = state;
    if (current is IncidentDetailLoaded) {
      await load(current.detail.incident.incidentId);
    }
  }
}
