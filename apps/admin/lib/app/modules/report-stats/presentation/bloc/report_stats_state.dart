import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entity/report_stats_entities.dart';

sealed class ReportStatsState extends Equatable {
  const ReportStatsState();

  @override
  List<Object?> get props => [];
}

/// Before the first read — the page dispatches the defaults on entry.
class ReportStatsInitial extends ReportStatsState {
  const ReportStatsInitial();
}

class ReportStatsLoading extends ReportStatsState {
  const ReportStatsLoading(this.query);

  final ReportStatsQueryEntity query;

  @override
  List<Object?> get props => [query];
}

class ReportStatsLoaded extends ReportStatsState {
  const ReportStatsLoaded(this.stats, this.query);

  final ReportStatsEntity stats;
  final ReportStatsQueryEntity query;

  @override
  List<Object?> get props => [stats, query];
}

/// The read failed (422 on a bad range, 403 without the grant, network).
class ReportStatsError extends ReportStatsState {
  const ReportStatsError(this.failure, this.query);

  final Failure failure;
  final ReportStatsQueryEntity query;

  @override
  List<Object?> get props => [failure, query];
}
