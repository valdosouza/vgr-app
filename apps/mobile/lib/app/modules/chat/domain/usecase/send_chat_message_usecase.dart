import '../entity/chat_entities.dart';
import '../repository/chat_repository.dart';

/// Enqueues a message and answers the optimistic bubble (decision 172).
/// The anti-contact rule ran on the screen already (171) — the API
/// re-checks regardless.
class SendChatMessageUsecase {
  const SendChatMessageUsecase(this._repository);

  final ChatRepository _repository;

  Future<ChatMessageEntity> call({
    required int reportId,
    required int? threadId,
    required String text,
  }) =>
      _repository.send(reportId: reportId, threadId: threadId, text: text);
}
