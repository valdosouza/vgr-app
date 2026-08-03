import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repository/auth_repository.dart';

sealed class RecoveryEvent extends Equatable {
  const RecoveryEvent();

  @override
  List<Object?> get props => [];
}

class RecoveryCodeRequested extends RecoveryEvent {
  const RecoveryCodeRequested(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

class ChangePasswordSubmitted extends RecoveryEvent {
  const ChangePasswordSubmitted({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  final String email;
  final String code;
  final String newPassword;

  @override
  List<Object?> get props => [email, code, newPassword];
}

sealed class RecoveryState extends Equatable {
  const RecoveryState();

  @override
  List<Object?> get props => [];
}

class RecoveryInitial extends RecoveryState {
  const RecoveryInitial();
}

class RecoveryLoading extends RecoveryState {
  const RecoveryLoading();
}

/// The code request answered — always generic (no user enumeration).
class RecoveryCodeSent extends RecoveryState {
  const RecoveryCodeSent(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

class PasswordChanged extends RecoveryState {
  const PasswordChanged();
}

class RecoveryError extends RecoveryState {
  const RecoveryError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class RecoveryBloc extends Bloc<RecoveryEvent, RecoveryState> {
  RecoveryBloc(this._repository) : super(const RecoveryInitial()) {
    on<RecoveryCodeRequested>(_onCodeRequested);
    on<ChangePasswordSubmitted>(_onChangeSubmitted);
  }

  final AuthRepository _repository;

  Future<void> _onCodeRequested(
    RecoveryCodeRequested event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(const RecoveryLoading());
    final result = await _repository.recoveryPassword(event.email);
    result.fold(
      (failure) => emit(RecoveryError(failure.message)),
      (_) => emit(RecoveryCodeSent(event.email)),
    );
  }

  Future<void> _onChangeSubmitted(
    ChangePasswordSubmitted event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(const RecoveryLoading());
    final result = await _repository.changePassword(event.email, event.code, event.newPassword);
    result.fold(
      (failure) => emit(RecoveryError(failure.message)),
      (_) => emit(const PasswordChanged()),
    );
  }
}
