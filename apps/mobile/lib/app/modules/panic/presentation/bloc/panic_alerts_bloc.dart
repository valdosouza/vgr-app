import 'dart:async';

import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../report/domain/gateway/location_gateway.dart';
import '../../domain/entity/panic_entities.dart';
import '../../domain/usecase/list_panic_alerts_usecase.dart';

/// Poll cadence while the screen is visible (decision 192 — polling only,
/// no push). Mirrors `chatPollInterval`: one place to tune, never a
/// background schedule.
const panicAlertsPollInterval = Duration(seconds: 5);

/// A panic alert is a rare event compared to chat messages — a small page
/// is plenty.
const panicAlertsPageLimit = 20;

/// Injectable clock for the poll — tests hand a controlled stream, same
/// contract as `ChatTicker`.
typedef PanicAlertsTicker = Stream<void> Function(Duration interval);

Stream<void> _periodicTicker(Duration interval) => Stream<void>.periodic(interval);

sealed class PanicAlertsEvent extends Equatable {
  const PanicAlertsEvent();

  @override
  List<Object?> get props => [];
}

class PanicAlertsStarted extends PanicAlertsEvent {
  const PanicAlertsStarted();
}

class PanicAlertsPollTicked extends PanicAlertsEvent {
  const PanicAlertsPollTicked();
}

/// The screen left the foreground: polling stops (192 — never in background).
class PanicAlertsPaused extends PanicAlertsEvent {
  const PanicAlertsPaused();
}

class PanicAlertsResumed extends PanicAlertsEvent {
  const PanicAlertsResumed();
}

sealed class PanicAlertsState extends Equatable {
  const PanicAlertsState();

  @override
  List<Object?> get props => [];
}

class PanicAlertsLoading extends PanicAlertsState {
  const PanicAlertsLoading();
}

class PanicAlertsError extends PanicAlertsState {
  const PanicAlertsError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

class PanicAlertsLoaded extends PanicAlertsState {
  const PanicAlertsLoaded({required this.alerts});

  /// Ascending by `alertId`, oldest first (server order, never re-sorted
  /// here) — an EMPTY list is a normal state (a non-responder, or a
  /// responder with nothing yet), never an error.
  final List<ResponderAlertEntity> alerts;

  @override
  List<Object?> get props => [alerts];
}

/// The responder's own alerts inbox (192, decisions 195/197): initial
/// load, then a cursor poll every tick while visible — mirrors
/// `ChatConversationBloc`'s exact ticker/lifecycle shape. Each row is
/// READ ONLY (197: a responder can never resolve someone else's alert),
/// so there is no action event here beyond loading.
///
/// Position cadence (judgment call): the responder's OWN position is
/// re-read once per visit/resume, never on every 5-second tick —
/// repeatedly hitting the OS location API that often is wasteful, and a
/// resume (or a manual re-entry) is a fair moment to refresh it. A stale
/// position is kept, best effort, if re-locating on resume fails
/// transiently, so a permission blip never loses the whole screen.
class PanicAlertsBloc extends Bloc<PanicAlertsEvent, PanicAlertsState> {
  PanicAlertsBloc(
    this._listAlerts,
    this._locationGateway, {
    PanicAlertsTicker ticker = _periodicTicker,
    Duration pollInterval = panicAlertsPollInterval,
  })  : _ticker = ticker,
        _pollInterval = pollInterval,
        super(const PanicAlertsLoading()) {
    on<PanicAlertsStarted>(_onStarted);
    on<PanicAlertsPollTicked>(_onTicked);
    on<PanicAlertsPaused>(_onPaused);
    on<PanicAlertsResumed>(_onResumed);
  }

  final ListPanicAlertsUsecase _listAlerts;
  final LocationGateway _locationGateway;
  final PanicAlertsTicker _ticker;
  final Duration _pollInterval;

  StreamSubscription<void>? _pollSub;
  GeoPoint? _position;

  Future<void> _onStarted(PanicAlertsStarted event, Emitter<PanicAlertsState> emit) async {
    _stopPolling();
    emit(const PanicAlertsLoading());
    final positionResult = await _locationGateway.currentPosition();
    if (emit.isDone) return;
    final locationFailure = positionResult.fold((f) => f, (_) => null);
    if (locationFailure != null) {
      emit(PanicAlertsError(locationFailure));
      return;
    }
    _position = positionResult.fold((_) => null, (p) => p);
    await _load(emit);
  }

  Future<void> _load(Emitter<PanicAlertsState> emit) async {
    final position = _position;
    if (position == null) return;
    final result =
        await _listAlerts(after: 0, limit: panicAlertsPageLimit, position: position);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(PanicAlertsError(failure)),
      (alerts) {
        emit(PanicAlertsLoaded(alerts: alerts));
        _startPolling();
      },
    );
  }

  Future<void> _onTicked(
    PanicAlertsPollTicked event,
    Emitter<PanicAlertsState> emit,
  ) async {
    final current = state;
    final position = _position;
    if (current is! PanicAlertsLoaded || position == null) return;
    final result = await _listAlerts(
      after: _lastId(current),
      limit: panicAlertsPageLimit,
      position: position,
    );
    if (emit.isDone) return;
    // A failed tick is transient: the inbox stays as it was, same posture
    // as `ChatConversationBloc._onTicked`.
    result.fold(
      (_) {},
      (page) {
        final latest = state;
        if (latest is! PanicAlertsLoaded) return;
        emit(PanicAlertsLoaded(alerts: _merge(latest.alerts, page)));
      },
    );
  }

  void _onPaused(PanicAlertsPaused event, Emitter<PanicAlertsState> emit) => _stopPolling();

  Future<void> _onResumed(
    PanicAlertsResumed event,
    Emitter<PanicAlertsState> emit,
  ) async {
    // Judgment call: refresh the position on resume (a fair "per visit"
    // moment), but best-effort — a transient failure keeps the last known
    // position rather than losing the whole screen over it.
    final positionResult = await _locationGateway.currentPosition();
    if (emit.isDone) return;
    positionResult.fold((_) {}, (point) => _position = point);
    _startPolling();
    add(const PanicAlertsPollTicked());
  }

  int _lastId(PanicAlertsLoaded loaded) =>
      loaded.alerts.map((a) => a.alertId).fold(0, (max, id) => id > max ? id : max);

  /// Appends only what is new — the server never re-serves an `alertId`
  /// already past the cursor, but this stays defensive against a replay.
  List<ResponderAlertEntity> _merge(
      List<ResponderAlertEntity> current, List<ResponderAlertEntity> served) {
    final merged = [...current];
    for (final alert in served) {
      if (merged.any((a) => a.alertId == alert.alertId)) continue;
      merged.add(alert);
    }
    return merged;
  }

  void _startPolling() {
    _pollSub?.cancel();
    _pollSub = _ticker(_pollInterval).listen((_) => add(const PanicAlertsPollTicked()));
  }

  void _stopPolling() {
    _pollSub?.cancel();
    _pollSub = null;
  }

  @override
  Future<void> close() async {
    _stopPolling();
    return super.close();
  }
}
