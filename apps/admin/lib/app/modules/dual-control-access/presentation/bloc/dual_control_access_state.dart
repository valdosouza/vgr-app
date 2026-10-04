import 'package:core/core.dart';
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

/// One-shot (decision 221): the request or the approval was refused — the
/// page hands it to the feedback bridge, and the bloc returns to the state
/// it was in (a refused approval no longer drops the request in progress).
class DualControlActionFailed extends DualControlAccessState {
  const DualControlActionFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
