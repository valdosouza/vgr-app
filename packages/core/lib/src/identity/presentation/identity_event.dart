import 'package:equatable/equatable.dart';

import '../domain/anonymity_mode.dart';
import '../domain/role.dart';

sealed class IdentityEvent extends Equatable {
  const IdentityEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when AuthenticateWithProviderUsecase resolves successfully.
class ProviderLoginCompleted extends IdentityEvent {
  const ProviderLoginCompleted({required this.role, required this.anonymityMode, this.token});

  final Role role;
  final AnonymityMode anonymityMode;
  final String? token;

  @override
  List<Object?> get props => [role, anonymityMode, token];
}

/// Fired by logout (decision 215): back to the anonymous default, so every
/// guard that reads the role sees "no session" immediately.
class SessionCleared extends IdentityEvent {
  const SessionCleared();
}
