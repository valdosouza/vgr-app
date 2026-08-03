import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

class RiskTierConfigEntity extends Equatable {
  const RiskTierConfigEntity({required this.category, required this.tier});

  final String category;
  final RiskTier tier;

  @override
  List<Object?> get props => [category, tier];
}
