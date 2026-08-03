import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/privilege_entity.dart';
import '../domain/repository/privilege_repository.dart';

class PrivilegeRepositoryImpl implements PrivilegeRepository {
  PrivilegeRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<PrivilegeEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/privileges');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(data.map((p) => PrivilegeEntity.fromJson(p as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PrivilegeEntity>> create(String description) async {
    try {
      final json = await _apiClient.post('/api/privileges', {'description': description});
      return Right(PrivilegeEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PrivilegeEntity>> update(int id, String description) async {
    try {
      final json = await _apiClient.put('/api/privileges/$id', {'description': description});
      return Right(PrivilegeEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(int id) async {
    try {
      await _apiClient.delete('/api/privileges/$id');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
