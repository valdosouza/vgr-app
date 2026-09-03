import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/report_stats_entities.dart';

/// Contract of the panel statistics front, phase B4 (decisions 164/165):
/// ONE aggregated read behind the `report_stats` VIEW grant. Not audited —
/// aggregates are not evidence (165). Every count arrives floored at
/// k = 5 by the API; the panel never re-derives anything from them.
abstract class ReportStatsRepository {
  Future<Either<Failure, ReportStatsEntity>> getStats(ReportStatsQueryEntity query);
}
