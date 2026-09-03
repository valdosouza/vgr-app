import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/chat_entities.dart';
import '../repository/chat_repository.dart';

/// The owner's thread list (decisions 55/170).
class ListChatThreadsUsecase {
  const ListChatThreadsUsecase(this._repository);

  final ChatRepository _repository;

  Future<Either<Failure, List<ChatThreadSummaryEntity>>> call(int reportId) =>
      _repository.listThreads(reportId);
}
