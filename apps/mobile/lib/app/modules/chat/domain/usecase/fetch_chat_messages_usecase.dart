import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/chat_entities.dart';
import '../repository/chat_repository.dart';

/// One cursor page of a thread (decision 172).
class FetchChatMessagesUsecase {
  const FetchChatMessagesUsecase(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, ChatPageEntity>> call(
    int threadId, {
    required int reportId,
    int after = 0,
    int limit = 50,
  }) =>
      _repository.fetchMessages(threadId, reportId: reportId, after: after, limit: limit);
}
