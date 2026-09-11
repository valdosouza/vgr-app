import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';
import 'package:vgr_mobile/app/modules/chat/domain/repository/chat_repository.dart';
import 'package:vgr_mobile/app/modules/chat/domain/usecase/list_chat_threads_usecase.dart';
import 'package:vgr_mobile/app/modules/chat/presentation/bloc/chat_threads_bloc.dart';
import 'package:vgr_mobile/app/modules/chat/presentation/page/chat_threads_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockChatRepository extends Mock implements ChatRepository {}

/// The owner's list (decisions 55/170): one row per helper, label or the
/// SERVED display name, last message time as served, unread badge, closed
/// marker. The page never decides who someone is.
void main() {
  late MockChatRepository repository;

  setUp(() => repository = MockChatRepository());

  Future<void> pumpPage(WidgetTester tester,
      {void Function(ChatThreadSummaryEntity thread)? onOpenThread}) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ChatThreadsBloc(ListChatThreadsUsecase(repository)),
        child: ChatThreadsPage(reportId: 5, onOpenThread: onOpenThread),
      ),
    );
  }

  testWidgets('rows show the role label or the served name, unread badge and closed marker',
      (tester) async {
    when(() => repository.listThreads(5)).thenAnswer((_) async => const Right([
          ChatThreadSummaryEntity(
            threadId: 9,
            reportId: 5,
            me: ChatParticipantEntity(participantToken: 'a', role: ChatRole.reporter),
            other: ChatParticipantEntity(participantToken: 'b', role: ChatRole.helper),
            lastMessageAt: '2026-09-03T10:15:00.000Z',
            unreadCount: 2,
            closed: false,
          ),
          ChatThreadSummaryEntity(
            threadId: 10,
            reportId: 5,
            me: ChatParticipantEntity(participantToken: 'a', role: ChatRole.reporter),
            other: ChatParticipantEntity(
                participantToken: 'c', role: ChatRole.helper, displayName: 'Ana'),
            unreadCount: 0,
            closed: true,
          ),
        ]));

    await pumpPage(tester);

    expect(find.text('Conversations'), findsOneWidget);
    expect(find.byKey(const Key('chat-thread-9')), findsOneWidget);
    expect(find.text('Helper'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('2026-09-03 10:15'), findsOneWidget);
    expect(find.byKey(const Key('chat-thread-10-closed')), findsOneWidget);
    expect(find.byKey(const Key('chat-thread-9-unread')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(const Key('chat-thread-10-unread')), findsNothing);
  });

  testWidgets('tapping a row opens the conversation with the served other participant',
      (tester) async {
    const thread = ChatThreadSummaryEntity(
      threadId: 9,
      reportId: 5,
      me: ChatParticipantEntity(participantToken: 'a', role: ChatRole.reporter),
      other: ChatParticipantEntity(participantToken: 'b', role: ChatRole.helper),
      unreadCount: 0,
      closed: false,
    );
    when(() => repository.listThreads(5)).thenAnswer((_) async => const Right([thread]));

    ChatThreadSummaryEntity? opened;
    await pumpPage(tester, onOpenThread: (t) => opened = t);
    await tester.tap(find.byKey(const Key('chat-thread-9')));

    expect(opened, thread);
  });

  testWidgets('empty state', (tester) async {
    when(() => repository.listThreads(5)).thenAnswer((_) async => const Right([]));

    await pumpPage(tester);

    expect(find.byKey(const Key('chat-threads-empty')), findsOneWidget);
    expect(find.textContaining('No conversations yet.'), findsOneWidget);
    // Owner-side rule (169/173) spelled out — the empty list is not a bug.
    expect(find.textContaining('helper with an account sends the first message'), findsOneWidget);
  });

  testWidgets('error state is retryable', (tester) async {
    when(() => repository.listThreads(5)).thenAnswer(
        (_) async => const Left(Failure(message: 'off', code: 'OFFLINE')));

    await pumpPage(tester);

    expect(find.byKey(const Key('chat-threads-error')), findsOneWidget);
    expect(find.text('No connection.'), findsOneWidget);
    when(() => repository.listThreads(5)).thenAnswer((_) async => const Right([]));
    await tester.tap(find.byKey(const Key('chat-threads-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-threads-empty')), findsOneWidget);
  });
}
