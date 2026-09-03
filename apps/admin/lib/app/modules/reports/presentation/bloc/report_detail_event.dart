import 'package:equatable/equatable.dart';

sealed class ReportDetailEvent extends Equatable {
  const ReportDetailEvent();

  @override
  List<Object?> get props => [];
}

class ReportDetailRequested extends ReportDetailEvent {
  const ReportDetailRequested(this.reportId);

  final int reportId;

  @override
  List<Object?> get props => [reportId];
}

/// The ONE exact read (decision 159) — grant-gated and audited server-side.
class ReportExactPositionRequested extends ReportDetailEvent {
  const ReportExactPositionRequested();
}

class ReportFreezeSubmitted extends ReportDetailEvent {
  const ReportFreezeSubmitted(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

class ReportUnfreezeRequestSubmitted extends ReportDetailEvent {
  const ReportUnfreezeRequestSubmitted(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

class ReportUnfreezeApproveSubmitted extends ReportDetailEvent {
  const ReportUnfreezeApproveSubmitted();
}
