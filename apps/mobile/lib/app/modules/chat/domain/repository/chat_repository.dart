import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../data/chat_send_outcomes.dart';
import '../entity/chat_entities.dart';

abstract class ChatRepository {
  /// `GET /app-chat/:reportId/threads` — the owner's threads (one per
  /// helper) or a helper's own thread (decisions 55/169/170). Carries
  /// `x-client-key` when this device owns the report (134).
  Future<Either<Failure, List<ChatThreadSummaryEntity>>> listThreads(int reportId);

  /// `GET /app-chat/threads/:threadId/messages?after=&limit=` — cursor
  /// page (172). [reportId] is what lets the anonymous reporter present
  /// the ownership header on a thread route.
  Future<Either<Failure, ChatPageEntity>> fetchMessages(
    int threadId, {
    required int reportId,
    int after = 0,
    int limit = 50,
  });

  /// Enqueues the message (`chat.post`, decision 172) under an
  /// app-generated `clientKey` and answers the optimistic `pending`
  /// bubble. [threadId] null = a helper's first message; the thread is
  /// created by the API (173). Never throws: the queue holds it.
  Future<ChatMessageEntity> send({
    required int reportId,
    required int? threadId,
    required String text,
  });

  /// Settles/fails optimistic bubbles as the queue flushes.
  Stream<ChatSendOutcome> get sendOutcomes;
}
