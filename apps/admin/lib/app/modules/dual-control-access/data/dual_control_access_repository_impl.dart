import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/dual_control_request_entity.dart';
import '../domain/repository/dual_control_access_repository.dart';

class DualControlAccessRepositoryImpl implements DualControlAccessRepository {
  DualControlAccessRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<DualControlRequestEntity>>> list(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/dual-control-access?${query.toQueryString()}');
      return Right(PagedResult.fromJson(_data(json), DualControlRequestEntity.fromJson));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, DualControlRequestEntity>> request(DualControlRequestDraft draft) async {
    try {
      final json = await _apiClient.post('/api/dual-control-access', draft.toJson());
      return Right(DualControlRequestEntity.fromJson(_data(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, DualControlRequestEntity>> approve(int id) async {
    try {
      // No body: the approver is the session user (decision 223).
      final json = await _apiClient.post('/api/dual-control-access/$id/approvals', {});
      return Right(DualControlRequestEntity.fromJson(_data(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> json) => (json['data'] as Map).cast<String, dynamic>();
}
