import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

abstract class AuthRepository {
  /// Returns the JWT on success. `ApiClient.setToken` is called internally
  /// as a side effect — every other repository's calls need no change.
  Future<Either<Failure, String>> login(String email, String password);

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
