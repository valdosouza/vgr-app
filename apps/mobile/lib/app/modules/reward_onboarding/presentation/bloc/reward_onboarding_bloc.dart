import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/reward_recipient_profile_entity.dart';
import '../../domain/usecase/get_onboarding_status_usecase.dart';
import '../../domain/usecase/submit_onboarding_usecase.dart';

sealed class RewardOnboardingEvent extends Equatable {
  const RewardOnboardingEvent();

  @override
  List<Object?> get props => [];
}

class OnboardingStarted extends RewardOnboardingEvent {
  const OnboardingStarted();
}

class OnboardingSubmitPressed extends RewardOnboardingEvent {
  const OnboardingSubmitPressed(this.profile);

  final RewardRecipientProfileEntity profile;

  @override
  List<Object?> get props => [profile];
}

sealed class RewardOnboardingState extends Equatable {
  const RewardOnboardingState();

  @override
  List<Object?> get props => [];
}

class OnboardingLoading extends RewardOnboardingState {
  const OnboardingLoading();
}

class OnboardingLoadError extends RewardOnboardingState {
  const OnboardingLoadError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// This account already has a `tb_reward_recipient_profile` row — the API
/// rejects a second onboarding with 409 (decision 143), so the screen
/// shows this instead of a form that can only fail.
class OnboardingAlreadyDone extends RewardOnboardingState {
  const OnboardingAlreadyDone();
}

class OnboardingForm extends RewardOnboardingState {
  const OnboardingForm({this.failure});

  /// Last submission failure, kept so the form can show it and retry.
  final Failure? failure;

  @override
  List<Object?> get props => [failure];
}

class OnboardingSubmitting extends RewardOnboardingState {
  const OnboardingSubmitting();
}

class OnboardingSuccess extends RewardOnboardingState {
  const OnboardingSuccess();
}

/// Helper onboarding to receive reward payouts (`/app-reward/onboarding`,
/// decisions 104/143). Checks status first so an already-onboarded helper
/// never sees a form that can only 409.
class RewardOnboardingBloc extends Bloc<RewardOnboardingEvent, RewardOnboardingState> {
  RewardOnboardingBloc(this._getStatus, this._submit) : super(const OnboardingLoading()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingSubmitPressed>(_onSubmitPressed);
  }

  final GetOnboardingStatusUsecase _getStatus;
  final SubmitOnboardingUsecase _submit;

  Future<void> _onStarted(
    OnboardingStarted event,
    Emitter<RewardOnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());
    final result = await _getStatus();
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(OnboardingLoadError(failure)),
      (onboarded) => emit(onboarded ? const OnboardingAlreadyDone() : const OnboardingForm()),
    );
  }

  Future<void> _onSubmitPressed(
    OnboardingSubmitPressed event,
    Emitter<RewardOnboardingState> emit,
  ) async {
    if (state is! OnboardingForm) return;

    emit(const OnboardingSubmitting());
    final result = await _submit(event.profile);
    if (emit.isDone) return;
    result.fold(
      (failure) => failure.code == 'DUPLICATE'
          ? emit(const OnboardingAlreadyDone())
          : emit(OnboardingForm(failure: failure)),
      (_) => emit(const OnboardingSuccess()),
    );
  }
}
