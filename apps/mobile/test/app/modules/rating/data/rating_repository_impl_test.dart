import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/rating/data/rating_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/rating/data/rating_repository_impl.dart';
import 'package:vgr_mobile/app/shared/data/my_reports_store.dart';

class MockApiClient extends Mock implements ApiClient {}

/// Paths, headers and the two-tier online/offline pattern of the RT2
/// write (`api/docs/feature/rating.md`) — mirrors `ReportRepositoryImpl`'s
/// `submit`/`resolve`: an API-judged refusal is a Left and is NEVER
/// enqueued (a retry would fail identically); a transport failure is the
/// one case that rides the offline queue (decision 181 — rating survives
/// offline exactly like a report submission does, 28).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient apiClient;
  late OfflineQueueService queue;
  late MyReportsStore myReports;
  late RatingRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    queue = OfflineQueueService(prefs: prefs);
    myReports = MyReportsStore(prefs: prefs);
    repository = RatingRepositoryImpl(
      apiClient,
      queue,
      myReports,
      clientKeyFactory: () => 'ck-fixed',
    );
  });

  group('rateOffer', () {
    test('online: posts score + a fresh clientKey with the owner header', () async {
      await myReports.save(5, 'key-5');
      when(() => apiClient.post(
            '/app-reports/5/offers/9/rating',
            {'score': 4, 'clientKey': 'ck-fixed'},
            headers: {'x-client-key': 'key-5'},
          )).thenAnswer((_) async => {
            'ratingId': 1,
            'reportId': 5,
            'helpOfferId': 9,
            'score': 4,
            'createdAt': '2026-09-04T10:00:00.000Z',
          });

      final result = await repository.rateOffer(reportId: 5, offerId: 9, score: 4);

      final outcome = result.getOrElse(() => throw StateError('left'));
      expect(outcome.queued, isFalse);
      expect(outcome.rating!.ratingId, 1);
      expect(outcome.rating!.score, 4);
    });

    test('no stored key → no header (a logged-in owner rides the bearer)', () async {
      when(() => apiClient.post('/app-reports/5/offers/9/rating', any(), headers: null))
          .thenAnswer((_) async => {
                'ratingId': 1,
                'reportId': 5,
                'helpOfferId': 9,
                'score': 3,
                'createdAt': '2026-09-04T10:00:00.000Z',
              });

      final result = await repository.rateOffer(reportId: 5, offerId: 9, score: 3);

      expect(result.isRight(), isTrue);
    });

    for (final judged in const [
      (404, 'NOT_FOUND'),
      (409, 'ALREADY_RATED'),
      (409, 'RATING_CLOSED'),
      (422, 'RATING_NOT_ALLOWED'),
      (451, 'LEGAL_BLOCKED'),
    ]) {
      test('${judged.$1} ${judged.$2}: a Left the caller surfaces, NEVER enqueued', () async {
        when(() => apiClient.post(any(), any(), headers: any(named: 'headers'))).thenThrow(
            Failure(message: 'judged', statusCode: judged.$1, code: judged.$2));

        final result = await repository.rateOffer(reportId: 5, offerId: 9, score: 4);

        expect(result.fold((f) => f.code, (_) => null), judged.$2);
        expect(await queue.pendingCount(), 0);
      });
    }

    test('transport failure enqueues rating_submit and answers queued (decision 181)',
        () async {
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(Exception('SocketException'));

      final result = await repository.rateOffer(reportId: 5, offerId: 9, score: 4);

      final outcome = result.getOrElse(() => throw StateError('left'));
      expect(outcome.queued, isTrue);
      expect(outcome.rating, isNull);
      expect(await queue.pendingCount(), 1);
    });

    test('each attempt generates its own clientKey — never reuses a stale one', () async {
      var calls = 0;
      final keys = <String>[];
      final repo = RatingRepositoryImpl(
        apiClient,
        queue,
        myReports,
        clientKeyFactory: () => 'ck-${++calls}',
      );
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenAnswer((invocation) async {
        keys.add((invocation.positionalArguments[1] as Map)['clientKey'] as String);
        return {
          'ratingId': 1,
          'reportId': 5,
          'helpOfferId': 9,
          'score': 4,
          'createdAt': 'now',
        };
      });

      await repo.rateOffer(reportId: 5, offerId: 9, score: 4);
      await repo.rateOffer(reportId: 5, offerId: 10, score: 5);

      expect(keys, ['ck-1', 'ck-2']);
    });
  });

  group('getMyReputation (decisions 184/185)', () {
    test('GET /app-ratings/me — no per-case argument, no id anywhere', () async {
      when(() => apiClient.get('/app-ratings/me'))
          .thenAnswer((_) async => {'count': 7, 'average': 4.29});

      final result = await repository.getMyReputation();

      final reputation = result.getOrElse(() => throw StateError('left'));
      expect(reputation.count, 7);
      expect(reputation.average, 4.29);
    });

    test('below the floor: average null, rendered as-is (never recomputed)', () async {
      when(() => apiClient.get('/app-ratings/me'))
          .thenAnswer((_) async => {'count': 2, 'average': null});

      final result = await repository.getMyReputation();

      expect(result.getOrElse(() => throw StateError('left')).average, isNull);
    });

    test('401 anonymous (never optional) surfaces as a Left by code', () async {
      when(() => apiClient.get('/app-ratings/me')).thenThrow(
          const Failure(message: 'unauth', statusCode: 401, code: 'UNAUTHORIZED'));

      final result = await repository.getMyReputation();

      expect(result.fold((f) => f.code, (_) => null), 'UNAUTHORIZED');
    });

    test('transport failure is OFFLINE, never enqueued (read-only, no queue for a GET)',
        () async {
      when(() => apiClient.get('/app-ratings/me')).thenThrow(Exception('SocketException'));

      final result = await repository.getMyReputation();

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
      expect(await queue.pendingCount(), 0);
    });
  });

  group('rating_submit queue task (RatingQueueTasks)', () {
    test('replays the same clientKey the repository generated', () async {
      RatingQueueTasks.register(queue, apiClient, myReports: myReports);
      await myReports.save(5, 'key-5');
      when(() => apiClient.post(
            '/app-reports/5/offers/9/rating',
            {'score': 4, 'clientKey': 'ck-fixed'},
            headers: {'x-client-key': 'key-5'},
          )).thenAnswer((_) async => {
            'ratingId': 1,
            'reportId': 5,
            'helpOfferId': 9,
            'score': 4,
            'createdAt': 'now',
          });

      await queue.enqueue(RatingQueueTasks.submit, {
        'reportId': 5,
        'offerId': 9,
        'score': 4,
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });

    test('5xx keeps the task for a later retry', () async {
      RatingQueueTasks.register(queue, apiClient);
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenThrow(const Failure(message: 'boom', statusCode: 500));

      await queue.enqueue(RatingQueueTasks.submit, {
        'reportId': 5,
        'offerId': 9,
        'score': 4,
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });

    test('a judged refusal (409 ALREADY_RATED) is dropped, not retried forever', () async {
      RatingQueueTasks.register(queue, apiClient);
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers'))).thenThrow(
          const Failure(message: 'dup', statusCode: 409, code: 'ALREADY_RATED'));

      await queue.enqueue(RatingQueueTasks.submit, {
        'reportId': 5,
        'offerId': 9,
        'score': 4,
        'clientKey': 'ck-fixed',
      });
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });
  });
}
