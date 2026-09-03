import 'dart:async';

import 'package:core/core.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/chat_send_outcomes.dart';
import '../../domain/entity/chat_entities.dart';
import '../../domain/usecase/fetch_chat_messages_usecase.dart';
import '../../domain/usecase/send_chat_message_usecase.dart';

/// Poll cadence while the screen is visible (decision 172). One place to
/// tune; never a background schedule.
const chatPollInterval = Duration(seconds: 5);

/// Injectable clock for the poll — tests hand a controlled stream.
typedef ChatTicker = Stream<void> Function(Duration interval);

Stream<void> _periodicTicker(Duration interval) => Stream<void>.periodic(interval);

sealed class ChatConversationEvent extends Equatable {
  const ChatConversationEvent();

  @override
  List<Object?> get props => [];
}

class ConversationStarted extends ChatConversationEvent {
  const ConversationStarted({required this.reportId, required this.threadId});

  final int reportId;

  /// Null for a helper who has not written yet — the first message creates
  /// the thread (173) and polling starts once it settles.
  final int? threadId;

  @override
  List<Object?> get props => [reportId, threadId];
}

class ConversationPollTicked extends ChatConversationEvent {
  const ConversationPollTicked();
}

class ConversationSendPressed extends ChatConversationEvent {
  const ConversationSendPressed(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// The screen left the foreground: polling stops (172 — never in background).
class ConversationPaused extends ChatConversationEvent {
  const ConversationPaused();
}

class ConversationResumed extends ChatConversationEvent {
  const ConversationResumed();
}

/// Internal: the queue reported on one of our optimistic bubbles.
class ConversationOutcomeArrived extends ChatConversationEvent {
  const ConversationOutcomeArrived(this.outcome);

  final ChatSendOutcome outcome;

  @override
  List<Object?> get props => [outcome];
}

sealed class ChatConversationState extends Equatable {
  const ChatConversationState();

  @override
  List<Object?> get props => [];
}

class ConversationLoading extends ChatConversationState {
  const ConversationLoading();
}

class ConversationError extends ChatConversationState {
  const ConversationError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

class ConversationLoaded extends ChatConversationState {
  const ConversationLoaded({
    required this.threadId,
    required this.closed,
    this.tier,
    required this.messages,
  });

  final int? threadId;

  /// Served by the API from the case's state (173): resolved or hidden.
  final bool closed;
  final String? tier;

  /// Oldest first; optimistic bubbles at the end until they settle.
  final List<ChatMessageEntity> messages;

  ConversationLoaded copyWith({
    int? threadId,
    bool? closed,
    String? tier,
    List<ChatMessageEntity>? messages,
  }) =>
      ConversationLoaded(
        threadId: threadId ?? this.threadId,
        closed: closed ?? this.closed,
        tier: tier ?? this.tier,
        messages: messages ?? this.messages,
      );

  @override
  List<Object?> get props => [threadId, closed, tier, messages];
}

/// One masked conversation (decisions 170/172/173/174): initial page,
/// cursor poll on every tick while visible, optimistic send settled or
/// failed ONLY by the queue's outcome.
class ChatConversationBloc extends Bloc<ChatConversationEvent, ChatConversationState> {
  ChatConversationBloc(
    this._fetchMessages,
    this._sendMessage,
    Stream<ChatSendOutcome> outcomes, {
    ChatTicker ticker = _periodicTicker,
    Duration pollInterval = chatPollInterval,
  })  : _ticker = ticker,
        _pollInterval = pollInterval,
        super(const ConversationLoading()) {
    on<ConversationStarted>(_onStarted);
    on<ConversationPollTicked>(_onTicked);
    on<ConversationSendPressed>(_onSendPressed);
    on<ConversationPaused>(_onPaused);
    on<ConversationResumed>(_onResumed);
    on<ConversationOutcomeArrived>(_onOutcome);
    _outcomeSub = outcomes.listen((outcome) => add(ConversationOutcomeArrived(outcome)));
  }

  final FetchChatMessagesUsecase _fetchMessages;
  final SendChatMessageUsecase _sendMessage;
  final ChatTicker _ticker;
  final Duration _pollInterval;

  late final StreamSubscription<ChatSendOutcome> _outcomeSub;
  StreamSubscription<void>? _pollSub;
  int? _reportId;
  int? _threadId;

  Future<void> _onStarted(
      ConversationStarted event, Emitter<ChatConversationState> emit) async {
    _reportId = event.reportId;
    _threadId = event.threadId;
    _stopPolling();
    if (event.threadId == null) {
      // Nothing to read yet; the first message creates the thread (173).
      emit(const ConversationLoaded(threadId: null, closed: false, messages: []));
      return;
    }
    emit(const ConversationLoading());
    final result = await _fetchMessages(event.threadId!, reportId: event.reportId);
    if (emit.isDone) return;
    result.fold(
      (failure) => emit(ConversationError(failure)),
      (page) {
        emit(ConversationLoaded(
          threadId: page.threadId,
          closed: page.closed,
          tier: page.tier,
          messages: page.messages,
        ));
        _startPolling();
      },
    );
  }

  Future<void> _onTicked(
      ConversationPollTicked event, Emitter<ChatConversationState> emit) async {
    final current = state;
    final threadId = _threadId;
    final reportId = _reportId;
    if (current is! ConversationLoaded || threadId == null || reportId == null) return;
    final result = await _fetchMessages(threadId, reportId: reportId, after: _lastId(current));
    if (emit.isDone) return;
    // A failed tick is transient: the conversation stays as it was.
    result.fold(
      (_) {},
      (page) {
        final latest = state;
        if (latest is! ConversationLoaded) return;
        emit(latest.copyWith(
          closed: page.closed,
          tier: page.tier,
          messages: _merge(latest.messages, page.messages),
        ));
      },
    );
  }

  Future<void> _onSendPressed(
      ConversationSendPressed event, Emitter<ChatConversationState> emit) async {
    final current = state;
    final reportId = _reportId;
    if (current is! ConversationLoaded || current.closed || reportId == null) return;
    final optimistic = await _sendMessage(
      reportId: reportId,
      threadId: _threadId,
      text: event.text,
    );
    if (emit.isDone) return;
    final latest = state;
    if (latest is! ConversationLoaded) return;
    emit(latest.copyWith(messages: [...latest.messages, optimistic]));
  }

  void _onOutcome(ConversationOutcomeArrived event, Emitter<ChatConversationState> emit) {
    final current = state;
    if (current is! ConversationLoaded) return;
    final outcome = event.outcome;
    final index = current.messages.indexWhere((m) => m.clientKey == outcome.clientKey);
    if (index < 0) return;

    switch (outcome) {
      case ChatSendSettled():
        final messages = [...current.messages]..[index] = outcome.message;
        final threadWasMissing = _threadId == null;
        _threadId = outcome.threadId;
        emit(current.copyWith(threadId: outcome.threadId, messages: messages));
        if (threadWasMissing) _startPolling();
      case ChatSendFailed():
        final messages = [...current.messages]
          ..[index] = current.messages[index]
              .copyWith(status: ChatMessageStatus.failed, failure: outcome.failure);
        emit(current.copyWith(messages: messages));
    }
  }

  void _onPaused(ConversationPaused event, Emitter<ChatConversationState> emit) =>
      _stopPolling();

  void _onResumed(ConversationResumed event, Emitter<ChatConversationState> emit) {
    if (_threadId == null) return;
    _startPolling();
    add(const ConversationPollTicked());
  }

  /// Appends only what is new: a served message whose `clientKey` matches
  /// a pending bubble REPLACES it (the poll may beat the queue outcome);
  /// an id already shown is skipped.
  List<ChatMessageEntity> _merge(
      List<ChatMessageEntity> current, List<ChatMessageEntity> served) {
    final merged = [...current];
    for (final message in served) {
      final byKey = merged.indexWhere((m) => m.clientKey == message.clientKey);
      if (byKey >= 0) {
        merged[byKey] = message;
        continue;
      }
      if (merged.any((m) => m.messageId != null && m.messageId == message.messageId)) continue;
      merged.add(message);
    }
    return merged;
  }

  int _lastId(ConversationLoaded loaded) => loaded.messages
      .map((m) => m.messageId ?? 0)
      .fold(0, (max, id) => id > max ? id : max);

  void _startPolling() {
    _pollSub?.cancel();
    _pollSub = _ticker(_pollInterval).listen((_) => add(const ConversationPollTicked()));
  }

  void _stopPolling() {
    _pollSub?.cancel();
    _pollSub = null;
  }

  @override
  Future<void> close() async {
    _stopPolling();
    await _outcomeSub.cancel();
    return super.close();
  }
}
