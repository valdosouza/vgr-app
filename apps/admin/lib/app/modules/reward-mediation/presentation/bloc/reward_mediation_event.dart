import 'package:equatable/equatable.dart';

sealed class RewardMediationEvent extends Equatable {
  const RewardMediationEvent();

  @override
  List<Object?> get props => [];
}

class MediationLookupRequested extends RewardMediationEvent {
  const MediationLookupRequested(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

class CriteriaPublishSubmitted extends RewardMediationEvent {
  const CriteriaPublishSubmitted(this.version, this.body);

  final String version;
  final String body;

  @override
  List<Object?> get props => [version, body];
}

class ResolutionProposed extends RewardMediationEvent {
  const ResolutionProposed(this.outcome, this.reason);

  final String outcome;
  final String reason;

  @override
  List<Object?> get props => [outcome, reason];
}

class ResolutionApproved extends RewardMediationEvent {
  const ResolutionApproved();
}

class ResolutionCancelled extends RewardMediationEvent {
  const ResolutionCancelled();
}

class ResolutionExecuted extends RewardMediationEvent {
  const ResolutionExecuted();
}

class ContestCloseSubmitted extends RewardMediationEvent {
  const ContestCloseSubmitted(this.contestId, this.note);

  final int contestId;
  final String note;

  @override
  List<Object?> get props => [contestId, note];
}
