import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/fee_rule_entity.dart';

sealed class MonetizationConfigState extends Equatable {
  const MonetizationConfigState();

  @override
  List<Object?> get props => [];
}

class MonetizationConfigLoading extends MonetizationConfigState {
  const MonetizationConfigLoading();
}

class MonetizationConfigLoaded extends MonetizationConfigState {
  const MonetizationConfigLoaded(this.rules, this.riskTiers);

  final List<FeeRuleEntity> rules;

  /// Category -> RiskTier, from `RiskConfigRepository` — read-only, used
  /// to enforce "high-tier Categories can't allow peer_to_peer" (decision
  /// 58) here in the admin app, since the API deliberately doesn't (see
  /// `D:\ProjetoVGR\api\docs\feature\monetization-config.md`).
  final Map<String, RiskTier> riskTiers;

  bool isHighTier(String category) => riskTiers[category] == RiskTier.high;

  @override
  List<Object?> get props => [rules, riskTiers];
}

class MonetizationConfigError extends MonetizationConfigState {
  const MonetizationConfigError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
