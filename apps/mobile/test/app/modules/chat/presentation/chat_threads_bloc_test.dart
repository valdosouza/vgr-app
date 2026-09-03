import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';
import 'package:vgr_mobile/app/modules/chat/domain/repository/chat_repository.dart';
import 'package:vgr_mobile/app/modules/chat/domain/usecase/list_chat_threads_usecase.dart';
import 'package:vgr_mobile/app/modules/chat/presentation/bloc/chat_threads_bloc.dart';

class MockChatRepository extends Mock implements ChatRepository {}

const _thread = ChatThreadSummaryEntity(
  threadId: 9,
  reportId: 5,
  me: ChatParticipantEntity(participantToken: 'a', role: ChatRole.reporter),
  other: ChatParticipantEntity(participantToken: 'b', role: ChatRole.helper),
  unreadCount: 1,
  closed: false,
);

void main() {
  late MockChatRepository repository;

  setUp(() => repository = MockChatRepository());

  ChatThreadsBloc build() => ChatThreadsBloc(ListChatThreadsUsecase(repository));

  test('loads the owner\'s threads', () async {
    when(() => repository.listThreads(5)).thenAnswer((_) async => const Right([_thread]));

    final bloc = build();
    expect(bloc.state, const ThreadsLoading());
    bloc.add(const ThreadsStarted(5));

    // Loading is re-emitted on every start so a retry shows progress.
    await expectLater(
      bloc.stream,
      emitsInOrder([const ThreadsLoading(), const ThreadsLoaded([_thread])]),
    );
  });

  test('surfaces a failure, retryable by starting again', () async {
    when(() => repository.listThreads(5)).thenAnswer(
        (_) async => const Left(Failure(message: 'off', code: 'OFFLINE')));

    final bloc = build()..add(const ThreadsStarted(5));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        const ThreadsLoading(),
        const ThreadsError(Failure(message: 'off', code: 'OFFLINE')),
      ]),
    );
  });
}
