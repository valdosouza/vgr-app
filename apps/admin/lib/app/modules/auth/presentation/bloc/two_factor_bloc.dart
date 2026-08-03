import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/login_result.dart';
import '../../domain/repository/auth_repository.dart';

sealed class TwoFactorEvent extends Equatable {
  const TwoFactorEvent();

  @override
  List<Object?> get props => [];
}

/// Asks the API for a fresh secret + otpauth URI (enroll-scope token).
class TwoFactorSetupRequested extends TwoFactorEvent {
  const TwoFactorSetupRequested(this.enrollToken);

  final String enrollToken;

  @override
  List<Object?> get props => [enrollToken];
}

class TwoFactorCodeSubmitted extends TwoFactorEvent {
  const TwoFactorCodeSubmitted({required this.enrollToken, required this.code});

  final String enrollToken;
  final String code;

  @override
  List<Object?> get props => [enrollToken, code];
}

sealed class TwoFactorState extends Equatable {
  const TwoFactorState();

  @override
  List<Object?> get props => [];
}

class TwoFactorLoading extends TwoFactorState {
  const TwoFactorLoading();
}

class TwoFactorSetupReady extends TwoFactorState {
  const TwoFactorSetupReady(this.setup, {this.invalidCode = false});

  final TwoFactorSetup setup;

  /// Set after a wrong code so the field shows the error without losing
  /// the secret the user already scanned.
  final bool invalidCode;

  @override
  List<Object?> get props => [setup, invalidCode];
}

/// Recovery codes are shown EXACTLY once (decision 114) — the session is
/// already open, but the page holds until the user confirms they saved them.
class TwoFactorActivated extends TwoFactorState {
  const TwoFactorActivated(this.activation);

  final TwoFactorActivation activation;

  @override
  List<Object?> get props => [activation];
}

class TwoFactorError extends TwoFactorState {
  const TwoFactorError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class TwoFactorBloc extends Bloc<TwoFactorEvent, TwoFactorState> {
  TwoFactorBloc(this._repository) : super(const TwoFactorLoading()) {
    on<TwoFactorSetupRequested>(_onSetupRequested);
    on<TwoFactorCodeSubmitted>(_onCodeSubmitted);
  }

  final AuthRepository _repository;

  Future<void> _onSetupRequested(
    TwoFactorSetupRequested event,
    Emitter<TwoFactorState> emit,
  ) async {
    emit(const TwoFactorLoading());
    final result = await _repository.startTwoFactorSetup(event.enrollToken);
    emit(result.fold(
      (failure) => TwoFactorError(failureText(failure)),
      TwoFactorSetupReady.new,
    ));
  }

  Future<void> _onCodeSubmitted(
    TwoFactorCodeSubmitted event,
    Emitter<TwoFactorState> emit,
  ) async {
    final previous = state;
    emit(const TwoFactorLoading());
    final result = await _repository.activateTwoFactor(event.enrollToken, event.code);
    emit(result.fold(
      (failure) => previous is TwoFactorSetupReady
          // Keep the QR on screen — the user only mistyped the code.
          ? TwoFactorSetupReady(previous.setup, invalidCode: true)
          : TwoFactorError(failureText(failure)),
      TwoFactorActivated.new,
    ));
  }
}
