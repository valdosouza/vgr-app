import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/reports_repository.dart';
import 'report_detail_event.dart';
import 'report_detail_state.dart';

/// Case detail on the panel plane (B1, decisions 159/160/165/166): loads
/// the detail (audited server-side) together with the embedded freeze
/// state; after every freeze action BOTH are re-fetched — the server is
/// the only authority on what the case is. The exact position is a
/// separate, grant-gated, audited read that never comes with the detail.
class ReportDetailBloc extends Bloc<ReportDetailEvent, ReportDetailState> {
  ReportDetailBloc(this._repository) : super(const ReportDetailInitial()) {
    on<ReportDetailRequested>(_onLoad);
    on<ReportExactPositionRequested>(_onReveal);
    on<ReportFreezeSubmitted>(
        (event, emit) => _mutate(emit, (id) => _repository.freeze(id, event.reason)));
    on<ReportUnfreezeRequestSubmitted>(
        (event, emit) => _mutate(emit, (id) => _repository.requestUnfreeze(id, event.reason)));
    on<ReportUnfreezeApproveSubmitted>(
        (event, emit) => _mutate(emit, _repository.approveUnfreeze));
  }

  final ReportsRepository _repository;
  int? _reportId;

  Future<void> _onLoad(ReportDetailRequested event, Emitter<ReportDetailState> emit) async {
    emit(const ReportDetailLoading());
    _reportId = event.reportId;
    final loaded = await _fetch(event.reportId);
    if (emit.isDone) return;
    emit(loaded);
  }

  /// Detail + freeze state. A refused freeze state (no `case_freeze`
  /// grant) is not an error: the detail renders with `freeze == null`.
  Future<ReportDetailState> _fetch(int reportId) async {
    final detail = await _repository.getDetail(reportId);
    return detail.fold(
      (failure) async => ReportDetailError(failure),
      (entity) async {
        final freeze = await _repository.getFreezeState(reportId);
        return ReportDetailLoaded(entity, freeze: freeze.fold((_) => null, (f) => f));
      },
    );
  }

  Future<void> _onReveal(
    ReportExactPositionRequested event,
    Emitter<ReportDetailState> emit,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! ReportDetailLoaded || current.busy || reportId == null) return;

    emit(current.copyWith(busy: true));
    final result = await _repository.getExactPosition(reportId);
    if (emit.isDone) return;
    emit(result.fold(
      (failure) => current.copyWith(busy: false, failure: failure),
      (position) => current.copyWith(busy: false, exactPosition: position),
    ));
  }

  Future<void> _mutate(
    Emitter<ReportDetailState> emit,
    Future<Either<Failure, void>> Function(int reportId) action,
  ) async {
    final current = state;
    final reportId = _reportId;
    if (current is! ReportDetailLoaded || current.busy || reportId == null) return;

    emit(current.copyWith(busy: true));
    final result = await action(reportId);
    if (emit.isDone) return;

    final next = await result.fold(
      (failure) async => current.copyWith(busy: false, failure: failure),
      (_) async {
        // Success: re-read everything; the exact position (if revealed)
        // is dropped on purpose — a new reveal is a new audited read.
        final refreshed = await _fetch(reportId);
        return refreshed is ReportDetailError
            ? current.copyWith(busy: false, failure: refreshed.failure)
            : refreshed;
      },
    );
    if (emit.isDone) return;
    emit(next);
  }
}
