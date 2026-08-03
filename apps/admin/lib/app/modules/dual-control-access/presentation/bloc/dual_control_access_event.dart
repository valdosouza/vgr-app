import 'package:equatable/equatable.dart';

sealed class DualControlAccessEvent extends Equatable {
  const DualControlAccessEvent();

  @override
  List<Object?> get props => [];
}

class RequestSubmitted extends DualControlAccessEvent {
  const RequestSubmitted({required this.accountabilityLogEntryId, required this.legalBasis});

  final int accountabilityLogEntryId;
  final String legalBasis;

  @override
  List<Object?> get props => [accountabilityLogEntryId, legalBasis];
}

class ApprovalSubmitted extends DualControlAccessEvent {
  const ApprovalSubmitted({required this.approverId});

  final String approverId;

  @override
  List<Object?> get props => [approverId];
}
