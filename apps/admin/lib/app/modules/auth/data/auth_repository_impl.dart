import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, String>> login(String email, String password) async {
    try {
      final json = await _apiClient.post('/auth/admin-login', {'email': email, 'password': password});
      final jwt = json['jwt'] as String;
      _apiClient.setToken(jwt);
      return Right(jwt);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> recoveryPassword(String email) async {
    try {
      await _apiClient.post('/auth/recovery-password', {'email': email});
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> changePassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      await _apiClient.post('/auth/change-password', {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
