import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/app_session_entity.dart';
import '../../domain/usecase/login_usecase.dart';
import '../../domain/usecase/login_with_google_usecase.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.email, required this.password, this.totpCode});

  final String email;
  final String password;
  final String? totpCode;

  @override
  List<Object?> get props => [email, password, totpCode];
}

class LoginWithGooglePressed extends LoginEvent {
  const LoginWithGooglePressed();
}

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object?> get props => [];
}

class LoginReady extends LoginState {
  const LoginReady({this.failure});

  final Failure? failure;

  @override
  List<Object?> get props => [failure];
}

class LoginSubmitting extends LoginState {
  const LoginSubmitting();
}

class LoginSuccess extends LoginState {
  const LoginSuccess();
}

/// Password accepted but the account enabled the optional TOTP (decision
/// 124) — the form asks for the code instead of showing an error.
class LoginTwoFactorRequired extends LoginState {
  const LoginTwoFactorRequired({
    required this.email,
    required this.password,
    this.invalidCode = false,
  });

  final String email;
  final String password;
  final bool invalidCode;

  @override
  List<Object?> get props => [email, password, invalidCode];
}

/// Email+password login (decisions 119/122/124). Unlike the panel, TOTP
/// enrollment is never mandatory — the second factor only appears here
/// when the account already turned it on.
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._login, this._loginWithGoogle, this._identityBloc, this._localPrefs)
      : super(const LoginReady()) {
    on<LoginSubmitted>(_onSubmitted);
    on<LoginWithGooglePressed>(_onGooglePressed);
  }

  final LoginUsecase _login;
  final LoginWithGoogleUsecase _loginWithGoogle;
  final IdentityBloc _identityBloc;
  final LocalPrefs _localPrefs;

  Future<void> _onSubmitted(LoginSubmitted event, Emitter<LoginState> emit) async {
    emit(const LoginSubmitting());
    final result = await _login(
      email: event.email,
      password: event.password,
      totpCode: event.totpCode,
    );
    if (emit.isDone) return;
    await result.fold(
      (failure) async {
        if (failure.code == 'TWO_FACTOR_REQUIRED') {
          emit(LoginTwoFactorRequired(
            email: event.email,
            password: event.password,
            invalidCode: event.totpCode != null,
          ));
          return;
        }
        emit(LoginReady(failure: failure));
      },
      (session) async {
        await _onSessionIssued(session);
        emit(const LoginSuccess());
      },
    );
  }

  Future<void> _onGooglePressed(
    LoginWithGooglePressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginSubmitting());
    final result = await _loginWithGoogle();
    if (emit.isDone) return;
    if (result == null) {
      // Cancelled the native flow — back to the form, no error shown
      // (same contract as the photo picker's null-means-cancel).
      emit(const LoginReady());
      return;
    }
    await result.fold(
      (failure) async => emit(LoginReady(failure: failure)),
      (session) async {
        await _onSessionIssued(session);
        emit(const LoginSuccess());
      },
    );
  }

  Future<void> _onSessionIssued(AppSessionEntity session) async {
    await _localPrefs.setAppRefreshToken(session.refreshToken);
    _identityBloc.add(ProviderLoginCompleted(
      role: Role.reporter,
      anonymityMode: AnonymityMode.identifiedNoReward,
      token: session.accessToken,
    ));
  }
}
