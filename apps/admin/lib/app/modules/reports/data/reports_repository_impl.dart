import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/report_entities.dart';
import '../domain/repository/reports_repository.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, ReportPageEntity>> search(
    ReportFiltersEntity filters,
    int page,
    int pageSize,
  ) =>
      _guard(() async {
        // Path + query built by Uri so every value is encoded once.
        final uri = Uri(
          path: '/api/reports',
          queryParameters: {
            'page': '$page',
            'pageSize': '$pageSize',
            ...filters.toQueryParameters(),
          },
        );
        return ReportPageEntity.fromJson(await _apiClient.get(uri.toString()));
      });

  @override
  Future<Either<Failure, ReportPanelDetailEntity>> getDetail(int reportId) => _guard(
      () async => ReportPanelDetailEntity.fromJson(await _apiClient.get('/api/reports/$reportId')));

  @override
  Future<Either<Failure, ReportExactPositionEntity>> getExactPosition(int reportId) =>
      _guard(() async => ReportExactPositionEntity.fromJson(
          await _apiClient.get('/api/reports/$reportId/position')));

  // The four freeze calls mirror `case_freeze_repository_impl.dart` line
  // by line (decision 165): modules never import each other, and
  // duplicating four one-liners is the accepted cost.
  @override
  Future<Either<Failure, ReportFreezeStateEntity>> getFreezeState(int reportId) => _guard(
      () async => ReportFreezeStateEntity.fromJson(await _apiClient.get('/api/case-freeze/$reportId')));

  @override
  Future<Either<Failure, void>> freeze(int reportId, String reason) =>
      _guard(() => _apiClient.post('/api/case-freeze/$reportId/freeze', {'reason': reason}));

  @override
  Future<Either<Failure, void>> requestUnfreeze(int reportId, String reason) => _guard(
      () => _apiClient.post('/api/case-freeze/$reportId/unfreeze-request', {'reason': reason}));

  @override
  Future<Either<Failure, void>> approveUnfreeze(int reportId) =>
      _guard(() => _apiClient.post('/api/case-freeze/$reportId/unfreeze-approve', {}));
}
