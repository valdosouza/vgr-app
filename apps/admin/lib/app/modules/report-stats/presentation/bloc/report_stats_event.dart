import 'package:equatable/equatable.dart';

import '../../domain/entity/report_stats_entities.dart';

sealed class ReportStatsEvent extends Equatable {
  const ReportStatsEvent();

  @override
  List<Object?> get props => [];
}

/// Read the aggregates under [query] — the page sends the defaults on
/// entry and the form values on Apply.
class ReportStatsRequested extends ReportStatsEvent {
  const ReportStatsRequested(this.query);

  final ReportStatsQueryEntity query;

  @override
  List<Object?> get props => [query];
}
