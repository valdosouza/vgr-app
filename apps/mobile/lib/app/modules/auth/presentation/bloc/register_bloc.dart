import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecase/register_usecase.dart';

sealed class RegisterEvent extends Equatable {
  const RegisterEvent();

  @override
  List<Object?> get props => [];
}

class RegisterSubmitted extends RegisterEvent {
  const RegisterSubmitted({
    required this.displayName,
    required this.email,
    required this.password,
    required this.consentVersion,
  });

  final String displayName;
  final String email;
  final String password;
  final String consentVersion;

  @override
  List<Object?> get props => [displayName, email, password, consentVersion];
}

sealed class RegisterState extends Equatable {
  const RegisterState();

  @override
  List<Object?> get props => [];
}

class RegisterReady extends RegisterState {
  const RegisterReady({this.failure});

  final Failure? failure;

  @override
  List<Object?> get props => [failure];
}

class RegisterSubmitting extends RegisterState {
  const RegisterSubmitting();
}

class RegisterSuccess extends RegisterState {
  const RegisterSuccess();
}

/// Email+password sign-up (decisions 119/123/151). No verification gate on
/// the way in — "a denúncia nunca espera" — the account can report
/// immediately; the email-verification screen is a separate, optional step.
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._register, this._identityBloc, this._localPrefs)
      : super(const RegisterReady()) {
    on<RegisterSubmitted>(_onSubmitted);
  }

  final RegisterUsecase _register;
  final IdentityBloc _identityBloc;
  final LocalPrefs _localPrefs;

  Future<void> _onSubmitted(RegisterSubmitted event, Emitter<RegisterState> emit) async {
    emit(const RegisterSubmitting());
    final result = await _register(
      displayName: event.displayName,
      email: event.email,
      password: event.password,
      consentVersion: event.consentVersion,
    );
    if (emit.isDone) return;
    await result.fold(
      (failure) async => emit(RegisterReady(failure: failure)),
      (session) async {
        // The app has no "keep me signed in" choice (decision 122) — the
        // refresh token is always persisted, same rationale as a mobile
        // OS session rather than a shared browser (decision 73's admin
        // rule does not apply here).
        await _localPrefs.setAppRefreshToken(session.refreshToken);
        _identityBloc.add(ProviderLoginCompleted(
          role: Role.reporter,
          anonymityMode: AnonymityMode.identifiedNoReward,
          token: session.accessToken,
        ));
        emit(const RegisterSuccess());
      },
    );
  }
}
