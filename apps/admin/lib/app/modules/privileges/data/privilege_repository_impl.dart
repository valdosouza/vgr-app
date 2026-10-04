import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/privilege_entity.dart';
import '../domain/repository/privilege_repository.dart';

class PrivilegeRepositoryImpl implements PrivilegeRepository {
  PrivilegeRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<PrivilegeEntity>>> list(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/privileges?${query.toQueryString()}');
      return Right(PagedResult.fromJson(json['data'] as Map<String, dynamic>, PrivilegeEntity.fromJson));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PrivilegeEntity>> create(PrivilegeDraft draft) async {
    try {
      final json = await _apiClient.post('/api/privileges', draft.toJson());
      return Right(PrivilegeEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PrivilegeEntity>> update(PrivilegeEntity current, PrivilegeDraft draft) async {
    try {
      final json = await _apiClient.put('/api/privileges/${current.id}', draft.toJson());
      return Right(PrivilegeEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(PrivilegeEntity item) async {
    try {
      await _apiClient.delete('/api/privileges/${item.id}');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
