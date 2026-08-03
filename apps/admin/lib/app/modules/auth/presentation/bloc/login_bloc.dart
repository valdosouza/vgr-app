import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/login_result.dart';
import '../../domain/repository/auth_repository.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._repository, this._identityBloc, this._localPrefs)
      : super(const LoginInitial()) {
    on<LoginPrefsRequested>(_onPrefsRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginEnrollmentCompleted>(_onEnrollmentCompleted);
  }

  final AuthRepository _repository;
  final IdentityBloc _identityBloc;
  final LocalPrefs _localPrefs;

  Future<void> _onPrefsRequested(
    LoginPrefsRequested event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginPrefsLoaded(
      rememberedEmail: await _localPrefs.getRememberedEmail(),
      keepConnected: await _localPrefs.getKeepConnected(),
    ));
  }

  /// Decision 73: token persisted ONLY under "keep me signed in";
  /// "remember my email" stores the email, never the password.
  Future<void> _openSession(
    String jwt, {
    required bool keepConnected,
    String? rememberedEmail,
    bool updateRememberedEmail = true,
  }) async {
    await _localPrefs.setKeepConnected(keepConnected);
    await _localPrefs.setSessionToken(keepConnected ? jwt : null);
    if (updateRememberedEmail) {
      await _localPrefs.setRememberedEmail(rememberedEmail);
    }

    _identityBloc.add(ProviderLoginCompleted(
      role: Role.admin,
      anonymityMode: AnonymityMode.anonymous,
      token: jwt,
    ));
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    final result = await _repository.login(
      event.email,
      event.password,
      totpCode: event.totpCode,
    );
    await result.fold(
      (failure) async {
        // Decision 114: the API distinguishes "wrong credentials" from
        // "credentials fine, second factor missing/wrong" by code — the
        // form switches to the code step instead of showing an error.
        if (failure.code == 'TWO_FACTOR_REQUIRED') {
          emit(LoginTwoFactorRequired(
            email: event.email,
            password: event.password,
            keepConnected: event.keepConnected,
            rememberEmail: event.rememberEmail,
            invalidCode: event.totpCode != null,
          ));
          return;
        }
        emit(LoginError(failureText(failure)));
      },
      (loginResult) async {
        switch (loginResult) {
          case LoginEnrollmentRequired(:final enrollToken):
            // No session exists yet — enrollment is mandatory.
            emit(LoginEnrollmentPending(
              enrollToken: enrollToken,
              keepConnected: event.keepConnected,
            ));
          case LoginSession(:final jwt):
            await _openSession(
              jwt,
              keepConnected: event.keepConnected,
              rememberedEmail: event.rememberEmail ? event.email : null,
            );
            emit(const LoginSuccess());
        }
      },
    );
  }

  /// Enrollment finished on the 2FA page: the session opens here so token
  /// persistence lives in one place only.
  Future<void> _onEnrollmentCompleted(
    LoginEnrollmentCompleted event,
    Emitter<LoginState> emit,
  ) async {
    await _openSession(
      event.jwt,
      keepConnected: event.keepConnected,
      updateRememberedEmail: false,
    );
    emit(const LoginSuccess());
  }
}
