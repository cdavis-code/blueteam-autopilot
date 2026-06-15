import 'package:equatable/equatable.dart';

import '../../api/backend_client.dart';

sealed class IncidentDetailState extends Equatable {
  const IncidentDetailState();

  @override
  List<Object?> get props => [];
}

class IncidentDetailInitial extends IncidentDetailState {
  const IncidentDetailInitial();
}

class IncidentDetailLoading extends IncidentDetailState {
  const IncidentDetailLoading();
}

class IncidentDetailLoaded extends IncidentDetailState {
  final IncidentDetailModel detail;

  const IncidentDetailLoaded({required this.detail});

  @override
  List<Object?> get props => [
    detail.incident.incidentId,
    detail.recommendations.length,
  ];

  IncidentDetailLoaded copyWith({IncidentDetailModel? detail}) {
    return IncidentDetailLoaded(detail: detail ?? this.detail);
  }
}

class IncidentDetailError extends IncidentDetailState {
  final String message;

  const IncidentDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
