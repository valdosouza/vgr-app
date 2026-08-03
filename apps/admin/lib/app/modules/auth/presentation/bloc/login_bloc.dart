import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/auth_repository.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._repository, this._identityBloc, this._localPrefs)
      : super(const LoginInitial()) {
    on<LoginPrefsRequested>(_onPrefsRequested);
    on<LoginSubmitted>(_onLoginSubmitted);
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

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    final result = await _repository.login(event.email, event.password);
    await result.fold(
      (failure) async => emit(LoginError(failure.message)),
      (jwt) async {
        // Decision 73: token persisted ONLY under "keep me signed in";
        // "remember my email" stores the email, never the password.
        await _localPrefs.setKeepConnected(event.keepConnected);
        await _localPrefs.setSessionToken(event.keepConnected ? jwt : null);
        await _localPrefs.setRememberedEmail(event.rememberEmail ? event.email : null);

        _identityBloc.add(ProviderLoginCompleted(
          role: Role.admin,
          anonymityMode: AnonymityMode.anonymous,
          token: jwt,
        ));
        emit(const LoginSuccess());
      },
    );
  }
}
