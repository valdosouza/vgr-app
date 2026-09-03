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

/// Moderation acts (B2, decisions 162/163): a catalog [reasonCode] plus
/// an optional [note] (mandatory when `other`). Same shape for hide and
/// its reversal — reverting is audited exactly like the act (162).
class ReportHideSubmitted extends ReportDetailEvent {
  const ReportHideSubmitted(this.reasonCode, this.note);

  final String reasonCode;
  final String? note;

  @override
  List<Object?> get props => [reasonCode, note];
}

class ReportUnhideSubmitted extends ReportDetailEvent {
  const ReportUnhideSubmitted(this.reasonCode, this.note);

  final String reasonCode;
  final String? note;

  @override
  List<Object?> get props => [reasonCode, note];
}

class ReportMediaBlockSubmitted extends ReportDetailEvent {
  const ReportMediaBlockSubmitted(this.publicId, this.reasonCode, this.note);

  final String publicId;
  final String reasonCode;
  final String? note;

  @override
  List<Object?> get props => [publicId, reasonCode, note];
}

/// Review mark (B3, decision 161): ONE human, no reason, audited
/// server-side. Not a moderation act — nothing on the case changes but
/// `reviewedAt/By`.
class ReportMarkReviewedSubmitted extends ReportDetailEvent {
  const ReportMarkReviewedSubmitted();
}

class ReportMediaUnblockSubmitted extends ReportDetailEvent {
  const ReportMediaUnblockSubmitted(this.publicId, this.reasonCode, this.note);

  final String publicId;
  final String reasonCode;
  final String? note;

  @override
  List<Object?> get props => [publicId, reasonCode, note];
}
