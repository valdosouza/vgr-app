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
  });

  final String email;
  final String password;

  /// Persists the JWT so the session survives a page refresh (decision 73).
  final bool keepConnected;

  /// Stores the email only — never the password.
  final bool rememberEmail;

  @override
  List<Object?> get props => [email, password, keepConnected, rememberEmail];
}

/// Loads remembered email / keep-connected choice into the form on open.
class LoginPrefsRequested extends LoginEvent {
  const LoginPrefsRequested();
}
