import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/report/data/report_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/report/data/report_repository_impl.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/photo_draft.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_input.dart';

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
  late ReportRepositoryImpl repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    queue = OfflineQueueService(prefs: prefs);
    repository = ReportRepositoryImpl(apiClient, queue, prefs: prefs);
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

  group('offline chain handlers (ReportQueueTasks)', () {
    test('queued draft drains submit → upload → attach in one flush', () async {
      ReportQueueTasks.register(queue, apiClient);
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
}
