import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_send_outcomes.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';
import 'package:vgr_mobile/app/modules/chat/domain/repository/chat_repository.dart';
import 'package:vgr_mobile/app/modules/chat/domain/usecase/fetch_chat_messages_usecase.dart';
import 'package:vgr_mobile/app/modules/chat/domain/usecase/send_chat_message_usecase.dart';
import 'package:vgr_mobile/app/modules/chat/presentation/bloc/chat_conversation_bloc.dart';
import 'package:vgr_mobile/app/modules/chat/presentation/page/chat_conversation_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';

class MockChatRepository extends Mock implements ChatRepository {}

ChatMessageEntity _served(int id, {bool mine = false, String? text}) => ChatMessageEntity(
      messageId: id,
      clientKey: 'ck-$id',
      sender: mine ? 'a' : 'b',
      mine: mine,
      text: text ?? 'm$id',
      createdAt: '2026-09-03T10:1$id:00.000Z',
    );

/// The conversation screen (decisions 170/171/172/174): title = the other
/// side's ROLE label (or the served name), bubbles by `mine`, pending /
/// failed markers, composer validated locally with the API's own rule
/// before anything is enqueued, closed notice instead of the composer.
void main() {
  late MockChatRepository repository;
  late StreamController<ChatSendOutcome> outcomes;
  late StreamController<void> ticks;

  setUp(() {
    repository = MockChatRepository();
    outcomes = StreamController<ChatSendOutcome>.broadcast();
    ticks = StreamController<void>.broadcast();
    when(() => repository.sendOutcomes).thenAnswer((_) => outcomes.stream);
  });

  tearDown(() async {
    await outcomes.close();
    await ticks.close();
  });

  void stubPage(List<ChatMessageEntity> messages, {bool closed = false}) =>
      when(() => repository.fetchMessages(9,
              reportId: 5, after: any(named: 'after'), limit: any(named: 'limit')))
          .thenAnswer((_) async =>
              Right(ChatPageEntity(threadId: 9, closed: closed, tier: 'medium', messages: messages)));

  Future<void> pumpPage(
    WidgetTester tester, {
    int? threadId = 9,
    ChatRole otherRole = ChatRole.helper,
    String? otherName,
  }) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ChatConversationBloc(
          FetchChatMessagesUsecase(repository),
          SendChatMessageUsecase(repository),
          repository.sendOutcomes,
          ticker: (_) => ticks.stream,
        ),
        child: ChatConversationPage(
          reportId: 5,
          threadId: threadId,
          otherRole: otherRole,
          otherName: otherName,
        ),
      ),
    );
  }

  testWidgets('renders bubbles by `mine`, times as served, and the ROLE for the reporter — '
      'never a name (170)', (tester) async {
    stubPage([_served(1, text: 'hello'), _served(2, mine: true, text: 'hi')]);

    await pumpPage(tester, otherRole: ChatRole.reporter);

    expect(find.text('Reporter'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('hi'), findsOneWidget);
    expect(find.text('2026-09-03 10:11'), findsOneWidget);
    expect(tester.widget<VgrChatBubble>(find.byKey(const Key('chat-bubble-ck-2'))).mine, isTrue);
    expect(tester.widget<VgrChatBubble>(find.byKey(const Key('chat-bubble-ck-1'))).mine, isFalse);
  });

  testWidgets('the served display name of an identified helper is the title', (tester) async {
    stubPage([]);

    await pumpPage(tester, otherName: 'Ana');

    expect(find.text('Ana'), findsOneWidget);
    expect(find.byKey(const Key('chat-conversation-empty')), findsOneWidget);
  });

  testWidgets('the composer blocks a phone number LOCALLY with the translated field error '
      'and enqueues nothing (171)', (tester) async {
    stubPage([]);

    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'me liga 91234567');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.textContaining('Direct contact is not allowed'), findsOneWidget);
    expect(find.textContaining('91234567'), findsWidgets);
    verifyNever(() => repository.send(
        reportId: any(named: 'reportId'), threadId: any(named: 'threadId'), text: any(named: 'text')));
  });

  testWidgets('a clean message is enqueued, shows pending, then settles', (tester) async {
    stubPage([]);
    when(() => repository.send(reportId: 5, threadId: 9, text: 'posso ir agora')).thenAnswer(
        (_) async => const ChatMessageEntity(
            clientKey: 'ck-new',
            mine: true,
            text: 'posso ir agora',
            createdAt: '2026-09-03T10:20:00.000Z',
            status: ChatMessageStatus.pending));

    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'posso ir agora');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.text('Sending…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, isEmpty);

    outcomes.add(ChatSendSettled(
        clientKey: 'ck-new',
        threadId: 9,
        message: const ChatMessageEntity(
            messageId: 7,
            clientKey: 'ck-new',
            mine: true,
            text: 'posso ir agora',
            createdAt: '2026-09-03T10:20:00.000Z')));
    await tester.pump();

    expect(find.text('Sending…'), findsNothing);
    expect(find.text('posso ir agora'), findsOneWidget);
  });

  testWidgets('a bubble refused by the API shows the translated reason', (tester) async {
    stubPage([]);
    when(() => repository.send(reportId: 5, threadId: 9, text: 'x')).thenAnswer(
        (_) async => const ChatMessageEntity(
            clientKey: 'ck-new', mine: true, text: 'x', createdAt: '',
            status: ChatMessageStatus.pending));

    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    outcomes.add(const ChatSendFailed(
        clientKey: 'ck-new',
        failure: Failure(message: 'closed', statusCode: 409, code: 'CHAT_CLOSED')));
    await tester.pump();

    expect(find.text('Not sent: This conversation is closed.'), findsOneWidget);
  });

  testWidgets('closed thread: the composer is replaced by the notice; reading still works',
      (tester) async {
    stubPage([_served(1, text: 'old')], closed: true);

    await pumpPage(tester);

    expect(find.text('old'), findsOneWidget);
    expect(find.byKey(const Key('chat-closed-notice')), findsOneWidget);
    expect(find.byType(VgrChatComposer), findsNothing);
  });

  testWidgets('a failed load is a retryable error', (tester) async {
    when(() => repository.fetchMessages(9,
            reportId: 5, after: any(named: 'after'), limit: any(named: 'limit')))
        .thenAnswer((_) async => const Left(Failure(message: 'nf', code: 'NOT_FOUND')));

    await pumpPage(tester);

    expect(find.byKey(const Key('chat-conversation-error')), findsOneWidget);
    expect(find.text('Record not found.'), findsOneWidget);
    expect(find.byKey(const Key('chat-conversation-retry')), findsOneWidget);
  });
}
