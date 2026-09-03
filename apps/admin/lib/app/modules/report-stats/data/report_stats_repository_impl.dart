import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/report_stats_entities.dart';
import '../domain/repository/report_stats_repository.dart';

class ReportStatsRepositoryImpl implements ReportStatsRepository {
  ReportStatsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  /// `GET /api/reports/stats?from&to&granularity` (B4, decision 164).
  /// Path + query built by Uri so every value is encoded once; unset
  /// filters are simply absent and the API applies its own defaults.
  @override
  Future<Either<Failure, ReportStatsEntity>> getStats(ReportStatsQueryEntity query) async {
    try {
      final params = query.toQueryParameters();
      final uri = Uri(
        path: '/api/reports/stats',
        queryParameters: params.isEmpty ? null : params,
      );
      return Right(ReportStatsEntity.fromJson(await _apiClient.get(uri.toString())));
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
