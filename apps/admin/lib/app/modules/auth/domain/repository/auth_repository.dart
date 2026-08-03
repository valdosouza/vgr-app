import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../login_result.dart';

abstract class AuthRepository {
  /// Either a session (JWT) or the mandatory-enrollment branch of decision
  /// 114. `ApiClient.setToken` is called internally when a session is
  /// issued — every other repository's calls need no change.
  ///
  /// [totpCode] is sent when the account already has 2FA enabled; omitting
  /// it against an enrolled account fails with code `TWO_FACTOR_REQUIRED`,
  /// which is the app's cue to show the code field.
  Future<Either<Failure, LoginResult>> login(
    String email,
    String password, {
    String? totpCode,
  });

  /// Starts enrollment with the enroll-scope token from [login].
  Future<Either<Failure, TwoFactorSetup>> startTwoFactorSetup(String enrollToken);

  /// Confirms the first code: enables 2FA, returns the session and the
  /// one-time recovery codes (shown once, never retrievable again).
  Future<Either<Failure, TwoFactorActivation>> activateTwoFactor(
    String enrollToken,
    String code,
  );

  /// "Lost my phone": password + one unused recovery code opens a session
  /// and clears TOTP, so the next login re-enrolls.
  Future<Either<Failure, String>> recoverWithBackupCode(
    String email,
    String password,
    String recoveryCode,
  );

  /// Always succeeds from the caller's perspective (the API never reveals
  /// whether the email exists) — a 6-digit code valid 15 minutes is emailed.
  Future<Either<Failure, Unit>> recoveryPassword(String email);

  /// Sets a new password given the emailed code.
  Future<Either<Failure, Unit>> changePassword(
    String email,
    String code,
    String newPassword,
  );
}
