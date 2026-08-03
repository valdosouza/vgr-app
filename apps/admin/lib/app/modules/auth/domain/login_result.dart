import 'package:equatable/equatable.dart';

/// What `POST /auth/admin-login` can answer since decision 114.
///
/// Enrollment is mandatory: a user who has not set up TOTP never receives
/// a session token, only a short-lived enroll-scope token usable on the
/// `/auth/2fa/*` endpoints.
sealed class LoginResult extends Equatable {
  const LoginResult();

  @override
  List<Object?> get props => [];
}

class LoginSession extends LoginResult {
  const LoginSession(this.jwt);

  final String jwt;

  @override
  List<Object?> get props => [jwt];
}

class LoginEnrollmentRequired extends LoginResult {
  const LoginEnrollmentRequired(this.enrollToken);

  final String enrollToken;

  @override
  List<Object?> get props => [enrollToken];
}

/// Secret + otpauth URI handed to the panel at enrollment (decision 114).
class TwoFactorSetup extends Equatable {
  const TwoFactorSetup({required this.secret, required this.otpauthUri});

  final String secret;
  final String otpauthUri;

  @override
  List<Object?> get props => [secret, otpauthUri];
}

/// Session plus the one-time recovery codes, shown exactly once.
class TwoFactorActivation extends Equatable {
  const TwoFactorActivation({required this.jwt, required this.recoveryCodes});

  final String jwt;
  final List<String> recoveryCodes;

  @override
  List<Object?> get props => [jwt, recoveryCodes];
}
