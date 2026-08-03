import 'package:equatable/equatable.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

/// Remembered form defaults loaded from LocalPrefs (decision 73).
class LoginPrefsLoaded extends LoginState {
  const LoginPrefsLoaded({this.rememberedEmail, this.keepConnected = false});

  final String? rememberedEmail;
  final bool keepConnected;

  @override
  List<Object?> get props => [rememberedEmail, keepConnected];
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  const LoginSuccess();
}

/// Password accepted, account already enrolled: the form now asks for the
/// 6-digit code (decision 114). Carries the credentials so the second
/// submit does not make the user retype them.
class LoginTwoFactorRequired extends LoginState {
  const LoginTwoFactorRequired({
    required this.email,
    required this.password,
    required this.keepConnected,
    required this.rememberEmail,
    this.invalidCode = false,
  });

  final String email;
  final String password;
  final bool keepConnected;
  final bool rememberEmail;

  /// True after a wrong code — the field shows an error instead of the
  /// plain "enter your code" hint.
  final bool invalidCode;

  @override
  List<Object?> get props => [email, password, keepConnected, rememberEmail, invalidCode];
}

/// Password accepted but 2FA was never set up: enrollment is mandatory
/// (decision 114), so the flow moves to the enrollment page carrying the
/// short-lived enroll token.
class LoginEnrollmentPending extends LoginState {
  const LoginEnrollmentPending({
    required this.enrollToken,
    required this.keepConnected,
  });

  final String enrollToken;
  final bool keepConnected;

  @override
  List<Object?> get props => [enrollToken, keepConnected];
}

class LoginError extends LoginState {
  const LoginError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
