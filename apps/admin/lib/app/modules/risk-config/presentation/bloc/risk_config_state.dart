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

class RiskConfigError extends RiskConfigState {
  const RiskConfigError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
