import 'package:equatable/equatable.dart';

sealed class CaseFreezeEvent extends Equatable {
  const CaseFreezeEvent();

  @override
  List<Object?> get props => [];
}

class CaseLookupRequested extends CaseFreezeEvent {
  const CaseLookupRequested(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

class CaseFreezeSubmitted extends CaseFreezeEvent {
  const CaseFreezeSubmitted(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

class UnfreezeRequestSubmitted extends CaseFreezeEvent {
  const UnfreezeRequestSubmitted(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

class UnfreezeApproveSubmitted extends CaseFreezeEvent {
  const UnfreezeApproveSubmitted();
}
