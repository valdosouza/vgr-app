import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecase/confirm_email_verification_usecase.dart';
import '../../domain/usecase/send_email_verification_usecase.dart';

sealed class EmailVerificationEvent extends Equatable {
  const EmailVerificationEvent();

  @override
  List<Object?> get props => [];
}

class EmailVerificationSendPressed extends EmailVerificationEvent {
  const EmailVerificationSendPressed();
}

class EmailVerificationConfirmPressed extends EmailVerificationEvent {
  const EmailVerificationConfirmPressed(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

sealed class EmailVerificationState extends Equatable {
  const EmailVerificationState();

  @override
  List<Object?> get props => [];
}

class EmailVerificationIdle extends EmailVerificationState {
  const EmailVerificationIdle();
}

class EmailVerificationSending extends EmailVerificationState {
  const EmailVerificationSending();
}

/// Code sent (or a resend) — the form shows the code field. [failure]
/// carries a wrong/expired-code error while staying on this step.
class EmailVerificationCodeSent extends EmailVerificationState {
  const EmailVerificationCodeSent({this.failure});

  final Failure? failure;

  @override
  List<Object?> get props => [failure];
}

class EmailVerificationConfirming extends EmailVerificationState {
  const EmailVerificationConfirming();
}

class EmailVerificationSuccess extends EmailVerificationState {
  const EmailVerificationSuccess();
}

class EmailVerificationSendFailed extends EmailVerificationState {
  const EmailVerificationSendFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Email verification (decision 151) — required before consequential
/// actions (offering/claiming a reward, becoming a responder), never
/// before reporting (decision 123).
class EmailVerificationBloc extends Bloc<EmailVerificationEvent, EmailVerificationState> {
  EmailVerificationBloc(this._send, this._confirm) : super(const EmailVerificationIdle()) {
    on<EmailVerificationSendPressed>(_onSendPressed);
    on<EmailVerificationConfirmPressed>(_onConfirmPressed);
  }

  final SendEmailVerificationUsecase _send;
  final ConfirmEmailVerificationUsecase _confirm;

  Future<void> _onSendPressed(
    EmailVerificationSendPressed event,
    Emitter<EmailVerificationState> emit,
  ) async {
    emit(const EmailVerificationSending());
    final result = await _send();
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(EmailVerificationSendFailed(failure)),
      (_) => emit(const EmailVerificationCodeSent()),
    );
  }

  Future<void> _onConfirmPressed(
    EmailVerificationConfirmPressed event,
    Emitter<EmailVerificationState> emit,
  ) async {
    if (state is! EmailVerificationCodeSent) return;

    emit(const EmailVerificationConfirming());
    final result = await _confirm(event.code);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(EmailVerificationCodeSent(failure: failure)),
      (_) => emit(const EmailVerificationSuccess()),
    );
  }
}
