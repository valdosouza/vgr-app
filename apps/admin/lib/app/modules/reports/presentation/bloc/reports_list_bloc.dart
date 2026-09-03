import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/report_entities.dart';
import '../../domain/repository/reports_repository.dart';
import 'reports_list_event.dart';
import 'reports_list_state.dart';

/// Panel report search (B1, decision 158): filters → page 1; prev/next
/// under the same filters. Nothing is fetched until the operator asks —
/// the list is not audited (166) but it is not free either.
class ReportsListBloc extends Bloc<ReportsListEvent, ReportsListState> {
  ReportsListBloc(this._repository, {this.pageSize = 20})
      : super(const ReportsListInitial()) {
    on<ReportsSearchRequested>((event, emit) => _load(emit, event.filters, 1));
    on<ReportsPageRequested>(_onPage);
  }

  final ReportsRepository _repository;
  final int pageSize;
  ReportFiltersEntity? _filters;

  Future<void> _onPage(ReportsPageRequested event, Emitter<ReportsListState> emit) async {
    final filters = _filters;
    if (filters == null) return;
    await _load(emit, filters, event.page);
  }

  Future<void> _load(
    Emitter<ReportsListState> emit,
    ReportFiltersEntity filters,
    int page,
  ) async {
    _filters = filters;
    emit(ReportsListLoading(filters));
    final result = await _repository.search(filters, page, pageSize);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ReportsListError(failure, filters)),
      (loaded) => emit(ReportsListLoaded(loaded, filters)),
    );
  }
}
