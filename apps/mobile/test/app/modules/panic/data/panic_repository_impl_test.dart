import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/panic/data/panic_local_store.dart';
import 'package:vgr_mobile/app/modules/panic/data/panic_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/panic/data/panic_repository_impl.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocationGateway extends Mock implements LocationGateway {}

/// Paths, headers and the two-tier online/offline pattern of the PP2
/// write/read surface (`api/docs/feature/panic.md`) — mirrors
/// `ReportRepositoryImpl`/`RatingRepositoryImpl`: an API-judged refusal is
/// a Left and is NEVER enqueued; a transport failure is the one case that
/// rides the offline queue (decision 28).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient apiClient;
  late MockLocationGateway locationGateway;
  late OfflineQueueService queue;
  late PanicLocalStore localStore;
  late PanicRepositoryImpl repository;

  const point = GeoPoint(lat: -23.55, lng: -46.63);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    locationGateway = MockLocationGateway();
    queue = OfflineQueueService(prefs: prefs);
    localStore = PanicLocalStore(prefs: prefs);
    repository = PanicRepositoryImpl(
      apiClient,
      queue,
      localStore,
      locationGateway,
      clientKeyFactory: () => 'ck-fixed',
    );
  });

  group('currentActiveAlertId (no PP1 read endpoint — local bookkeeping only)', () {
    test('nothing remembered -> null', () async {
      expect(await repository.currentActiveAlertId(), isNull);
    });

    test('mirrors whatever the local store currently holds', () async {
      await localStore.saveActiveAlert(alertId: 42, clientKey: 'ck-42');

      expect(await repository.currentActiveAlertId(), 42);
    });
  });

  group('trigger', () {
    test('location failure: Left, the API is NEVER called (65)', () async {
      when(() => locationGateway.currentPosition()).thenAnswer(
          (_) async => const Left(Failure(message: 'off', code: 'LOCATION_OFF')));

      final result = await repository.trigger();

      expect(result.fold((f) => f.code, (_) => null), 'LOCATION_OFF');
      verifyNever(() => apiClient.post(any(), any(), headers: any(named: 'headers')));
    });

    test('online: posts clientKey + position, saves {alertId, clientKey} locally', () async {
      when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(point));
      when(() => apiClient.post('/app-panic/alert', {
            'clientKey': 'ck-fixed',
            'position': {'lat': point.lat, 'lng': point.lng},
          })).thenAnswer((_) async => {
            'alertId': 42,
            'createdAt': '2026-09-04T10:00:00.000Z',
            'recipientCount': 3,
          });

      final result = await repository.trigger();

      final outcome = result.getOrElse(() => throw StateError('left'));
      expect(outcome.queued, isFalse);
      expect(outcome.alert!.alertId, 42);
      expect(outcome.alert!.recipientCount, 3);

      final saved = await localStore.activeAlert();
      expect(saved!.alertId, 42);
      expect(saved.clientKey, 'ck-fixed');
    });

    for (final judged in const [
      (409, 'PANIC_ALERT_ACTIVE'),
      (422, 'VALIDATION_FAILED'),
      (451, 'LEGAL_BLOCKED'),
    ]) {
      test('${judged.$1} ${judged.$2}: a Left the caller surfaces, NEVER enqueued', () async {
        when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(point));
        when(() => apiClient.post(any(), any(), headers: any(named: 'headers'))).thenThrow(
            Failure(message: 'judged', statusCode: judged.$1, code: judged.$2));

        final result = await repository.trigger();

        expect(result.fold((f) => f.code, (_) => null), judged.$2);
        expect(await queue.pendingCount(), 0);
        expect(await localStore.activeAlert(), isNull);
      });
    }

    test('transport failure enqueues panic_alert_trigger and answers queued (decision 28)',
        () async {
      when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(point));
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(Exception('SocketException'));

      final result = await repository.trigger();

      final outcome = result.getOrElse(() => throw StateError('left'));
      expect(outcome.queued, isTrue);
      expect(outcome.alert, isNull);
      expect(await queue.pendingCount(), 1);
      // The alertId does not exist yet — nothing to save locally until
      // the queue task actually lands it.
      expect(await localStore.activeAlert(), isNull);
    });

    test('each attempt generates its own clientKey — never reuses a stale one', () async {
      when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(point));
      var calls = 0;
      final keys = <String>[];
      final repo = PanicRepositoryImpl(
        apiClient,
        queue,
        localStore,
        locationGateway,
        clientKeyFactory: () => 'ck-${++calls}',
      );
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenAnswer((invocation) async {
        keys.add((invocation.positionalArguments[1] as Map)['clientKey'] as String);
        return {'alertId': 1, 'createdAt': 'now', 'recipientCount': 0};
      });

      await repo.trigger();
      await repo.trigger();

      expect(keys, ['ck-1', 'ck-2']);
    });
  });

  group('resolve', () {
    test('anonymous trigger: sends x-client-key from the local record, clears it on success',
        () async {
      await localStore.saveActiveAlert(alertId: 42, clientKey: 'ck-42');
      when(() => apiClient.post('/app-panic/alerts/42/resolve', const {},
              headers: {'x-client-key': 'ck-42'}))
          .thenAnswer((_) async => {'alertId': 42, 'status': 'resolved'});

      final result = await repository.resolve(42);

      expect(result.isRight(), isTrue);
      expect(await localStore.activeAlert(), isNull);
    });

    test('identified trigger: no local clientKey -> no header (session bearer owns it)',
        () async {
      when(() => apiClient.post('/app-panic/alerts/42/resolve', const {}, headers: null))
          .thenAnswer((_) async => {'alertId': 42, 'status': 'resolved'});

      final result = await repository.resolve(42);

      expect(result.isRight(), isTrue);
    });

    test('409 PANIC_ALERT_ALREADY_RESOLVED: treated as an effective success, clears the '
        'local record too', () async {
      await localStore.saveActiveAlert(alertId: 42, clientKey: 'ck-42');
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers'))).thenThrow(
          const Failure(
              message: 'already', statusCode: 409, code: 'PANIC_ALERT_ALREADY_RESOLVED'));

      final result = await repository.resolve(42);

      expect(result.isRight(), isTrue);
      expect(await localStore.activeAlert(), isNull);
    });

    test('404 NOT_FOUND (missing or not owner): a Left, local record untouched', () async {
      await localStore.saveActiveAlert(alertId: 42, clientKey: 'ck-42');
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(const Failure(message: 'nf', statusCode: 404, code: 'NOT_FOUND'));

      final result = await repository.resolve(42);

      expect(result.fold((f) => f.code, (_) => null), 'NOT_FOUND');
      expect(await localStore.activeAlert(), isNotNull);
    });

    test('transport failure enqueues panic_alert_resolve and clears the local record right '
        'away (decision 28 — queued is a success, not an error)', () async {
      await localStore.saveActiveAlert(alertId: 42, clientKey: 'ck-42');
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(Exception('SocketException'));

      final result = await repository.resolve(42);

      expect(result.isRight(), isTrue);
      expect(await localStore.activeAlert(), isNull);
      expect(await queue.pendingCount(), 1);
    });
  });

  group('listAlerts', () {
    test('GET with the responder\'s own position, cursor and limit forwarded', () async {
      when(() => apiClient.get('/app-panic/alerts?after=0&limit=20&lat=${point.lat}&lng=${point.lng}'))
          .thenAnswer((_) async => {
                'alerts': [
                  {'alertId': 7, 'distanceKm': 2.0, 'createdAt': 'now', 'resolved': false},
                ],
              });

      final result =
          await repository.listAlerts(after: 0, limit: 20, position: point);

      final alerts = result.getOrElse(() => throw StateError('left'));
      expect(alerts, hasLength(1));
      expect(alerts.single.alertId, 7);
    });

    test('a judged failure (401 anonymous) is a Left', () async {
      when(() => apiClient.get(any())).thenThrow(
          const Failure(message: 'unauth', statusCode: 401, code: 'UNAUTHORIZED'));

      final result = await repository.listAlerts(after: 0, limit: 20, position: point);

      expect(result.fold((f) => f.code, (_) => null), 'UNAUTHORIZED');
    });

    test('transport failure is OFFLINE, never enqueued (read-only)', () async {
      when(() => apiClient.get(any())).thenThrow(Exception('SocketException'));

      final result = await repository.listAlerts(after: 0, limit: 20, position: point);

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
      expect(await queue.pendingCount(), 0);
    });
  });

  group('responderRequestAlreadySent (local bookkeeping only)', () {
    test('mirrors whatever the local store currently holds', () async {
      expect(await repository.responderRequestAlreadySent(), isFalse);

      await localStore.markResponderRequestSent();

      expect(await repository.responderRequestAlreadySent(), isTrue);
    });
  });

  group('requestResponderAuthorization (decision 190)', () {
    test('online success marks the local "already sent" flag', () async {
      when(() => apiClient.post('/app-panic/responder-pool', const {})).thenAnswer((_) async => {
            'id': 3,
            'userId': 11,
            'status': 'pending',
            'criteriaNotes': null,
            'requestedAt': 'now',
            'resolvedAt': null,
            'resolvedBy': null,
          });

      final result = await repository.requestResponderAuthorization();

      expect(result.isRight(), isTrue);
      expect(await localStore.responderRequestSent(), isTrue);
    });

    test('a judged failure never marks the flag', () async {
      when(() => apiClient.post(any(), any())).thenThrow(
          const Failure(message: 'unauth', statusCode: 401, code: 'UNAUTHORIZED'));

      final result = await repository.requestResponderAuthorization();

      expect(result.fold((f) => f.code, (_) => null), 'UNAUTHORIZED');
      expect(await localStore.responderRequestSent(), isFalse);
    });

    test('transport failure is OFFLINE, never enqueued, flag not marked', () async {
      when(() => apiClient.post(any(), any())).thenThrow(Exception('SocketException'));

      final result = await repository.requestResponderAuthorization();

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
      expect(await queue.pendingCount(), 0);
      expect(await localStore.responderRequestSent(), isFalse);
    });
  });

  group('panic_alert_trigger queue task (PanicQueueTasks)', () {
    test('on flush success, saves {alertId, clientKey} the repository could not know yet',
        () async {
      PanicQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post('/app-panic/alert', {
            'clientKey': 'ck-queued',
            'position': {'lat': point.lat, 'lng': point.lng},
          })).thenAnswer((_) async => {
            'alertId': 99,
            'createdAt': 'now',
            'recipientCount': 1,
          });

      await queue.enqueue(PanicQueueTasks.trigger, {
        'clientKey': 'ck-queued',
        'lat': point.lat,
        'lng': point.lng,
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
      final saved = await localStore.activeAlert();
      expect(saved!.alertId, 99);
      expect(saved.clientKey, 'ck-queued');
    });

    test('5xx keeps the task for a later retry', () async {
      PanicQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(const Failure(message: 'boom', statusCode: 500));

      await queue.enqueue(PanicQueueTasks.trigger, {
        'clientKey': 'ck-queued',
        'lat': point.lat,
        'lng': point.lng,
      });
      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });

    test('a judged refusal (409 PANIC_ALERT_ACTIVE) is dropped, not retried forever', () async {
      PanicQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers'))).thenThrow(
          const Failure(message: 'active', statusCode: 409, code: 'PANIC_ALERT_ACTIVE'));

      await queue.enqueue(PanicQueueTasks.trigger, {
        'clientKey': 'ck-queued',
        'lat': point.lat,
        'lng': point.lng,
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
      expect(await localStore.activeAlert(), isNull);
    });
  });

  group('panic_alert_resolve queue task (PanicQueueTasks)', () {
    test('replays the resolve with the queued clientKey header', () async {
      PanicQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post('/app-panic/alerts/42/resolve', const {},
              headers: {'x-client-key': 'ck-42'}))
          .thenAnswer((_) async => {'alertId': 42, 'status': 'resolved'});

      await queue.enqueue(PanicQueueTasks.resolve, {'alertId': 42, 'clientKey': 'ck-42'});
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });

    test('409 PANIC_ALERT_ALREADY_RESOLVED is treated as done, not retried', () async {
      PanicQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers'))).thenThrow(
          const Failure(
              message: 'already', statusCode: 409, code: 'PANIC_ALERT_ALREADY_RESOLVED'));

      await queue.enqueue(PanicQueueTasks.resolve, {'alertId': 42, 'clientKey': 'ck-42'});
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });

    test('5xx keeps the task for a later retry', () async {
      PanicQueueTasks.register(queue, apiClient, localStore: localStore);
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(const Failure(message: 'boom', statusCode: 500));

      await queue.enqueue(PanicQueueTasks.resolve, {'alertId': 42, 'clientKey': 'ck-42'});
      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });
  });
}
