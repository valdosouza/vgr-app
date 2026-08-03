import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../risk-config/domain/repository/risk_config_repository.dart';
import '../../domain/entity/fee_rule_entity.dart';
import '../../domain/repository/fee_rule_repository.dart';
import 'monetization_config_event.dart';
import 'monetization_config_state.dart';

class MonetizationConfigBloc extends Bloc<MonetizationConfigEvent, MonetizationConfigState> {
  MonetizationConfigBloc(this._feeRuleRepository, this._riskConfigRepository)
      : super(const MonetizationConfigLoading()) {
    on<FetchRequested>(_onFetchRequested);
    on<RuleEdited>(_onRuleEdited);
  }

  final FeeRuleRepository _feeRuleRepository;
  final RiskConfigRepository _riskConfigRepository;

  Future<void> _onFetchRequested(
    FetchRequested event,
    Emitter<MonetizationConfigState> emit,
  ) async {
    emit(const MonetizationConfigLoading());

    final rulesResult = await _feeRuleRepository.list();
    final riskTiersResult = await _riskConfigRepository.list();

    rulesResult.fold(
      (failure) => emit(MonetizationConfigError(failure.message)),
      (rules) => riskTiersResult.fold(
        (failure) => emit(MonetizationConfigError(failure.message)),
        (riskTiers) => emit(MonetizationConfigLoaded(
          rules,
          {for (final r in riskTiers) r.category: r.tier},
        )),
      ),
    );
  }

  /// Rejects the edit locally (no repository call) when it would allow
  /// peer_to_peer on a high-tier Category (decision 58) — mirrors the
  /// server-side constraint from `PaymentIntent` (API task 30).
  Future<void> _onRuleEdited(
    RuleEdited event,
    Emitter<MonetizationConfigState> emit,
  ) async {
    final current = state;
    if (current is! MonetizationConfigLoaded) return;

    if (event.category != null &&
        current.isHighTier(event.category!) &&
        event.paymentModeAllowed.contains(PaymentMode.peerToPeer)) {
      emit(const MonetizationConfigError(
        'High-tier Categories cannot allow peer_to_peer payment (decision 58)',
      ));
      return;
    }

    final result = await _feeRuleRepository.upsert(event.category, event.feePercent, event.paymentModeAllowed);
    result.fold(
      (failure) => emit(MonetizationConfigError(failure.message)),
      (_) {
        final updated = FeeRuleEntity(
          category: event.category,
          feePercent: event.feePercent,
          paymentModeAllowed: event.paymentModeAllowed,
        );
        final hadRule = current.rules.any((rule) => rule.category == event.category);
        final updatedRules = hadRule
            ? [for (final rule in current.rules) if (rule.category == event.category) updated else rule]
            : [...current.rules, updated];
        emit(MonetizationConfigLoaded(updatedRules, current.riskTiers));
      },
    );
  }
}
