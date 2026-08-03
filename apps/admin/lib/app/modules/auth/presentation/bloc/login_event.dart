import 'package:equatable/equatable.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({
    required this.email,
    required this.password,
    this.keepConnected = false,
    this.rememberEmail = false,
    this.totpCode,
  });

  final String email;
  final String password;

  /// Second factor, sent on the retry after the API answered
  /// TWO_FACTOR_REQUIRED (decision 114).
  final String? totpCode;

  /// Persists the JWT so the session survives a page refresh (decision 73).
  final bool keepConnected;

  /// Stores the email only — never the password.
  final bool rememberEmail;

  @override
  List<Object?> get props => [email, password, keepConnected, rememberEmail, totpCode];
}

/// Enrollment finished on the 2FA page — the session token comes back here
/// so the usual "keep me signed in" persistence still happens in one place.
class LoginEnrollmentCompleted extends LoginEvent {
  const LoginEnrollmentCompleted({required this.jwt, required this.keepConnected});

  final String jwt;
  final bool keepConnected;

  @override
  List<Object?> get props => [jwt, keepConnected];
}

/// Loads remembered email / keep-connected choice into the form on open.
class LoginPrefsRequested extends LoginEvent {
  const LoginPrefsRequested();
}
