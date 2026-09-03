import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_queue_tasks.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_send_outcomes.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';
import 'package:vgr_mobile/app/modules/report/data/my_reports_store.dart';

class MockApiClient extends Mock implements ApiClient {}

const _served = {
  'messageId': 42,
  'clientKey': 'ck-1',
  'sender': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'mine': true,
  'text': 'oi',
  'purged': false,
  'createdAt': '2026-09-03T10:15:00.000Z',
};

/// The `chat.post` handler (decision 172): posts to the thread route or,
/// on a helper's first message, to the report route (173); 201 and a 200
/// replay both settle the bubble; 422/409/451 were JUDGED by the API —
/// the bubble fails and the task is dropped, never retried (same rule as
/// `report_queue_tasks.dart`); 5xx keeps the task.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiClient apiClient;
  late OfflineQueueService queue;
  late MyReportsStore myReports;
  late ChatSendOutcomes outcomes;
  late List<ChatSendOutcome> received;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    apiClient = MockApiClient();
    queue = OfflineQueueService(prefs: prefs);
    myReports = MyReportsStore(prefs: prefs);
    outcomes = ChatSendOutcomes();
    received = [];
    outcomes.stream.listen(received.add);
    ChatQueueTasks.register(queue, apiClient, myReports, outcomes: outcomes);
  });

  tearDown(() => outcomes.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Map<String, dynamic> payload({int? threadId = 9}) => {
        'reportId': 5,
        'threadId': threadId,
        'clientKey': 'ck-1',
        'text': 'oi',
      };

  test('posts to /app-chat/threads/:threadId/messages with x-client-key from the store; '
      '201 settles the bubble', () async {
    await myReports.save(5, 'key-5');
    when(() => apiClient.post(
          '/app-chat/threads/9/messages',
          {'clientKey': 'ck-1', 'text': 'oi'},
          headers: {'x-client-key': 'key-5'},
        )).thenAnswer((_) async => {'threadId': 9, 'message': _served});

    await queue.enqueue(ChatQueueTasks.post, payload());
    await queue.flush();
    await settle();

    expect(await queue.pendingCount(), 0);
    final settled = received.single as ChatSendSettled;
    expect(settled.clientKey, 'ck-1');
    expect(settled.threadId, 9);
    expect(settled.message.messageId, 42);
    expect(settled.message.status, ChatMessageStatus.sent);
  });

  test('threadId null → POST /app-chat/:reportId/messages (helper\'s first message, 173); '
      'no key → no header', () async {
    when(() => apiClient.post(
          '/app-chat/5/messages',
          {'clientKey': 'ck-1', 'text': 'oi'},
          headers: null,
        )).thenAnswer((_) async => {'threadId': 12, 'message': _served});

    await queue.enqueue(ChatQueueTasks.post, payload(threadId: null));
    await queue.flush();
    await settle();

    expect((received.single as ChatSendSettled).threadId, 12);
  });

  test('a 200 replay settles exactly like a 201 (137/172)', () async {
    when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => {'threadId': 9, 'message': _served, 'replayed': true});

    await queue.enqueue(ChatQueueTasks.post, payload());
    await queue.flush();
    await settle();

    expect(received.single, isA<ChatSendSettled>());
  });

  for (final judged in const [
    (422, 'CONTACT_NOT_ALLOWED'),
    (409, 'CHAT_CLOSED'),
    (451, 'LEGAL_BLOCKED'),
  ]) {
    test('${judged.$1} ${judged.$2}: bubble fails with the code, task dropped, no retry',
        () async {
      var calls = 0;
      when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
          .thenAnswer((_) async {
        calls++;
        throw Failure(
          message: 'judged',
          statusCode: judged.$1,
          code: judged.$2,
          fields: judged.$1 == 422
              ? const [
                  FieldFailure(field: 'text', message: 'x', code: 'CONTACT_NOT_ALLOWED',
                      params: {'kind': 'phone', 'match': '91234567'}),
                ]
              : null,
        );
      });

      await queue.enqueue(ChatQueueTasks.post, payload());
      await queue.flush();
      await queue.flush();
      await settle();

      expect(calls, 1);
      expect(await queue.pendingCount(), 0);
      final failed = received.single as ChatSendFailed;
      expect(failed.clientKey, 'ck-1');
      expect(failed.failure.code, judged.$2);
    });
  }

  test('5xx keeps the task for a later flush and publishes nothing', () async {
    when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
        .thenThrow(const Failure(message: 'boom', statusCode: 503, code: 'INTERNAL'));

    await queue.enqueue(ChatQueueTasks.post, payload());
    await queue.flush();
    await settle();

    expect(await queue.pendingCount(), 1);
    expect(received, isEmpty);
  });

  test('a transport error keeps the task and publishes nothing (offline promise, 28)',
      () async {
    when(() => apiClient.post(any(), any(), headers: any(named: 'headers')))
        .thenThrow(Exception('SocketException'));

    await queue.enqueue(ChatQueueTasks.post, payload());
    await queue.flush();
    await settle();

    expect(await queue.pendingCount(), 1);
    expect(received, isEmpty);
  });
}
