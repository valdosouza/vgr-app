import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_repository_impl.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_send_outcomes.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';
import 'package:vgr_mobile/app/shared/data/my_reports_store.dart';

class MockApiClient extends Mock implements ApiClient {}

const _thread = {
  'threadId': 9,
  'reportId': 5,
  'me': {'participantToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'role': 'reporter', 'displayName': null},
  'other': {'participantToken': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'role': 'helper', 'displayName': null},
  'lastMessageAt': null,
  'unreadCount': 0,
  'closed': false,
};

/// Paths, headers, query and JSON mapping of `/app-chat` (chat.md). The
/// anonymous reporter's ownership travels as `x-client-key` from
/// `MyReportsStore` exactly like the report detail (134/169); a logged-in
/// user carries the bearer through `ApiClient` itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient apiClient;
  late OfflineQueueService queue;
  late MyReportsStore myReports;
  late ChatSendOutcomes outcomes;
  late ChatRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    queue = OfflineQueueService(prefs: prefs);
    myReports = MyReportsStore(prefs: prefs);
    outcomes = ChatSendOutcomes();
    repository = ChatRepositoryImpl(
      apiClient,
      queue,
      myReports,
      outcomes,
      clientKeyFactory: () => 'ck-fixed',
      now: () => DateTime.utc(2026, 9, 3, 10, 0),
    );
  });

  tearDown(() => outcomes.dispose());

  group('listThreads', () {
    test('GET /app-chat/:reportId/threads with x-client-key when this device owns the report',
        () async {
      await myReports.save(5, 'key-5');
      when(() => apiClient.get('/app-chat/5/threads', headers: {'x-client-key': 'key-5'}))
          .thenAnswer((_) async => {'threads': [_thread]});

      final result = await repository.listThreads(5);

      final threads = result.getOrElse(() => throw StateError('left'));
      expect(threads.single.threadId, 9);
      expect(threads.single.other.role, ChatRole.helper);
      expect(threads.single.other.displayName, isNull);
    });

    test('no stored key → no header (a logged-in helper rides the bearer)', () async {
      when(() => apiClient.get('/app-chat/5/threads', headers: null))
          .thenAnswer((_) async => {'threads': []});

      final result = await repository.listThreads(5);

      expect(result.getOrElse(() => throw StateError('left')), isEmpty);
    });

    test('API refusal is a Left by code; transport failure is OFFLINE', () async {
      when(() => apiClient.get('/app-chat/5/threads', headers: null)).thenThrow(
          const Failure(message: 'nf', statusCode: 404, code: 'NOT_FOUND'));
      expect((await repository.listThreads(5)).fold((f) => f.code, (_) => null), 'NOT_FOUND');

      when(() => apiClient.get('/app-chat/5/threads', headers: null))
          .thenThrow(Exception('SocketException'));
      expect((await repository.listThreads(5)).fold((f) => f.code, (_) => null), 'OFFLINE');
    });
  });

  group('fetchMessages', () {
    test('GET /app-chat/threads/:threadId/messages?after=&limit= with the owner header',
        () async {
      await myReports.save(5, 'key-5');
      when(() => apiClient.get(
            '/app-chat/threads/9/messages?after=41&limit=50',
            headers: {'x-client-key': 'key-5'},
          )).thenAnswer((_) async => {
            'threadId': 9,
            'closed': false,
            'tier': 'medium',
            'messages': [
              {
                'messageId': 42,
                'clientKey': 'ck-9',
                'sender': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                'mine': false,
                'text': 'oi',
                'purged': false,
                'createdAt': '2026-09-03T10:15:00.000Z',
              },
            ],
          });

      final result = await repository.fetchMessages(9, reportId: 5, after: 41);

      final page = result.getOrElse(() => throw StateError('left'));
      expect(page.messages.single.messageId, 42);
      expect(page.messages.single.status, ChatMessageStatus.sent);
      expect(page.closed, isFalse);
    });

    test('defaults: after=0, limit=50, no header without a key', () async {
      when(() => apiClient.get('/app-chat/threads/9/messages?after=0&limit=50', headers: null))
          .thenAnswer((_) async =>
              {'threadId': 9, 'closed': true, 'tier': 'high', 'messages': []});

      final page = (await repository.fetchMessages(9, reportId: 5))
          .getOrElse(() => throw StateError('left'));

      expect(page.closed, isTrue);
      expect(page.messages, isEmpty);
    });
  });

  group('send (decision 172 — through the offline queue)', () {
    test('enqueues chat.post with an app-generated clientKey and answers the optimistic bubble',
        () async {
      final optimistic = await repository.send(reportId: 5, threadId: 9, text: 'oi');

      expect(optimistic.clientKey, 'ck-fixed');
      expect(optimistic.status, ChatMessageStatus.pending);
      expect(optimistic.mine, isTrue);
      expect(optimistic.text, 'oi');
      expect(optimistic.messageId, isNull);
      expect(optimistic.createdAt, '2026-09-03T10:00:00.000Z');
      // No handler registered here → the fire-and-forget flush leaves it.
      expect(await queue.pendingCount(), 1);
    });

    test('the payload carries reportId, threadId (null on a first message), clientKey, text',
        () async {
      final captured = <Map<String, dynamic>>[];
      queue.register(ChatQueueTasks.post, (payload) async {
        captured.add(payload);
        return QueueTaskResult.done;
      });

      await repository.send(reportId: 5, threadId: null, text: 'first');
      await queue.flush();

      expect(captured.single, {
        'reportId': 5,
        'threadId': null,
        'clientKey': 'ck-fixed',
        'text': 'first',
      });
    });

    test('never calls the API directly — the queue is the only path', () async {
      await repository.send(reportId: 5, threadId: 9, text: 'oi');
      verifyNever(() => apiClient.post(any(), any(), headers: any(named: 'headers')));
    });
  });
}
