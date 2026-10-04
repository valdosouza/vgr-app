import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/interface_entity.dart';
import '../domain/repository/interface_repository.dart';

class InterfaceRepositoryImpl implements InterfaceRepository {
  InterfaceRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<InterfaceEntity>>> list(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/interfaces?${query.toQueryString()}');
      return Right(PagedResult.fromJson(json['data'] as Map<String, dynamic>, InterfaceEntity.fromJson));
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
  Future<Either<Failure, InterfaceEntity>> create(InterfaceDraft draft) async {
    try {
      final json = await _apiClient.post('/api/interfaces', draft.toJson());
      return Right(InterfaceEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, InterfaceEntity>> update(InterfaceEntity current, InterfaceDraft draft) async {
    try {
      final json = await _apiClient.put('/api/interfaces/${current.id}', draft.toJson());
      return Right(InterfaceEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(InterfaceEntity item) async {
    try {
      await _apiClient.delete('/api/interfaces/${item.id}');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
