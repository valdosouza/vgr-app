import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/chat/data/chat_send_outcomes.dart';
import 'package:vgr_mobile/app/modules/chat/domain/entity/chat_entities.dart';
import 'package:vgr_mobile/app/modules/chat/domain/repository/chat_repository.dart';
import 'package:vgr_mobile/app/modules/chat/domain/usecase/fetch_chat_messages_usecase.dart';
import 'package:vgr_mobile/app/modules/chat/domain/usecase/send_chat_message_usecase.dart';
import 'package:vgr_mobile/app/modules/chat/presentation/bloc/chat_conversation_bloc.dart';

class MockChatRepository extends Mock implements ChatRepository {}

ChatMessageEntity _served(int id, {bool mine = false, String? clientKey}) => ChatMessageEntity(
      messageId: id,
      clientKey: clientKey ?? 'ck-$id',
      sender: mine ? 'a' : 'b',
      mine: mine,
      text: 'm$id',
      createdAt: '2026-09-03T10:0$id:00.000Z',
    );

ChatPageEntity _page(List<ChatMessageEntity> messages, {bool closed = false}) =>
    ChatPageEntity(threadId: 9, closed: closed, tier: 'medium', messages: messages);

/// Delivery (decision 172): initial load, then a cursor poll every tick
/// WHILE the screen is visible; sending is optimistic and settles or
/// fails from the queue's outcome, never by the bloc's own guess.
void main() {
  late MockChatRepository repository;
  late StreamController<ChatSendOutcome> outcomes;
  late StreamController<void> ticks;
  late int tickerCalls;

  setUp(() {
    repository = MockChatRepository();
    outcomes = StreamController<ChatSendOutcome>.broadcast();
    ticks = StreamController<void>.broadcast();
    tickerCalls = 0;
    when(() => repository.sendOutcomes).thenAnswer((_) => outcomes.stream);
  });

  tearDown(() async {
    await outcomes.close();
    await ticks.close();
  });

  ChatConversationBloc build() => ChatConversationBloc(
        FetchChatMessagesUsecase(repository),
        SendChatMessageUsecase(repository),
        repository.sendOutcomes,
        ticker: (_) {
          tickerCalls++;
          return ticks.stream;
        },
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void stubFetch(int after, ChatPageEntity page) => when(() => repository.fetchMessages(9,
      reportId: 5, after: after, limit: any(named: 'limit'))).thenAnswer((_) async => Right(page));

  test('initial load renders the page and starts polling', () async {
    stubFetch(0, _page([_served(1), _served(2, mine: true)]));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();

    final loaded = bloc.state as ConversationLoaded;
    expect(loaded.threadId, 9);
    expect(loaded.messages.map((m) => m.messageId), [1, 2]);
    expect(tickerCalls, 1);
    await bloc.close();
  });

  test('a poll tick fetches after the highest id and APPENDS only what is new', () async {
    stubFetch(0, _page([_served(1), _served(2)]));
    stubFetch(2, _page([_served(3)]));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    ticks.add(null);
    await settle();

    expect((bloc.state as ConversationLoaded).messages.map((m) => m.messageId), [1, 2, 3]);
    verify(() => repository.fetchMessages(9, reportId: 5, after: 2, limit: any(named: 'limit')))
        .called(1);
    await bloc.close();
  });

  test('a poll tick that fails keeps the conversation as it was (transient)', () async {
    stubFetch(0, _page([_served(1)]));
    when(() => repository.fetchMessages(9, reportId: 5, after: 1, limit: any(named: 'limit')))
        .thenAnswer((_) async => const Left(Failure(message: 'off', code: 'OFFLINE')));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    ticks.add(null);
    await settle();

    expect(bloc.state, isA<ConversationLoaded>());
    expect((bloc.state as ConversationLoaded).messages.length, 1);
    await bloc.close();
  });

  test('send → optimistic pending bubble → settled by the queue outcome (201/200)', () async {
    stubFetch(0, _page([_served(1)]));
    const optimistic = ChatMessageEntity(
      clientKey: 'ck-new',
      mine: true,
      text: 'oi',
      createdAt: '2026-09-03T10:10:00.000Z',
      status: ChatMessageStatus.pending,
    );
    when(() => repository.send(reportId: 5, threadId: 9, text: 'oi'))
        .thenAnswer((_) async => optimistic);

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    bloc.add(const ConversationSendPressed('oi'));
    await settle();

    var messages = (bloc.state as ConversationLoaded).messages;
    expect(messages.last.status, ChatMessageStatus.pending);
    expect(messages.last.clientKey, 'ck-new');

    outcomes.add(ChatSendSettled(
      clientKey: 'ck-new',
      threadId: 9,
      message: _served(7, mine: true, clientKey: 'ck-new'),
    ));
    await settle();

    messages = (bloc.state as ConversationLoaded).messages;
    expect(messages.length, 2);
    expect(messages.last.status, ChatMessageStatus.sent);
    expect(messages.last.messageId, 7);
    await bloc.close();
  });

  test('a judged refusal (422/409/451) marks the bubble failed with the failure', () async {
    stubFetch(0, _page([]));
    when(() => repository.send(reportId: 5, threadId: 9, text: 'oi')).thenAnswer(
        (_) async => const ChatMessageEntity(
            clientKey: 'ck-new', mine: true, text: 'oi', createdAt: 't',
            status: ChatMessageStatus.pending));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    bloc.add(const ConversationSendPressed('oi'));
    await settle();
    outcomes.add(const ChatSendFailed(
      clientKey: 'ck-new',
      failure: Failure(message: 'closed', statusCode: 409, code: 'CHAT_CLOSED'),
    ));
    await settle();

    final bubble = (bloc.state as ConversationLoaded).messages.single;
    expect(bubble.status, ChatMessageStatus.failed);
    expect(bubble.failureCode, 'CHAT_CLOSED');
    await bloc.close();
  });

  test('a message already settled that the poll serves again is not duplicated', () async {
    stubFetch(0, _page([]));
    when(() => repository.send(reportId: 5, threadId: 9, text: 'oi')).thenAnswer(
        (_) async => const ChatMessageEntity(
            clientKey: 'ck-new', mine: true, text: 'oi', createdAt: 't',
            status: ChatMessageStatus.pending));
    stubFetch(7, _page([]));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    bloc.add(const ConversationSendPressed('oi'));
    await settle();
    // The poll may serve the message BEFORE the queue outcome arrives.
    stubFetch(0, _page([_served(7, mine: true, clientKey: 'ck-new')]));
    ticks.add(null);
    await settle();
    outcomes.add(ChatSendSettled(
        clientKey: 'ck-new', threadId: 9, message: _served(7, mine: true, clientKey: 'ck-new')));
    await settle();

    final messages = (bloc.state as ConversationLoaded).messages;
    expect(messages.length, 1);
    expect(messages.single.status, ChatMessageStatus.sent);
    await bloc.close();
  });

  test('helper without a thread: no polling until the first message settles with a threadId '
      '(173)', () async {
    when(() => repository.send(reportId: 5, threadId: null, text: 'oi')).thenAnswer(
        (_) async => const ChatMessageEntity(
            clientKey: 'ck-new', mine: true, text: 'oi', createdAt: 't',
            status: ChatMessageStatus.pending));
    when(() => repository.fetchMessages(12,
            reportId: 5, after: any(named: 'after'), limit: any(named: 'limit')))
        .thenAnswer((_) async => Right(ChatPageEntity(
            threadId: 12, closed: false, tier: 'medium', messages: [_served(1)])));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: null));
    await settle();

    expect((bloc.state as ConversationLoaded).threadId, isNull);
    expect(tickerCalls, 0);
    verifyNever(() => repository.fetchMessages(any(),
        reportId: any(named: 'reportId'), after: any(named: 'after'), limit: any(named: 'limit')));

    bloc.add(const ConversationSendPressed('oi'));
    await settle();
    outcomes.add(ChatSendSettled(
        clientKey: 'ck-new', threadId: 12, message: _served(1, mine: true, clientKey: 'ck-new')));
    await settle();

    expect((bloc.state as ConversationLoaded).threadId, 12);
    expect(tickerCalls, 1);
    await bloc.close();
  });

  test('closed thread: sending is refused locally, reading still works', () async {
    stubFetch(0, _page([_served(1)], closed: true));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    bloc.add(const ConversationSendPressed('oi'));
    await settle();

    expect((bloc.state as ConversationLoaded).closed, isTrue);
    verifyNever(() => repository.send(
        reportId: any(named: 'reportId'), threadId: any(named: 'threadId'), text: any(named: 'text')));
    await bloc.close();
  });

  test('paused stops the ticker; resumed polls at once and subscribes again (never in '
      'background, 172)', () async {
    stubFetch(0, _page([_served(1)]));
    stubFetch(1, _page([_served(2)]));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();
    bloc.add(const ConversationPaused());
    await settle();
    ticks.add(null);
    await settle();
    expect((bloc.state as ConversationLoaded).messages.length, 1);

    bloc.add(const ConversationResumed());
    await settle();
    expect((bloc.state as ConversationLoaded).messages.length, 2);
    expect(tickerCalls, 2);
    await bloc.close();
  });

  test('a failed initial load is an error state', () async {
    when(() => repository.fetchMessages(9, reportId: 5, after: 0, limit: any(named: 'limit')))
        .thenAnswer((_) async => const Left(Failure(message: 'nf', code: 'NOT_FOUND')));

    final bloc = build()..add(const ConversationStarted(reportId: 5, threadId: 9));
    await settle();

    expect(bloc.state, const ConversationError(Failure(message: 'nf', code: 'NOT_FOUND')));
    await bloc.close();
  });
}
