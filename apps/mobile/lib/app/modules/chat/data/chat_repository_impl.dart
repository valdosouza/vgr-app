import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/my_reports_store.dart';
import '../domain/entity/chat_entities.dart';
import '../domain/repository/chat_repository.dart';
import 'chat_queue_tasks.dart';
import 'chat_send_outcomes.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(
    this._apiClient,
    this._queue,
    this._myReports,
    this._outcomes, {
    String Function()? clientKeyFactory,
    DateTime Function()? now,
  })  : _newClientKey = clientKeyFactory ?? (() => const Uuid().v4()),
        _now = now ?? DateTime.now;

  final ApiClient _apiClient;
  final OfflineQueueService _queue;
  final MyReportsStore _myReports;
  final ChatSendOutcomes _outcomes;
  final String Function() _newClientKey;
  final DateTime Function() _now;

  /// Bearer ownership of the anonymous reporter (134/169) — header, never
  /// URL; absent for a helper, whose session rides `ApiClient`'s bearer.
  Future<Map<String, String>?> _ownerHeaders(int reportId) async {
    final clientKey = await _myReports.clientKeyOf(reportId);
    return clientKey == null ? null : {'x-client-key': clientKey};
  }

  @override
  Future<Either<Failure, List<ChatThreadSummaryEntity>>> listThreads(int reportId) async {
    try {
      final response = await _apiClient.get(
        '/app-chat/$reportId/threads',
        headers: await _ownerHeaders(reportId),
      );
      return Right((response['threads'] as List<dynamic>)
          .map((t) => ChatThreadSummaryEntity.fromJson((t as Map).cast<String, dynamic>()))
          .toList());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<Either<Failure, ChatPageEntity>> fetchMessages(
    int threadId, {
    required int reportId,
    int after = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _apiClient.get(
        '/app-chat/threads/$threadId/messages?after=$after&limit=$limit',
        headers: await _ownerHeaders(reportId),
      );
      return Right(ChatPageEntity.fromJson(response));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<ChatMessageEntity> send({
    required int reportId,
    required int? threadId,
    required String text,
  }) async {
    final clientKey = _newClientKey();
    await _queue.enqueue(ChatQueueTasks.post, {
      'reportId': reportId,
      'threadId': threadId,
      'clientKey': clientKey,
      'text': text,
    });
    // Fire-and-forget: kick the flush now, the periodic retry self-heals.
    // ignore: unawaited_futures
    _queue.flush();
    return ChatMessageEntity(
      clientKey: clientKey,
      mine: true,
      text: text,
      createdAt: _now().toUtc().toIso8601String(),
      status: ChatMessageStatus.pending,
    );
  }

  @override
  Stream<ChatSendOutcome> get sendOutcomes => _outcomes.stream;
}
