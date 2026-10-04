import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/user_entity.dart';
import '../domain/repository/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<UserEntity>>> list(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/users?${query.toQueryString()}');
      return Right(PagedResult.fromJson(json['data'] as Map<String, dynamic>, UserEntity.fromJson));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, UserEntity>> create(UserDraft draft) async {
    try {
      final json = await _apiClient.post('/api/users', {
        'name': draft.name,
        'email': draft.email,
        'active': draft.active,
        'password': draft.password ?? '',
      });
      return Right(UserEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, UserEntity>> update(UserEntity current, UserDraft draft) async {
    try {
      final json = await _apiClient.put('/api/users/${current.id}', {
        'name': draft.name,
        'email': draft.email,
        'active': draft.active,
        // No `locale`: the form does not edit it, and since decision 230 the
        // API keeps what is saved when the field is absent (it used to null
        // it, so the panel echoed the value — which could also overwrite a
        // language the user had just changed).
        if (draft.password != null && draft.password!.isNotEmpty) 'password': draft.password,
      });
      return Right(UserEntity.fromJson(json['data'] as Map<String, dynamic>));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> delete(UserEntity item) async {
    try {
      await _apiClient.delete('/api/users/${item.id}');
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
