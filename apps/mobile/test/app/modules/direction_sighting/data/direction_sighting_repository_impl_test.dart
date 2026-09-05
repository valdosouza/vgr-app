import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/data/direction_sighting_local_store.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/data/direction_sighting_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/data/direction_sighting_repository_impl.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Paths and the two-tier online/offline pattern of the DS2 write
/// (`api/docs/feature/direction-sightings.md`) — mirrors
/// `RatingRepositoryImpl` exactly: an API-judged refusal is a Left and is
/// NEVER enqueued (a retry would fail identically); a transport failure
/// rides the offline queue (decision 28 — a sighting survives offline
/// exactly like every other write in this app).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient apiClient;
  late OfflineQueueService queue;
  late DirectionSightingLocalStore localStore;
  late DirectionSightingRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    queue = OfflineQueueService(prefs: prefs);
    localStore = DirectionSightingLocalStore(prefs: prefs);
    repository = DirectionSightingRepositoryImpl(
      apiClient,
      queue,
      localStore,
      clientKeyFactory: () => 'ck-fixed',
    );
  });

  group('logSighting', () {
    test('online: posts reportId + direction + a fresh clientKey', () async {
      when(() => apiClient.post('/app-direction-sightings', {
            'reportId': 7,
            'direction': 'N',
            'clientKey': 'ck-fixed',
          })).thenAnswer((_) async => {
            'sightingId': 501,
            'reportId': 7,
            'estimate': 'N',
            'count': 6,
          });

      final result = await repository.logSighting(reportId: 7, direction: Direction.n);

      final outcome = result.getOrElse(() => throw StateError('left'));
      expect(outcome.queued, isFalse);
      expect(outcome.result!.sightingId, 501);
      expect(outcome.result!.estimate, Direction.n);
      expect(outcome.result!.count, 6);
    });

    test('online success records the local "already sighted" mark right away', () async {
      when(() => apiClient.post(any(), any())).thenAnswer((_) async => {
            'sightingId': 1,
            'reportId': 7,
            'estimate': 'N',
            'count': 1,
          });

      await repository.logSighting(reportId: 7, direction: Direction.n);

      expect(await localStore.sightingFor(7), Direction.n);
    });

    for (final judged in const [
      (404, 'NOT_FOUND'),
      (422, 'DIRECTION_SIGHTING_NOT_ELIGIBLE'),
      (422, 'BUSINESS_RULE'),
      (451, 'LEGAL_BLOCKED'),
    ]) {
      test('${judged.$1} ${judged.$2}: a Left the caller surfaces, NEVER enqueued, '
          'nothing recorded locally', () async {
        when(() => apiClient.post(any(), any())).thenThrow(
            Failure(message: 'judged', statusCode: judged.$1, code: judged.$2));

        final result = await repository.logSighting(reportId: 7, direction: Direction.n);

        expect(result.fold((f) => f.code, (_) => null), judged.$2);
        expect(await queue.pendingCount(), 0);
        expect(await localStore.sightingFor(7), isNull);
      });
    }

    test('transport failure enqueues direction_sighting_submit, answers queued, and '
        'records the local mark right away (decision 28 — a revisit before the flush '
        'must not re-offer the picker)', () async {
      when(() => apiClient.post(any(), any())).thenThrow(Exception('SocketException'));

      final result = await repository.logSighting(reportId: 7, direction: Direction.sw);

      final outcome = result.getOrElse(() => throw StateError('left'));
      expect(outcome.queued, isTrue);
      expect(outcome.result, isNull);
      expect(await queue.pendingCount(), 1);
      expect(await localStore.sightingFor(7), Direction.sw);
    });

    test('each attempt generates its own clientKey', () async {
      var calls = 0;
      final keys = <String>[];
      final repo = DirectionSightingRepositoryImpl(
        apiClient,
        queue,
        localStore,
        clientKeyFactory: () => 'ck-${++calls}',
      );
      when(() => apiClient.post(any(), any())).thenAnswer((invocation) async {
        keys.add((invocation.positionalArguments[1] as Map)['clientKey'] as String);
        return {'sightingId': 1, 'reportId': 7, 'estimate': 'N', 'count': 1};
      });

      await repo.logSighting(reportId: 7, direction: Direction.n);
      await repo.logSighting(reportId: 8, direction: Direction.s);

      expect(keys, ['ck-1', 'ck-2']);
    });
  });

  group('direction_sighting_submit queue task (DirectionSightingQueueTasks)', () {
    test('replays the same clientKey the repository generated and records the local mark',
        () async {
      DirectionSightingQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post('/app-direction-sightings', {
            'reportId': 7,
            'direction': 'E',
            'clientKey': 'ck-fixed',
          })).thenAnswer((_) async => {
            'sightingId': 1,
            'reportId': 7,
            'estimate': 'E',
            'count': 2,
          });

      await queue.enqueue(DirectionSightingQueueTasks.submit, {
        'reportId': 7,
        'direction': 'E',
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
      expect(await localStore.sightingFor(7), Direction.e);
    });

    test('5xx keeps the task for a later retry', () async {
      DirectionSightingQueueTasks.register(queue, apiClient);
      when(() => apiClient.post(any(), any()))
          .thenThrow(const Failure(message: 'boom', statusCode: 500));

      await queue.enqueue(DirectionSightingQueueTasks.submit, {
        'reportId': 7,
        'direction': 'E',
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });

    test('a judged refusal (422 BUSINESS_RULE) is dropped, not retried forever', () async {
      DirectionSightingQueueTasks.register(queue, apiClient);
      when(() => apiClient.post(any(), any())).thenThrow(
          const Failure(message: 'resolved', statusCode: 422, code: 'BUSINESS_RULE'));

      await queue.enqueue(DirectionSightingQueueTasks.submit, {
        'reportId': 7,
        'direction': 'E',
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });

    test('localStore is optional — a missing one never crashes the handler', () async {
      DirectionSightingQueueTasks.register(queue, apiClient);
      when(() => apiClient.post(any(), any())).thenAnswer((_) async => {
            'sightingId': 1,
            'reportId': 7,
            'estimate': 'E',
            'count': 2,
          });

      await queue.enqueue(DirectionSightingQueueTasks.submit, {
        'reportId': 7,
        'direction': 'E',
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });
  });
}
