import 'package:equatable/equatable.dart';

import '../../domain/entity/dual_control_access_request_entity.dart';

sealed class DualControlAccessState extends Equatable {
  const DualControlAccessState();

  @override
  List<Object?> get props => [];
}

class DualControlInitial extends DualControlAccessState {
  const DualControlInitial();
}

class DualControlProgress extends DualControlAccessState {
  const DualControlProgress(this.entity);

  final DualControlAccessRequestEntity entity;

  @override
  List<Object?> get props => [entity];
}

/// One-shot — emitted only when [DualControlAccessRequestEntity.isGrantable]
/// turns true as a result of the approval just recorded (decision 45).
class DualControlActionSuccess extends DualControlAccessState {
  const DualControlActionSuccess(this.entity);

  final DualControlAccessRequestEntity entity;

  @override
  List<Object?> get props => [entity];
}

class DualControlError extends DualControlAccessState {
  const DualControlError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
