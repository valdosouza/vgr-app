import 'package:equatable/equatable.dart';

import '../../domain/entity/fee_rule_entity.dart';

sealed class MonetizationConfigEvent extends Equatable {
  const MonetizationConfigEvent();

  @override
  List<Object?> get props => [];
}

class FetchRequested extends MonetizationConfigEvent {
  const FetchRequested();
}

class RuleEdited extends MonetizationConfigEvent {
  const RuleEdited({required this.category, required this.feePercent, required this.paymentModeAllowed});

  final String? category;
  final double feePercent;
  final Set<PaymentMode> paymentModeAllowed;

  @override
  List<Object?> get props => [category, feePercent, paymentModeAllowed];
}
