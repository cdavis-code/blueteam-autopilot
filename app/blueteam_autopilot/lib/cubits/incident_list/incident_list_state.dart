import 'package:equatable/equatable.dart';

import '../../api/models/incident_model.dart';

sealed class IncidentListState extends Equatable {
  const IncidentListState();

  @override
  List<Object?> get props => [];
}

class IncidentListInitial extends IncidentListState {
  const IncidentListInitial();
}

class IncidentListLoading extends IncidentListState {
  const IncidentListLoading();
}

class IncidentListLoaded extends IncidentListState {
  final List<IncidentModel> incidents;
  final String? severityFilter;
  final String? statusFilter;

  const IncidentListLoaded({
    required this.incidents,
    this.severityFilter,
    this.statusFilter,
  });

  @override
  List<Object?> get props => [incidents, severityFilter, statusFilter];

  IncidentListLoaded copyWith({
    List<IncidentModel>? incidents,
    String? severityFilter,
    String? statusFilter,
    bool clearSeverityFilter = false,
    bool clearStatusFilter = false,
  }) {
    return IncidentListLoaded(
      incidents: incidents ?? this.incidents,
      severityFilter: clearSeverityFilter
          ? null
          : (severityFilter ?? this.severityFilter),
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
    );
  }
}

class IncidentListError extends IncidentListState {
  final String message;

  const IncidentListError(this.message);

  @override
  List<Object?> get props => [message];
}
