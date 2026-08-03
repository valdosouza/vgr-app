import 'package:equatable/equatable.dart';

enum PaymentMode { intermediated, peerToPeer }

extension PaymentModeJson on PaymentMode {
  static PaymentMode fromJson(String value) => value == 'peer_to_peer' ? PaymentMode.peerToPeer : PaymentMode.intermediated;
  String toJson() => this == PaymentMode.peerToPeer ? 'peer_to_peer' : 'intermediated';
}

class FeeRuleEntity extends Equatable {
  const FeeRuleEntity({
    required this.category,
    required this.feePercent,
    required this.paymentModeAllowed,
  });

  /// `null` = global default (decision 39).
  final String? category;
  final double feePercent;
  final Set<PaymentMode> paymentModeAllowed;

  @override
  List<Object?> get props => [category, feePercent, paymentModeAllowed];
}
