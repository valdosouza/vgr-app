import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../report/domain/gateway/location_gateway.dart';
import '../domain/entity/panic_entities.dart';
import '../domain/repository/panic_repository.dart';
import 'panic_local_store.dart';
import 'panic_queue_tasks.dart';

class PanicRepositoryImpl implements PanicRepository {
  PanicRepositoryImpl(
    this._apiClient,
    this._queue,
    this._localStore,
    this._locationGateway, {
    String Function()? clientKeyFactory,
  }) : _newClientKey = clientKeyFactory ?? (() => const Uuid().v4());

  final ApiClient _apiClient;
  final OfflineQueueService _queue;
  final PanicLocalStore _localStore;
  final LocationGateway _locationGateway;
  final String Function() _newClientKey;

  @override
  Future<int?> currentActiveAlertId() async => (await _localStore.activeAlert())?.alertId;

  @override
  Future<Either<Failure, TriggerOutcome>> trigger() async {
    final positionResult = await _locationGateway.currentPosition();
    // Cold trigger (65): no prior configuration, and a location failure
    // never reaches the API — the page surfaces the same retry
    // affordance `report_form_page.dart` already established.
    return positionResult.fold(
      (failure) async => Left(failure),
      (point) => _triggerAt(point),
    );
  }

  Future<Either<Failure, TriggerOutcome>> _triggerAt(GeoPoint point) async {
    // A fresh idempotency key per ATTEMPT (137), mirrors
    // `RatingRepositoryImpl.rateOffer`: a genuine retry after a real
    // refusal is its own new attempt, never a replay of a stale one.
    final clientKey = _newClientKey();
    try {
      final response = await _apiClient.post('/app-panic/alert', {
        'clientKey': clientKey,
        'position': {'lat': point.lat, 'lng': point.lng},
      });
      final alert = TriggeredAlertEntity.fromJson(response);
      // Bearer ownership (mirrors decision 134 applied to panic): this is
      // what lets THIS device call resolve() later, even after a restart.
      await _localStore.saveActiveAlert(alertId: alert.alertId, clientKey: clientKey);
      return Right(TriggerOutcome.online(alert));
    } on Failure catch (failure) {
      // The API judged (422/451, or 409 PANIC_ALERT_ACTIVE — 198): a
      // queued retry would fail identically — surface it, never enqueue.
      // A 409 here specifically means the SERVER already has an active
      // alert this device's LOCAL record does not know about (e.g. a
      // reinstalled app) — there is no reconstruction endpoint in PP1, so
      // this is a documented known gap (see `app/docs/feature/panic.md`):
      // the caller sees a clear translated message, never a crash.
      return Left(failure);
    } catch (_) {
      // Transport failure: the trigger survives offline (decision 28).
      // The alertId does not exist yet, so nothing is saved locally until
      // `PanicQueueTasks.trigger` actually lands it later.
      await _queue.enqueue(PanicQueueTasks.trigger, {
        'clientKey': clientKey,
        'lat': point.lat,
        'lng': point.lng,
      });
      // ignore: unawaited_futures
      _queue.flush();
      return const Right(TriggerOutcome.queued());
    }
  }

  @override
  Future<Either<Failure, void>> resolve(int alertId) async {
    final active = await _localStore.activeAlert();
    final clientKey = active?.alertId == alertId ? active?.clientKey : null;
    try {
      await _apiClient.post(
        '/app-panic/alerts/$alertId/resolve',
        const {},
        headers: clientKey == null ? null : {'x-client-key': clientKey},
      );
      await _localStore.clearActiveAlert();
      return const Right(null);
    } on Failure catch (failure) {
      // Judgment call (mirrors `report_queue_tasks.dart`'s
      // `_judgeResolve`): an ack that never reached this device after a
      // first resolve DID succeed lands here identically to a genuine
      // double-resolve. Either way the alert IS resolved, so this one
      // outcome clears the local record and is treated as success —
      // every other refusal (404 missing/not owner) surfaces as-is.
      if (failure.code == 'PANIC_ALERT_ALREADY_RESOLVED') {
        await _localStore.clearActiveAlert();
        return const Right(null);
      }
      return Left(failure);
    } catch (_) {
      // Transport failure: the resolve survives offline (decision 28 —
      // queued is a success, not an error) under the SAME alertId/
      // clientKey, so a replayed dispatch is answered by the API as a
      // resolve of the same alert.
      await _queue.enqueue(PanicQueueTasks.resolve, {
        'alertId': alertId,
        'clientKey': clientKey,
      });
      // ignore: unawaited_futures
      _queue.flush();
      await _localStore.clearActiveAlert();
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, List<ResponderAlertEntity>>> listAlerts({
    required int after,
    required int limit,
    required GeoPoint position,
  }) async {
    try {
      final response = await _apiClient.get(
        '/app-panic/alerts?after=$after&limit=$limit&lat=${position.lat}&lng=${position.lng}',
      );
      return Right((response['alerts'] as List<dynamic>)
          .map((a) => ResponderAlertEntity.fromJson((a as Map).cast<String, dynamic>()))
          .toList());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<bool> responderRequestAlreadySent() => _localStore.responderRequestSent();

  @override
  Future<Either<Failure, void>> requestResponderAuthorization() async {
    try {
      // No `criteriaNotes` collected this phase (193/194 keep per-user
      // configuration screens out of scope, decision 190).
      await _apiClient.post('/app-panic/responder-pool', const {});
      await _localStore.markResponderRequestSent();
      return const Right(null);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      // Read-adjacent, infrequent, identified-only action — no offline
      // queue, same posture as `getMyReputation`.
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }
}
