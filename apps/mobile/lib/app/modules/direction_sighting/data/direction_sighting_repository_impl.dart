import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../domain/entity/direction_sighting_entities.dart';
import '../domain/repository/direction_sighting_repository.dart';
import 'direction_sighting_local_store.dart';
import 'direction_sighting_queue_tasks.dart';

class DirectionSightingRepositoryImpl implements DirectionSightingRepository {
  DirectionSightingRepositoryImpl(
    this._apiClient,
    this._queue,
    this._localStore, {
    String Function()? clientKeyFactory,
  }) : _newClientKey = clientKeyFactory ?? (() => const Uuid().v4());

  final ApiClient _apiClient;
  final OfflineQueueService _queue;
  final DirectionSightingLocalStore _localStore;
  final String Function() _newClientKey;

  @override
  Future<Either<Failure, SightOutcome>> logSighting({
    required int reportId,
    required Direction direction,
  }) async {
    // This sighting's OWN idempotency key (decision 137) — unlike a
    // report/offer clientKey, it never doubles as a bearer secret: a
    // sighting is append-only, never resolved or edited later.
    final clientKey = _newClientKey();
    try {
      final response = await _apiClient.post('/app-direction-sightings', {
        'reportId': reportId,
        'direction': direction.wire,
        'clientKey': clientKey,
      });
      // Soft, UX-only spam mitigation (see `DirectionSightingLocalStore`'s
      // own doc) — recorded right away so the picker never re-offers
      // itself on this device.
      await _localStore.saveSighting(reportId: reportId, direction: direction);
      return Right(SightOutcome.online(DirectionSightingResult.fromJson(response)));
    } on Failure catch (failure) {
      // The API judged (404/422 DIRECTION_SIGHTING_NOT_ELIGIBLE/422
      // BUSINESS_RULE/451): nothing was recorded — a queued retry would
      // fail identically, surface it, never enqueue (same rule as every
      // other write in this app).
      return Left(failure);
    } catch (_) {
      // Transport failure: the sighting survives offline (decision 28)
      // under this clientKey. Recorded LOCALLY right away too — a
      // revisit before the queue flushes must not re-offer the picker
      // and risk a second, different-direction submission from the same
      // device.
      await _queue.enqueue(DirectionSightingQueueTasks.submit, {
        'reportId': reportId,
        'direction': direction.wire,
        'clientKey': clientKey,
      });
      await _localStore.saveSighting(reportId: reportId, direction: direction);
      // Fire-and-forget: kick the flush now, the periodic retry self-heals.
      // ignore: unawaited_futures
      _queue.flush();
      return const Right(SightOutcome.queued());
    }
  }
}
