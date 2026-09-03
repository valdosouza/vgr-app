import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/report_stats_repository.dart';
import 'report_stats_event.dart';
import 'report_stats_state.dart';

/// Panel statistics (B4, decision 164): one aggregated read per request.
/// The page asks for the defaults on entry and for the form values on
/// Apply; every answer replaces the previous one — nothing is cached or
/// merged client-side, so the screen only ever shows what the server
/// summed and floored.
class ReportStatsBloc extends Bloc<ReportStatsEvent, ReportStatsState> {
  ReportStatsBloc(this._repository) : super(const ReportStatsInitial()) {
    on<ReportStatsRequested>(_onRequested);
  }

  final ReportStatsRepository _repository;

  Future<void> _onRequested(
    ReportStatsRequested event,
    Emitter<ReportStatsState> emit,
  ) async {
    emit(ReportStatsLoading(event.query));
    final result = await _repository.getStats(event.query);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ReportStatsError(failure, event.query)),
      (stats) => emit(ReportStatsLoaded(stats, event.query)),
    );
  }
}
