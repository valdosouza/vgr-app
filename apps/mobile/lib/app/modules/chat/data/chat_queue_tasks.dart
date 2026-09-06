import 'package:core/core.dart';

import '../../../shared/data/my_reports_store.dart';
import '../domain/entity/chat_entities.dart';
import 'chat_send_outcomes.dart';

/// The `chat.post` task of the offline queue (decisions 28/172/137).
///
/// One kind: the message waits for connectivity under its own `clientKey`,
/// so a double dispatch is a 200 replay the API answers with the same
/// message. The handler tells the open conversation what happened through
/// [ChatSendOutcomes]; the queue itself learns only done/retry/drop.
abstract final class ChatQueueTasks {
  static const post = 'chat.post';

  /// Wires the handler. Call once at bootstrap next to `ReportQueueTasks`,
  /// before any flush.
  static void register(
    OfflineQueueService queue,
    ApiClient apiClient,
    MyReportsStore myReports, {
    required ChatSendOutcomes outcomes,
  }) {
    queue.register(post, (payload) async {
      final reportId = payload['reportId'] as int;
      final threadId = payload['threadId'] as int?;
      final clientKey = payload['clientKey'] as String;
      // Thread route when it exists; report route creates it on a
      // helper's first message (173). The anonymous reporter's ownership
      // travels as x-client-key (134/169) — header, never URL.
      final path = threadId == null
          ? '/app-chat/$reportId/messages'
          : '/app-chat/threads/$threadId/messages';
      final ownerKey = await myReports.clientKeyOf(reportId);
      try {
        final response = await apiClient.post(
          path,
          {'clientKey': clientKey, 'text': payload['text'] as String},
          headers: ownerKey == null ? null : {'x-client-key': ownerKey},
        );
        // 201 and a 200 replay carry the same shape — both settle (137).
        outcomes.publish(ChatSendSettled(
          clientKey: clientKey,
          threadId: response['threadId'] as int,
          message: ChatMessageEntity.fromJson(
              (response['message'] as Map).cast<String, dynamic>()),
        ));
        return QueueTaskResult.done;
      } on Failure catch (failure) {
        // 5xx is the API having a bad moment — retry keeps the task and
        // tells the screen nothing. Anything else was judged (422 contact,
        // 409 closed, 451 legal): retrying can never succeed, so the task
        // is dropped and the bubble fails — same rule as report_queue_tasks.
        if ((failure.statusCode ?? 0) >= 500) return QueueTaskResult.retry;
        outcomes.publish(ChatSendFailed(clientKey: clientKey, failure: failure));
        return QueueTaskResult.drop;
      }
      // A transport error throws past the handler: the queue keeps the
      // task and stops — the offline promise of decision 28.
    });
  }
}
