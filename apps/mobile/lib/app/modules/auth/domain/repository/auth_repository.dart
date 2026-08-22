import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/app_session_entity.dart';

/// Contract of the app plane's auth data layer (`/app-auth`, decisions
/// 119-124/151-152). Apple/Facebook and phone OTP are still absent —
/// decision 152 defers them until real credentials exist; Google is wired.
abstract class AuthRepository {
  Future<Either<Failure, AppSessionEntity>> register({
    required String displayName,
    required String email,
    required String password,
    required String consentVersion,
  });

  /// [totpCode] is only sent when the account asked for one already — the
  /// API answers `TWO_FACTOR_REQUIRED` the first time (decision 124).
  Future<Either<Failure, AppSessionEntity>> login({
    required String email,
    required String password,
    String? totpCode,
  });

  Future<Either<Failure, AppSessionEntity>> refresh(String refreshToken);

  /// [idToken] must already be a raw token from the provider's SDK — the
  /// API is the one that verifies it (decision 119: the app plane never
  /// trusts a client-supplied claim about itself).
  Future<Either<Failure, AppSessionEntity>> loginWithProvider({
    required String provider,
    required String idToken,
  });

  /// Decision 151: sends a 6-digit code to the account's email, reusing
  /// the panel's mailer. Silent no-op server-side with no email or an
  /// already-verified one.
  Future<Either<Failure, void>> sendEmailVerification();

  Future<Either<Failure, void>> confirmEmailVerification(String code);

  /// Revokes every refresh token and bumps `session_version` (decision
  /// 122) — the only shape of sign-out the API exposes; there is no
  /// single-device variant.
  Future<Either<Failure, void>> signOutEverywhere();
}
