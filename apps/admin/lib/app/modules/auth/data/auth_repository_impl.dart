import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/login_result.dart';
import '../domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, LoginResult>> login(
    String email,
    String password, {
    String? totpCode,
  }) async {
    try {
      final json = await _apiClient.post('/auth/admin-login', {
        'email': email,
        'password': password,
        if (totpCode != null) 'totpCode': totpCode,
      });
      // Decision 114: enrollment branch carries no session token at all.
      if (json['twoFactorSetupRequired'] == true) {
        return Right(LoginEnrollmentRequired(json['enrollToken'] as String));
      }
      final jwt = json['jwt'] as String;
      _apiClient.setToken(jwt);
      return Right(LoginSession(jwt));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, TwoFactorSetup>> startTwoFactorSetup(String enrollToken) async {
    try {
      final json = await _apiClient.post('/auth/2fa/setup', {'enrollToken': enrollToken});
      final data = json['data'] as Map<String, dynamic>;
      return Right(TwoFactorSetup(
        secret: data['secret'] as String,
        otpauthUri: data['otpauthUri'] as String,
      ));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, TwoFactorActivation>> activateTwoFactor(
    String enrollToken,
    String code,
  ) async {
    try {
      final json = await _apiClient.post('/auth/2fa/activate', {
        'enrollToken': enrollToken,
        'code': code,
      });
      final data = json['data'] as Map<String, dynamic>;
      final jwt = data['jwt'] as String;
      _apiClient.setToken(jwt);
      return Right(TwoFactorActivation(
        jwt: jwt,
        recoveryCodes: (data['recoveryCodes'] as List<dynamic>).cast<String>(),
      ));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, String>> recoverWithBackupCode(
    String email,
    String password,
    String recoveryCode,
  ) async {
    try {
      final json = await _apiClient.post('/auth/2fa/recover', {
        'email': email,
        'password': password,
        'recoveryCode': recoveryCode,
      });
      final jwt = (json['data'] as Map<String, dynamic>)['jwt'] as String;
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
