import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/report_entities.dart';

sealed class ReportsListState extends Equatable {
  const ReportsListState();

  @override
  List<Object?> get props => [];
}

/// Filter bar only — nothing searched yet.
class ReportsListInitial extends ReportsListState {
  const ReportsListInitial();
}

class ReportsListLoading extends ReportsListState {
  const ReportsListLoading(this.filters);

  final ReportFiltersEntity filters;

  @override
  List<Object?> get props => [filters];
}

class ReportsListLoaded extends ReportsListState {
  const ReportsListLoaded(this.page, this.filters);

  final ReportPageEntity page;
  final ReportFiltersEntity filters;

  @override
  List<Object?> get props => [page, filters];
}

/// The search itself failed (422 on a bad filter, no grant, network).
class ReportsListError extends ReportsListState {
  const ReportsListError(this.failure, this.filters);

  final Failure failure;
  final ReportFiltersEntity filters;

  @override
  List<Object?> get props => [failure, filters];
}
