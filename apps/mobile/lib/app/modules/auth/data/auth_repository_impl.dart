import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/app_session_entity.dart';
import '../domain/repository/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  AppSessionEntity _session(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    // The access token drives every subsequent app-plane call — set it
    // here, in the one place a session is ever opened, same pattern as
    // apps/admin's AuthRepositoryImpl.
    _apiClient.setToken(data['accessToken'] as String);
    return AppSessionEntity(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      accountId: data['accountId'] as int,
    );
  }

  @override
  Future<Either<Failure, AppSessionEntity>> register({
    required String displayName,
    required String email,
    required String password,
    required String consentVersion,
  }) async {
    try {
      final json = await _apiClient.post('/app-auth/register', {
        'displayName': displayName,
        'email': email,
        'password': password,
        'consentVersion': consentVersion,
      });
      return Right(_session(json));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, AppSessionEntity>> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    try {
      final json = await _apiClient.post('/app-auth/login', {
        'email': email,
        'password': password,
        if (totpCode != null) 'totpCode': totpCode,
      });
      return Right(_session(json));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, AppSessionEntity>> refresh(String refreshToken) async {
    try {
      final json = await _apiClient.post('/app-auth/refresh', {'refreshToken': refreshToken});
      return Right(_session(json));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, AppSessionEntity>> loginWithProvider({
    required String provider,
    required String idToken,
  }) async {
    try {
      final json = await _apiClient
          .post('/app-auth/login-provider', {'provider': provider, 'idToken': idToken});
      return Right(_session(json));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      await _apiClient.post('/app-auth/verify-email/send', const {});
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> confirmEmailVerification(String code) async {
    try {
      await _apiClient.post('/app-auth/verify-email/confirm', {'code': code});
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> signOutEverywhere() async {
    try {
      await _apiClient.post('/app-auth/sign-out-everywhere', const {});
      _apiClient.setToken(null);
      return const Right(null);
    } on Failure catch (f) {
      // The token might already be stale (401) — still drop it locally,
      // signing out must never fail closed into a stuck session.
      _apiClient.setToken(null);
      return Left(f);
    }
  }
}
