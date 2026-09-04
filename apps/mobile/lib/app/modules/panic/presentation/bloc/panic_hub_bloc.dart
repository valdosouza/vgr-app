import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecase/check_active_panic_alert_usecase.dart';
import '../../domain/usecase/resolve_panic_alert_usecase.dart';
import '../../domain/usecase/trigger_panic_alert_usecase.dart';

sealed class PanicHubEvent extends Equatable {
  const PanicHubEvent();

  @override
  List<Object?> get props => [];
}

/// Checks the LOCALLY-remembered active alert (no PP1 endpoint exists to
/// read it from the server — `panic_repository.dart`'s doc comment).
class PanicHubStarted extends PanicHubEvent {
  const PanicHubStarted();
}

/// Dispatched ONLY after the page's own `showVgrConfirm` (decision 65 is a
/// serious action, `destructive: true`, same widget RT2 used for closing a
/// report) — this bloc never re-derives that confirmation.
class PanicTriggerPressed extends PanicHubEvent {
  const PanicTriggerPressed();
}

/// "I'm safe now" — only the triggerer resolves (decision 197); no
/// confirmation gate, unlike the trigger, since calming a false alarm
/// down should never carry extra friction.
class PanicResolvePressed extends PanicHubEvent {
  const PanicResolvePressed();
}

enum PanicPhase { loading, idle, triggering, active, resolving }

class PanicHubState extends Equatable {
  const PanicHubState({
    this.phase = PanicPhase.loading,
    this.alertId,
    this.recipientCount,
    this.queued = false,
    this.failure,
  });

  final PanicPhase phase;

  /// Present once the SERVER assigned one — null while a queued trigger
  /// (decision 28) has not landed yet (see [queued]), so there is nothing
  /// to call `resolve` with.
  final int? alertId;

  /// Server-reported responder count (65 — may legitimately be 0), only
  /// known right after a fresh ONLINE trigger; a remembered alert from a
  /// previous app session never carries it (no PP1 endpoint to
  /// reconstruct it, see `panic_repository.dart`).
  final int? recipientCount;

  /// True while the current alert's trigger is still waiting on the
  /// offline queue to reach the API (decision 28 — queued is a success,
  /// not an error, but resolve is not reachable until [alertId] exists).
  final bool queued;

  /// The last trigger/resolve refusal, surfaced inline; cleared on the
  /// next attempt of either action.
  final Failure? failure;

  PanicHubState copyWith({
    PanicPhase? phase,
    int? alertId,
    int? recipientCount,
    bool? queued,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      PanicHubState(
        phase: phase ?? this.phase,
        alertId: alertId ?? this.alertId,
        recipientCount: recipientCount ?? this.recipientCount,
        queued: queued ?? this.queued,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [phase, alertId, recipientCount, queued, failure];
}

/// The panic hub (decisions 62/65/191/196-198): trigger button when idle,
/// active-alert status + "I'm safe now" when this device has one
/// unresolved, driven entirely by the local record `PanicRepository`
/// surfaces (no PP1 endpoint to read either fact from the server).
class PanicHubBloc extends Bloc<PanicHubEvent, PanicHubState> {
  PanicHubBloc(this._checkActive, this._trigger, this._resolve) : super(const PanicHubState()) {
    on<PanicHubStarted>(_onStarted);
    on<PanicTriggerPressed>(_onTriggerPressed);
    on<PanicResolvePressed>(_onResolvePressed);
  }

  final CheckActivePanicAlertUsecase _checkActive;
  final TriggerPanicAlertUsecase _trigger;
  final ResolvePanicAlertUsecase _resolve;

  Future<void> _onStarted(PanicHubStarted event, Emitter<PanicHubState> emit) async {
    emit(const PanicHubState(phase: PanicPhase.loading));
    final alertId = await _checkActive();
    if (emit.isDone) return;
    emit(alertId == null
        ? const PanicHubState(phase: PanicPhase.idle)
        : PanicHubState(phase: PanicPhase.active, alertId: alertId));
  }

  Future<void> _onTriggerPressed(
    PanicTriggerPressed event,
    Emitter<PanicHubState> emit,
  ) async {
    if (state.phase == PanicPhase.triggering) return; // one attempt in flight at a time
    emit(state.copyWith(phase: PanicPhase.triggering, clearFailure: true));
    final result = await _trigger();
    if (emit.isDone) return;
    result.fold(
      // Location failure (never reached the API) or a Failure the API
      // judged (422/451, or 409 PANIC_ALERT_ACTIVE — the local record
      // disagreeing with the server, a documented PP1 gap): back to
      // idle, error shown, retryable.
      (failure) => emit(PanicHubState(phase: PanicPhase.idle, failure: failure)),
      (outcome) => emit(PanicHubState(
        phase: PanicPhase.active,
        alertId: outcome.alert?.alertId,
        recipientCount: outcome.alert?.recipientCount,
        queued: outcome.queued,
      )),
    );
  }

  Future<void> _onResolvePressed(
    PanicResolvePressed event,
    Emitter<PanicHubState> emit,
  ) async {
    final alertId = state.alertId;
    // Nothing to resolve yet while a queued trigger has not landed an
    // alertId (decision 28) — the page hides the action in that case too.
    if (state.phase != PanicPhase.active || alertId == null) return;

    emit(state.copyWith(phase: PanicPhase.resolving, clearFailure: true));
    final result = await _resolve(alertId);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(state.copyWith(phase: PanicPhase.active, failure: failure)),
      (_) => emit(const PanicHubState(phase: PanicPhase.idle)),
    );
  }
}
