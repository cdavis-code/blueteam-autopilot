import 'package:equatable/equatable.dart';

sealed class ActionPanelState extends Equatable {
  const ActionPanelState();

  @override
  List<Object?> get props => [];
}

class ActionPanelInitial extends ActionPanelState {
  const ActionPanelInitial();
}

/// An operation is in progress (approve/reject/execute).
class ActionPanelOperating extends ActionPanelState {
  final String recommendationId;
  final String operation; // 'approve', 'reject', 'execute'

  const ActionPanelOperating({
    required this.recommendationId,
    required this.operation,
  });

  @override
  List<Object?> get props => [recommendationId, operation];
}

/// An operation completed successfully.
class ActionPanelSuccess extends ActionPanelState {
  final String recommendationId;
  final String newStatus;
  final String? executionLog;

  const ActionPanelSuccess({
    required this.recommendationId,
    required this.newStatus,
    this.executionLog,
  });

  @override
  List<Object?> get props => [recommendationId, newStatus, executionLog];
}

/// An operation failed.
class ActionPanelError extends ActionPanelState {
  final String recommendationId;
  final String message;

  const ActionPanelError({
    required this.recommendationId,
    required this.message,
  });

  @override
  List<Object?> get props => [recommendationId, message];
}
