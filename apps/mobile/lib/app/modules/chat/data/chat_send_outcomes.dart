import 'dart:async';

import 'package:core/core.dart';

import '../domain/entity/chat_entities.dart';

/// What the offline queue's `chat.post` handler reports back about a
/// message it dispatched (decision 172). The conversation bloc holds an
/// optimistic `pending` bubble keyed by `clientKey`; this is the ONLY
/// thing that settles or fails it — the app never guesses.
sealed class ChatSendOutcome {
  const ChatSendOutcome(this.clientKey);

  final String clientKey;
}

/// 201, or a 200 replay — both mean the API holds the message (137).
class ChatSendSettled extends ChatSendOutcome {
  const ChatSendSettled({
    required String clientKey,
    required this.threadId,
    required this.message,
  }) : super(clientKey);

  /// The thread the message landed in — new when it was a helper's first
  /// message (173).
  final int threadId;
  final ChatMessageEntity message;
}

/// The API judged and refused (422 `CONTACT_NOT_ALLOWED`, 409
/// `CHAT_CLOSED`, 451): no retry, the bubble shows the translated code.
class ChatSendFailed extends ChatSendOutcome {
  const ChatSendFailed({required String clientKey, required this.failure}) : super(clientKey);

  final Failure failure;
}

/// Broadcast bus between the queue handler (data layer, app-wide) and
/// whichever conversation screen is open. One instance per app.
class ChatSendOutcomes {
  final _controller = StreamController<ChatSendOutcome>.broadcast();

  Stream<ChatSendOutcome> get stream => _controller.stream;

  void publish(ChatSendOutcome outcome) {
    if (!_controller.isClosed) _controller.add(outcome);
  }

  Future<void> dispose() => _controller.close();
}
