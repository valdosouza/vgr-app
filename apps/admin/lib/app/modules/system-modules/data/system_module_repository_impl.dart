import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/system_module_entity.dart';
import '../domain/repository/system_module_repository.dart';

class SystemModuleRepositoryImpl implements SystemModuleRepository {
  SystemModuleRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<SystemModuleEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/system-modules');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(data.map((m) => SystemModuleEntity.fromJson(m as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, List<InterfaceOption>>> listInterfaceOptions() async {
    try {
      final json = await _apiClient.get('/api/interfaces');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(data.map((i) => InterfaceOption.fromJson(i as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, SystemModuleEntity>> create(SystemModuleEntity input) async {
    try {
      final json = await _apiClient.post('/api/system-modules', input.toJson());
      return Right(SystemModuleEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, SystemModuleEntity>> update(SystemModuleEntity input) async {
    try {
      final json = await _apiClient.put('/api/system-modules/${input.id}', input.toJson());
      return Right(SystemModuleEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(int id) async {
    try {
      await _apiClient.delete('/api/system-modules/$id');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
