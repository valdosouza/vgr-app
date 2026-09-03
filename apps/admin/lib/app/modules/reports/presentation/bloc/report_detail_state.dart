import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/report_entities.dart';

sealed class ReportDetailState extends Equatable {
  const ReportDetailState();

  @override
  List<Object?> get props => [];
}

class ReportDetailInitial extends ReportDetailState {
  const ReportDetailInitial();
}

class ReportDetailLoading extends ReportDetailState {
  const ReportDetailLoading();
}

/// The case is on screen. [freeze] is `null` when `/api/case-freeze`
/// refused (no `case_freeze` grant) — the detail still renders. [busy]
/// while a mutation is in flight; [failure] carries the last action error
/// without losing the case; [exactPosition] only after an audited reveal.
class ReportDetailLoaded extends ReportDetailState {
  const ReportDetailLoaded(
    this.detail, {
    required this.freeze,
    this.busy = false,
    this.failure,
    this.exactPosition,
  });

  final ReportPanelDetailEntity detail;
  final ReportFreezeStateEntity? freeze;
  final bool busy;
  final Failure? failure;
  final ReportExactPositionEntity? exactPosition;

  ReportDetailLoaded copyWith({
    bool? busy,
    Failure? failure,
    ReportExactPositionEntity? exactPosition,
  }) =>
      ReportDetailLoaded(
        detail,
        freeze: freeze,
        busy: busy ?? this.busy,
        failure: failure,
        exactPosition: exactPosition ?? this.exactPosition,
      );

  @override
  List<Object?> get props => [detail, freeze, busy, failure, exactPosition];
}

/// The detail itself failed (404, no grant).
class ReportDetailError extends ReportDetailState {
  const ReportDetailError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
