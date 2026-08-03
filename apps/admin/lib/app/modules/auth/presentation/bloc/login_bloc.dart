import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/auth_repository.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._repository, this._identityBloc) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  final AuthRepository _repository;
  final IdentityBloc _identityBloc;

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    final result = await _repository.login(event.email, event.password);
    result.fold(
      (failure) => emit(LoginError(failure.message)),
      (jwt) {
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
