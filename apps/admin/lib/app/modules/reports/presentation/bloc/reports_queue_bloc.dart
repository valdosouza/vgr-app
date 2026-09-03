import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/reports_repository.dart';
import 'reports_queue_event.dart';
import 'reports_queue_state.dart';

/// Proactive moderation queue (B3, decision 161): open, not reviewed, not
/// hidden, not purged cases, ordered by the SERVER (tier → media → oldest).
/// Marking a case reviewed posts and then RE-FETCHES the current page —
/// a case leaves the queue only because the server no longer serves it.
/// Reading the queue is a list read and is not audited (166).
class ReportsQueueBloc extends Bloc<ReportsQueueEvent, ReportsQueueState> {
  ReportsQueueBloc(this._repository, {this.pageSize = 20})
      : super(const ReportsQueueInitial()) {
    on<ReportsQueueRequested>((event, emit) => _load(emit, 1));
    on<ReportsQueuePageRequested>((event, emit) => _load(emit, event.page));
    on<ReportsQueueMarkReviewed>(_onMark);
  }

  final ReportsRepository _repository;
  final int pageSize;
  int _page = 1;

  Future<void> _load(Emitter<ReportsQueueState> emit, int page) async {
    _page = page;
    emit(const ReportsQueueLoading());
    final result = await _repository.queue(page, pageSize);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ReportsQueueError(failure)),
      (loaded) => emit(ReportsQueueLoaded(loaded)),
    );
  }

  Future<void> _onMark(ReportsQueueMarkReviewed event, Emitter<ReportsQueueState> emit) async {
    final current = state;
    if (current is! ReportsQueueLoaded || current.busy) return;

    emit(current.copyWith(busy: true));
    final result = await _repository.markReviewed(event.reportId);
    if (emit.isDone) return;

    final next = await result.fold(
      (failure) async => current.copyWith(busy: false, failure: failure),
      (_) async {
        // Success: re-read the same page; the rows stay on screen meanwhile.
        final refreshed = await _repository.queue(_page, pageSize);
        return refreshed.fold(
          (failure) => current.copyWith(busy: false, failure: failure),
          (loaded) => ReportsQueueLoaded(loaded),
        );
      },
    );
    if (emit.isDone) return;
    emit(next);
  }
}
