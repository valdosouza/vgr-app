import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/risk_tier_config_entity.dart';
import '../../domain/repository/risk_config_repository.dart';
import 'risk_config_event.dart';
import 'risk_config_state.dart';

class RiskConfigBloc extends Bloc<RiskConfigEvent, RiskConfigState> {
  RiskConfigBloc(this._repository) : super(const RiskConfigLoading()) {
    on<FetchRequested>(_onFetchRequested);
    on<TierEdited>(_onTierEdited);
  }

  final RiskConfigRepository _repository;

  Future<void> _onFetchRequested(
    FetchRequested event,
    Emitter<RiskConfigState> emit,
  ) async {
    emit(const RiskConfigLoading());
    final result = await _repository.list();
    result.fold(
      (failure) => emit(RiskConfigError(failure.message)),
      (items) => emit(RiskConfigLoaded(items)),
    );
  }

  /// Updates the row directly instead of re-fetching the whole list —
  /// this is what "persists without a page reload" means (task 03).
  Future<void> _onTierEdited(
    TierEdited event,
    Emitter<RiskConfigState> emit,
  ) async {
    final result = await _repository.upsert(event.category, event.tier);
    result.fold(
      (failure) => emit(RiskConfigError(failure.message)),
      (_) {
        final current = state;
        if (current is RiskConfigLoaded) {
          final updated = [
            for (final item in current.items)
              if (item.category == event.category)
                RiskTierConfigEntity(category: item.category, tier: event.tier)
              else
                item,
          ];
          emit(RiskConfigLoaded(updated));
        }
      },
    );
  }
}
