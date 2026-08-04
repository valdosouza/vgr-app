import 'package:core/core.dart';

import '../domain/entity/report_input.dart';
import 'my_reports_store.dart';

/// Task kinds + handlers of the report offline chain (decisions 28/123/137).
///
/// Three kinds, each enqueueing the next on success, so a retry re-runs
/// only the step that failed:
///
///   submit ──▶ mediaUpload (per photo) ──▶ mediaAttach
///
/// Every step is replay-safe on the API side (submit by `clientKey`,
/// attach answers 200 on replay). The one non-idempotent step is the raw
/// upload: a crash between upload and attach re-uploads on retry and the
/// first blob is left `pending` — exactly what the 48h orphan TTL exists
/// for (decision 136).
abstract final class ReportQueueTasks {
  static const submit = 'report_submit';
  static const mediaUpload = 'report_media_upload';
  static const mediaAttach = 'report_media_attach';

  /// Wires the three handlers. Call once at bootstrap, before any flush.
  static void register(OfflineQueueService queue, ApiClient apiClient,
      {MyReportsStore? myReports}) {
    queue.register(submit, (payload) async {
      final input = ReportInput.fromJson(payload);
      final int reportId;
      try {
        final response = await _swallowReplay(
          () => apiClient.post('/app-reports', input.toSubmitBody()),
        );
        reportId = response['reportId'] as int;
      } on Failure catch (failure) {
        return _judge(failure);
      }
      // Bearer ownership survives the offline path too (decision 134).
      await myReports?.save(reportId, input.clientKey);
      for (final photo in input.photos) {
        await queue.enqueue(mediaUpload, {
          'reportId': reportId,
          'clientKey': input.clientKey,
          ...photo.toJson(),
        });
      }
      return QueueTaskResult.done;
    });

    queue.register(mediaUpload, (payload) async {
      final keepOriginal = payload['keepOriginal'] as bool? ?? false;
      final String publicId;
      try {
        final response = await apiClient.postMultipart(
          '/app-media',
          filePath: payload['path'] as String,
          fields: {
            'class': 'evidence',
            'keepOriginal': '$keepOriginal',
            if (keepOriginal && payload['exifWarningVersion'] != null)
              'exifWarningVersion': payload['exifWarningVersion'] as String,
          },
        );
        publicId = response['publicId'] as String;
      } on Failure catch (failure) {
        return _judge(failure);
      }
      await queue.enqueue(mediaAttach, {
        'reportId': payload['reportId'],
        'clientKey': payload['clientKey'],
        'mediaPublicId': publicId,
      });
      return QueueTaskResult.done;
    });

    queue.register(mediaAttach, (payload) async {
      try {
        await _swallowReplay(
          () => apiClient.post(
            '/app-reports/${payload['reportId']}/media',
            {'mediaPublicId': payload['mediaPublicId']},
            // Bearer-secret ownership for the anonymous reporter
            // (decision 134) — header, never URL.
            headers: {'x-client-key': payload['clientKey'] as String},
          ),
        );
      } on Failure catch (failure) {
        return _judge(failure);
      }
      return QueueTaskResult.done;
    });
  }

  /// A replay answers 200 with the same resource — success by contract
  /// (decision 137). Only here for symmetry/documentation: ApiClient
  /// treats any 2xx as success already.
  static Future<Map<String, dynamic>> _swallowReplay(
    Future<Map<String, dynamic>> Function() call,
  ) =>
      call();

  /// 5xx is the API having a bad moment — retry keeps the task. Anything
  /// else was judged and refused; retrying can never succeed, so the task
  /// is dropped rather than wedging the queue forever (a transport error
  /// never reaches here — it throws past the handler and the queue holds
  /// the task).
  static QueueTaskResult _judge(Failure failure) =>
      (failure.statusCode ?? 0) >= 500 ? QueueTaskResult.retry : QueueTaskResult.drop;
}
