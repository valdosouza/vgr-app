import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/interface_entity.dart';
import '../domain/repository/interface_repository.dart';

class InterfaceRepositoryImpl implements InterfaceRepository {
  InterfaceRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<InterfaceEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/interfaces');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(data.map((i) => InterfaceEntity.fromJson(i as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, List<PrivilegeOption>>> listPrivilegeOptions() async {
    try {
      final json = await _apiClient.get('/api/privileges');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(data.map((p) => PrivilegeOption.fromJson(p as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, InterfaceEntity>> create(InterfaceEntity input) async {
    try {
      final json = await _apiClient.post('/api/interfaces', input.toJson());
      return Right(InterfaceEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, InterfaceEntity>> update(InterfaceEntity input) async {
    try {
      final json = await _apiClient.put('/api/interfaces/${input.id}', input.toJson());
      return Right(InterfaceEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(int id) async {
    try {
      await _apiClient.delete('/api/interfaces/$id');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
