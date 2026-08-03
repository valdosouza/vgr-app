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

class LoginError extends LoginState {
  const LoginError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
