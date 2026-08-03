import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

sealed class RiskConfigEvent extends Equatable {
  const RiskConfigEvent();

  @override
  List<Object?> get props => [];
}

class FetchRequested extends RiskConfigEvent {
  const FetchRequested();
}

class TierEdited extends RiskConfigEvent {
  const TierEdited({required this.category, required this.tier});

  final String category;
  final RiskTier tier;

  @override
  List<Object?> get props => [category, tier];
}
