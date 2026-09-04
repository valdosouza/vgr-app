import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/report/data/my_reports_store.dart';
import 'package:vgr_mobile/app/modules/report/data/report_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/report/data/report_repository_impl.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/feed_item_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/photo_draft.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_input.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_view_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';

class MockApiClient extends Mock implements ApiClient {}

ReportInput _input({List<PhotoDraft> photos = const []}) => ReportInput(
      clientKey: 'key-1',
      category: 'assault',
      subject: 'adult',
      lat: -23.5,
      lng: -46.6,
      anonymous: true,
      photos: photos,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient apiClient;
  late OfflineQueueService queue;
  late MyReportsStore myReports;
  late ReportRepositoryImpl repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    queue = OfflineQueueService(prefs: prefs);
    myReports = MyReportsStore(prefs: prefs);
    repository = ReportRepositoryImpl(apiClient, queue, myReports, prefs: prefs);
  });

  group('submit', () {
    test('online: posts to /app-reports and answers the accepted id', () async {
      when(() => apiClient.post('/app-reports', any()))
          .thenAnswer((_) async => {'reportId': 7, 'status': 'open'});

      final result = await repository.submit(_input());

      expect(result.getOrElse(() => throw StateError('left')),
          const SubmitOutcome.online(7));
      final body = verify(() => apiClient.post('/app-reports', captureAny()))
          .captured
          .single as Map<String, dynamic>;
      expect(body['clientKey'], 'key-1');
      // Bearer ownership persisted (decision 134): later reads of report 7
      // present this key.
      expect(await myReports.clientKeyOf(7), 'key-1');
    });

    test('online with photos: report never waits — photos ride the queue '
        '(decision 123)', () async {
      when(() => apiClient.post('/app-reports', any()))
          .thenAnswer((_) async => {'reportId': 7, 'status': 'open'});

      await repository.submit(_input(photos: const [
        PhotoDraft(path: '/tmp/a.jpg'),
        PhotoDraft(path: '/tmp/b.jpg', keepOriginal: true, exifWarningVersion: 'exif-warning/v1'),
      ]));

      // Handlers are not registered here, so the fire-and-forget flush
      // leaves both upload tasks visible.
      expect(await queue.pendingCount(), 2);
    });

    test('API rejection surfaces as Left and is NEVER enqueued (422 spec scenario)',
        () async {
      when(() => apiClient.post('/app-reports', any())).thenThrow(
        const Failure(message: 'Validation failed', statusCode: 422, code: 'VALIDATION_FAILED'),
      );

      final result = await repository.submit(_input());

      expect(result.isLeft(), isTrue);
      expect(await queue.pendingCount(), 0);
    });

    test('transport failure queues the WHOLE draft under the same clientKey '
        '(decisions 28/137)', () async {
      when(() => apiClient.post('/app-reports', any()))
          .thenThrow(Exception('SocketException'));

      final result = await repository.submit(_input(photos: const [
        PhotoDraft(path: '/tmp/a.jpg'),
      ]));

      expect(result.getOrElse(() => throw StateError('left')),
          const SubmitOutcome.queued());
      expect(await queue.pendingCount(), 1);
    });
  });

  group('getCategoryForms (decision 47)', () {
    const payload = {
      'forms': [
        {
          'category': 'missing',
          'fields': [
            {'name': 'age', 'type': 'number', 'required': true},
          ],
        },
      ],
    };

    test('serves the API catalog and caches it locally', () async {
      when(() => apiClient.get('/app-reports/category-forms'))
          .thenAnswer((_) async => payload);

      final result = await repository.getCategoryForms();

      final forms = result.getOrElse(() => throw StateError('left'));
      expect(forms.single.category, 'missing');
      expect(forms.single.fields.single.required_, isTrue);
    });

    test('offline: serves the cached catalog so the form renders (A1 contract)',
        () async {
      when(() => apiClient.get('/app-reports/category-forms'))
          .thenAnswer((_) async => payload);
      await repository.getCategoryForms(); // primes the cache

      when(() => apiClient.get('/app-reports/category-forms'))
          .thenThrow(Exception('SocketException'));
      final result = await repository.getCategoryForms();

      expect(result.getOrElse(() => throw StateError('left')).single.category, 'missing');
    });

    test('offline with no cache is a Left, not a crash', () async {
      when(() => apiClient.get('/app-reports/category-forms'))
          .thenThrow(Exception('SocketException'));

      final result = await repository.getCategoryForms();

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
    });
  });

  group('feed and detail reads (A2)', () {
    test('listNearby queries /app-feed with transient viewer position', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => {
            'items': [
              {
                'reportId': 3,
                'category': 'missing',
                'freeTag': null,
                'subject': 'child',
                'tier': 'medium',
                'position': {'lat': -23.505, 'lng': -46.605},
                'distanceKm': 1.5,
                'createdAt': '2026-08-04T18:15:00.000Z',
              },
            ],
            'page': 1,
            'hasMore': true,
            'order': 'recency',
          });

      final result = await repository.listNearby(
          const GeoPoint(lat: -23.5, lng: -46.6), 1, FeedOrder.recency);

      final page = result.getOrElse(() => throw StateError('left'));
      expect(page.items.single.reportId, 3);
      expect(page.hasMore, isTrue);
      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(path, '/app-feed?lat=-23.5&lng=-46.6&page=1&order=recency');
    });

    test('getReport presents the stored clientKey — bearer ownership (134)',
        () async {
      await myReports.save(9, 'key-9');
      when(() => apiClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => {
                'access': 'owner',
                'reportId': 9,
                'category': 'assault',
                'freeTag': null,
                'subject': 'adult',
                'tier': 'high',
                'status': 'open',
                'position': {'lat': -23.5, 'lng': -46.6},
                'detailFields': {'weapon': 'knife'},
                'createdAt': '2026-08-04T18:12:33.000Z',
                'resolvedAt': null,
                'timeline': [
                  {'eventType': 'created', 'payload': null, 'createdAt': '2026-08-04T18:12:33.000Z'},
                ],
                'media': [
                  {'publicId': 'pub-1', 'mime': 'image/webp', 'width': 320, 'height': 320},
                ],
                'offers': [],
              });

      final result = await repository.getReport(9);

      final view = result.getOrElse(() => throw StateError('left'));
      expect(view.access, ReportAccess.owner);
      expect(view.timeline!.single.eventType, 'created');
      final headers = verify(() => apiClient.get(any(), headers: captureAny(named: 'headers')))
          .captured
          .single as Map<String, String>;
      expect(headers['x-client-key'], 'key-9');
    });

    test('getReport for a report this device does not own sends no key', () async {
      when(() => apiClient.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => {
                'access': 'summary',
                'reportId': 4,
                'category': 'robbery',
                'freeTag': null,
                'subject': 'property',
                'tier': 'medium',
                'status': 'resolved',
                'resolvedAt': '2026-08-04T18:00:00.000Z',
              });

      final result = await repository.getReport(4);

      expect(result.getOrElse(() => throw StateError('left')).access,
          ReportAccess.summary);
      final headers = verify(() => apiClient.get(any(), headers: captureAny(named: 'headers')))
          .captured
          .single as Map<String, String>?;
      expect(headers, isNull);
    });
  });

  group('resolve (decisions 18/131/179)', () {
    test('online: posts to /app-reports/:id/resolve with the owner header', () async {
      await myReports.save(9, 'key-9');
      when(() => apiClient.post('/app-reports/9/resolve', const {},
              headers: {'x-client-key': 'key-9'}))
          .thenAnswer((_) async => {'reportId': 9, 'status': 'resolved'});

      final result = await repository.resolve(9);

      expect(result.isRight(), isTrue);
      verify(() => apiClient.post('/app-reports/9/resolve', const {},
          headers: {'x-client-key': 'key-9'})).called(1);
    });

    test('no stored key → no header (a logged-in owner rides the bearer)', () async {
      when(() => apiClient.post('/app-reports/9/resolve', const {}, headers: null))
          .thenAnswer((_) async => {'reportId': 9, 'status': 'resolved'});

      final result = await repository.resolve(9);

      expect(result.isRight(), isTrue);
    });

    test('API rejection (already resolved / non-owner) surfaces as Left, never enqueued',
        () async {
      when(() => apiClient.post('/app-reports/9/resolve', const {}, headers: null)).thenThrow(
        const Failure(
            message: 'Report is already resolved', statusCode: 422, code: 'BUSINESS_RULE'),
      );

      final result = await repository.resolve(9);

      expect(result.fold((f) => f.code, (_) => null), 'BUSINESS_RULE');
      expect(await queue.pendingCount(), 0);
    });

    test('transport failure queues the close under report_resolve (28)', () async {
      when(() => apiClient.post('/app-reports/9/resolve', const {}, headers: null))
          .thenThrow(Exception('SocketException'));

      final result = await repository.resolve(9);

      expect(result.isRight(), isTrue);
      expect(await queue.pendingCount(), 1);
    });
  });

  group('offline chain handlers (ReportQueueTasks)', () {
    test('queued draft drains submit → upload → attach in one flush, '
        'persisting ownership', () async {
      ReportQueueTasks.register(queue, apiClient, myReports: myReports);
      when(() => apiClient.post('/app-reports', any()))
          .thenAnswer((_) async => {'reportId': 9, 'status': 'open'});
      when(() => apiClient.postMultipart('/app-media',
              filePath: any(named: 'filePath'), fields: any(named: 'fields')))
          .thenAnswer((_) async => {'publicId': 'pub-1'});
      when(() => apiClient.post('/app-reports/9/media', any(),
              headers: any(named: 'headers')))
          .thenAnswer((_) async => {'replayed': false});

      await queue.enqueue(ReportQueueTasks.submit, _input(photos: const [
        PhotoDraft(path: '/tmp/a.jpg', keepOriginal: true, exifWarningVersion: 'exif-warning/v1'),
      ]).toJson());
      await queue.flush();

      expect(await queue.pendingCount(), 0);
      final fields = verify(() => apiClient.postMultipart('/app-media',
              filePath: any(named: 'filePath'), fields: captureAny(named: 'fields')))
          .captured
          .single as Map<String, String>;
      expect(fields['class'], 'evidence');
      expect(fields['keepOriginal'], 'true');
      expect(fields['exifWarningVersion'], 'exif-warning/v1');
      final headers = verify(() => apiClient.post('/app-reports/9/media', any(),
              headers: captureAny(named: 'headers')))
          .captured
          .single as Map<String, String>;
      // Bearer-secret ownership (decision 134) — header, never URL.
      expect(headers['x-client-key'], 'key-1');
      // The offline path persists ownership too (A2).
      expect(await myReports.clientKeyOf(9), 'key-1');
    });

    test('5xx keeps the task for retry; a judged refusal drops it', () async {
      ReportQueueTasks.register(queue, apiClient);
      when(() => apiClient.post('/app-reports', any()))
          .thenThrow(const Failure(message: 'boom', statusCode: 500));
      await queue.enqueue(ReportQueueTasks.submit, _input().toJson());

      await queue.flush();
      expect(await queue.pendingCount(), 1); // retried later

      when(() => apiClient.post('/app-reports', any())).thenThrow(
          const Failure(message: 'blocked', statusCode: 451, code: 'LEGAL_BLOCKED'));
      await queue.flush();
      expect(await queue.pendingCount(), 0); // dropped — retrying cannot succeed
    });
  });

  group('resolve queue task (ReportQueueTasks.resolve)', () {
    test('posts to /app-reports/:id/resolve with the owner header; done on success', () async {
      ReportQueueTasks.register(queue, apiClient, myReports: myReports);
      await myReports.save(9, 'key-9');
      when(() => apiClient.post('/app-reports/9/resolve', const {},
              headers: {'x-client-key': 'key-9'}))
          .thenAnswer((_) async => {'reportId': 9, 'status': 'resolved'});

      await queue.enqueue(ReportQueueTasks.resolve, {'reportId': 9});
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });

    test('5xx keeps the task for a later retry', () async {
      ReportQueueTasks.register(queue, apiClient);
      when(() => apiClient.post('/app-reports/9/resolve', const {}, headers: null))
          .thenThrow(const Failure(message: 'boom', statusCode: 500));

      await queue.enqueue(ReportQueueTasks.resolve, {'reportId': 9});
      await queue.flush();

      expect(await queue.pendingCount(), 1);
    });

    test('422 BUSINESS_RULE "already resolved" is treated as done — the ack that '
        'never arrived after a first attempt DID succeed, the goal is met either way',
        () async {
      ReportQueueTasks.register(queue, apiClient);
      when(() => apiClient.post('/app-reports/9/resolve', const {}, headers: null)).thenThrow(
          const Failure(
              message: 'Report is already resolved', statusCode: 422, code: 'BUSINESS_RULE'));

      await queue.enqueue(ReportQueueTasks.resolve, {'reportId': 9});
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });

    test('a genuine refusal (404 non-owner) is dropped, not retried forever', () async {
      ReportQueueTasks.register(queue, apiClient);
      when(() => apiClient.post('/app-reports/9/resolve', const {}, headers: null)).thenThrow(
          const Failure(message: 'nf', statusCode: 404, code: 'NOT_FOUND'));

      await queue.enqueue(ReportQueueTasks.resolve, {'reportId': 9});
      await queue.flush();

      expect(await queue.pendingCount(), 0);
    });
  });
}
