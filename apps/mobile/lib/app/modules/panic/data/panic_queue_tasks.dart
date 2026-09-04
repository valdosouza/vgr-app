import 'package:core/core.dart';

import 'panic_local_store.dart';

/// The `panic_alert_trigger`/`panic_alert_resolve` tasks of the offline
/// queue (decisions 28/62/191/198): a panic trigger and its resolve are
/// both meant to survive being offline at the moment they are tapped,
/// exactly like `report_queue_tasks.dart`/`rating_queue_tasks.dart`.
abstract final class PanicQueueTasks {
  static const trigger = 'panic_alert_trigger';
  static const resolve = 'panic_alert_resolve';

  /// Wires both handlers. Call once at bootstrap next to
  /// `ReportQueueTasks`/`ChatQueueTasks`/`RatingQueueTasks`, before any
  /// flush.
  static void register(OfflineQueueService queue, ApiClient apiClient,
      {PanicLocalStore? localStore}) {
    queue.register(trigger, (payload) async {
      final clientKey = payload['clientKey'] as String;
      final Map<String, dynamic> response;
      try {
        response = await apiClient.post('/app-panic/alert', {
          'clientKey': clientKey,
          'position': {'lat': payload['lat'], 'lng': payload['lng']},
        });
      } on Failure catch (failure) {
        return _judge(failure);
      }
      // The repository could not know the server-assigned alertId at the
      // moment it enqueued this task — THIS is where {alertId, clientKey}
      // finally gets persisted (mirrors `report_queue_tasks.dart`'s
      // `submit` handler saving to `MyReportsStore` only once the id
      // exists).
      await localStore?.saveActiveAlert(
        alertId: response['alertId'] as int,
        clientKey: clientKey,
      );
      return QueueTaskResult.done;
    });

    queue.register(resolve, (payload) async {
      final alertId = payload['alertId'] as int;
      final clientKey = payload['clientKey'] as String?;
      try {
        await apiClient.post(
          '/app-panic/alerts/$alertId/resolve',
          const {},
          headers: clientKey == null ? null : {'x-client-key': clientKey},
        );
      } on Failure catch (failure) {
        return _judgeResolve(failure);
      }
      return QueueTaskResult.done;
    });
  }

  /// 5xx is the API having a bad moment — retry keeps the task. Anything
  /// else was judged (404/409 `PANIC_ALERT_ACTIVE`/422/451): retrying can
  /// never succeed, so the task is dropped rather than wedging the queue
  /// forever. A dropped trigger currently has no user-facing surfacing —
  /// same accepted gap as a dropped `report_submit`.
  static QueueTaskResult _judge(Failure failure) =>
      (failure.statusCode ?? 0) >= 500 ? QueueTaskResult.retry : QueueTaskResult.drop;

  /// Mirrors `report_queue_tasks.dart`'s `_judgeResolve`: the resolve
  /// endpoint's only business-rule refusal is "already resolved" — an ack
  /// that never reached this device after a first attempt DID succeed
  /// lands here identically to a genuine double-resolve. Either way the
  /// alert IS resolved, so this one outcome is `done`, never retried.
  static QueueTaskResult _judgeResolve(Failure failure) {
    if ((failure.statusCode ?? 0) >= 500) return QueueTaskResult.retry;
    if (failure.code == 'PANIC_ALERT_ALREADY_RESOLVED') return QueueTaskResult.done;
    return QueueTaskResult.drop;
  }
}
