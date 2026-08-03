import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/user_entity.dart';
import '../domain/repository/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<UserEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/users');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(data.map((u) => UserEntity.fromJson(u as Map<String, dynamic>)).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, UserEntity>> create({
    required String name,
    required String email,
    required String active,
    required String password,
  }) async {
    try {
      final json = await _apiClient.post('/api/users', {
        'name': name,
        'email': email,
        'active': active,
        'password': password,
      });
      return Right(UserEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, UserEntity>> update({
    required int id,
    required String name,
    required String email,
    required String active,
    String? password,
  }) async {
    try {
      final json = await _apiClient.put('/api/users/$id', {
        'name': name,
        'email': email,
        'active': active,
        if (password != null && password.isNotEmpty) 'password': password,
      });
      return Right(UserEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(int id) async {
    try {
      await _apiClient.delete('/api/users/$id');
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, List<UserInterfaceGrants>>> privilegeMatrix(int userId) async {
    try {
      final json = await _apiClient.get('/api/users/$userId/privileges');
      final data = json['data'] as List<dynamic>? ?? const [];
      return Right(
        data.map((g) => UserInterfaceGrants.fromJson(g as Map<String, dynamic>)).toList(),
      );
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> syncPrivileges(
    int userId,
    int interfaceId,
    List<int> privilegeIds,
  ) async {
    try {
      await _apiClient.put('/api/users/$userId/privileges/$interfaceId', {
        'privilegeIds': privilegeIds,
      });
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
