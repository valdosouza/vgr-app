import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/system_module_entity.dart';
import '../domain/repository/system_module_repository.dart';

class SystemModuleRepositoryImpl implements SystemModuleRepository {
  SystemModuleRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<SystemModuleEntity>>> list(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/system-modules?${query.toQueryString()}');
      return Right(PagedResult.fromJson(json['data'] as Map<String, dynamic>, SystemModuleEntity.fromJson));
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
  Future<Either<Failure, SystemModuleEntity>> create(SystemModuleDraft draft) async {
    try {
      final json = await _apiClient.post('/api/system-modules', draft.toJson());
      return Right(SystemModuleEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, SystemModuleEntity>> update(SystemModuleEntity current, SystemModuleDraft draft) async {
    try {
      final json = await _apiClient.put('/api/system-modules/${current.id}', draft.toJson());
      return Right(SystemModuleEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(SystemModuleEntity item) async {
    try {
      await _apiClient.delete('/api/system-modules/${item.id}');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
