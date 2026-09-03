import 'package:equatable/equatable.dart';

import '../../domain/entity/report_entities.dart';

sealed class ReportsListEvent extends Equatable {
  const ReportsListEvent();

  @override
  List<Object?> get props => [];
}

/// New filters → back to page 1.
class ReportsSearchRequested extends ReportsListEvent {
  const ReportsSearchRequested(this.filters);

  final ReportFiltersEntity filters;

  @override
  List<Object?> get props => [filters];
}

/// Prev/next under the CURRENT filters.
class ReportsPageRequested extends ReportsListEvent {
  const ReportsPageRequested(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}
