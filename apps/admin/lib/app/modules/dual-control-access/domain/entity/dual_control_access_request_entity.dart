import 'package:equatable/equatable.dart';

class DualControlAccessRequestEntity extends Equatable {
  const DualControlAccessRequestEntity({
    required this.id,
    required this.legalBasis,
    required this.approverIds,
  });

  final String id;
  final String legalBasis;
  final List<String> approverIds;

  /// Only true once 2 DISTINCT approverIds are recorded (decision 45).
  bool get isGrantable => approverIds.toSet().length >= 2 && legalBasis.isNotEmpty;

  @override
  List<Object?> get props => [id, legalBasis, approverIds];
}
