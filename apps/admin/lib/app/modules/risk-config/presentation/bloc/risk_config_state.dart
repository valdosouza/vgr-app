import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/risk_tier_config_entity.dart';

sealed class RiskConfigState extends Equatable {
  const RiskConfigState();

  @override
  List<Object?> get props => [];
}

class RiskConfigLoading extends RiskConfigState {
  const RiskConfigLoading();
}

class RiskConfigLoaded extends RiskConfigState {
  const RiskConfigLoaded(this.items);

  final List<RiskTierConfigEntity> items;

  @override
  List<Object?> get props => [items];
}

/// The catalog could not be LOADED — translated by code (80/83), with a
/// retry. An action failure never lands here: it is [RiskConfigActionFailed].
class RiskConfigError extends RiskConfigState {
  const RiskConfigError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// One-shot (decision 221): an edit was refused — the page hands it to the
/// feedback bridge and keeps showing the list it had.
class RiskConfigActionFailed extends RiskConfigState {
  const RiskConfigActionFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// One-shot: an edit was saved.
class RiskConfigActionSucceeded extends RiskConfigState {
  const RiskConfigActionSucceeded();
}
