import 'package:core/core.dart';
import 'package:equatable/equatable.dart';

/// Entities of the masked chat (C2 — decisions 54, 169-174), mapped 1:1
/// from what `/app-chat` serves (`api/docs/feature/chat.md`). The app
/// renders `role` + `displayName` EXACTLY as served (170): it never looks
/// anyone up, never derives a name, never shows one for the reporter.

/// Wire names of the API's `ChatRole`.
enum ChatRole { reporter, helper }

/// One side of a thread as the API masks it: an opaque token per
/// (thread, participant), a fixed role, and a display name ONLY when the
/// helper chose to identify and the tier allows — the reporter's is
/// always null (170).
class ChatParticipantEntity extends Equatable {
  const ChatParticipantEntity({
    required this.participantToken,
    required this.role,
    this.displayName,
  });

  final String participantToken;
  final ChatRole role;
  final String? displayName;

  factory ChatParticipantEntity.fromJson(Map<String, dynamic> json) => ChatParticipantEntity(
        participantToken: json['participantToken'] as String,
        role: ChatRole.values.byName(json['role'] as String),
        displayName: json['displayName'] as String?,
      );

  @override
  List<Object?> get props => [participantToken, role, displayName];
}

/// `GET /app-chat/:reportId/threads` row.
class ChatThreadSummaryEntity extends Equatable {
  const ChatThreadSummaryEntity({
    required this.threadId,
    required this.reportId,
    required this.me,
    required this.other,
    this.lastMessageAt,
    required this.unreadCount,
    required this.closed,
  });

  final int threadId;
  final int reportId;
  final ChatParticipantEntity me;
  final ChatParticipantEntity other;

  /// Degraded by tier on the server (174); null before the first message.
  final String? lastMessageAt;
  final int unreadCount;

  /// Derived from the case on the server (173): resolved or hidden.
  final bool closed;

  factory ChatThreadSummaryEntity.fromJson(Map<String, dynamic> json) => ChatThreadSummaryEntity(
        threadId: json['threadId'] as int,
        reportId: json['reportId'] as int,
        me: ChatParticipantEntity.fromJson((json['me'] as Map).cast<String, dynamic>()),
        other: ChatParticipantEntity.fromJson((json['other'] as Map).cast<String, dynamic>()),
        lastMessageAt: json['lastMessageAt'] as String?,
        unreadCount: json['unreadCount'] as int,
        closed: json['closed'] as bool,
      );

  @override
  List<Object?> get props => [threadId, reportId, me, other, lastMessageAt, unreadCount, closed];
}

/// Local delivery status (172): a message rides the offline queue, so it
/// is `pending` from the tap until the flush confirms (201, or 200 on a
/// replay), and `failed` when the API judged and refused (422/409/451).
enum ChatMessageStatus { sent, pending, failed }

class ChatMessageEntity extends Equatable {
  const ChatMessageEntity({
    this.messageId,
    required this.clientKey,
    this.sender,
    required this.mine,
    this.text,
    this.purged = false,
    required this.createdAt,
    this.status = ChatMessageStatus.sent,
    this.failure,
  });

  /// Null while optimistic — the server assigns it.
  final int? messageId;

  /// The MESSAGE's idempotency key, generated in the app (172/137).
  final String clientKey;

  /// The sender's participantToken; null while optimistic.
  final String? sender;

  /// Served by the API — the screen never computes it.
  final bool mine;

  /// Null after a purge (131/173).
  final String? text;
  final bool purged;

  /// As served — already degraded by tier (174) — or the local clock for
  /// an optimistic bubble until it settles.
  final String createdAt;
  final ChatMessageStatus status;

  /// Why the API refused it (only when [status] is failed).
  final Failure? failure;

  /// The code to translate: the field error's (`CONTACT_NOT_ALLOWED`)
  /// first, then the envelope's (`CHAT_CLOSED`, `LEGAL_BLOCKED`).
  String? get failureCode {
    final fields = failure?.fields;
    if (fields != null && fields.isNotEmpty && fields.first.code != null) {
      return fields.first.code;
    }
    return failure?.code;
  }

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) => ChatMessageEntity(
        messageId: json['messageId'] as int,
        clientKey: json['clientKey'] as String,
        sender: json['sender'] as String?,
        mine: json['mine'] as bool,
        text: json['text'] as String?,
        purged: json['purged'] as bool? ?? false,
        createdAt: json['createdAt'] as String,
      );

  ChatMessageEntity copyWith({ChatMessageStatus? status, Failure? failure}) => ChatMessageEntity(
        messageId: messageId,
        clientKey: clientKey,
        sender: sender,
        mine: mine,
        text: text,
        purged: purged,
        createdAt: createdAt,
        status: status ?? this.status,
        failure: failure ?? this.failure,
      );

  @override
  List<Object?> get props =>
      [messageId, clientKey, sender, mine, text, purged, createdAt, status, failure];
}

/// `GET /app-chat/threads/:threadId/messages` page.
class ChatPageEntity extends Equatable {
  const ChatPageEntity({
    required this.threadId,
    required this.closed,
    required this.tier,
    required this.messages,
  });

  final int threadId;
  final bool closed;
  final String tier;

  /// Ascending by messageId from the cursor.
  final List<ChatMessageEntity> messages;

  factory ChatPageEntity.fromJson(Map<String, dynamic> json) => ChatPageEntity(
        threadId: json['threadId'] as int,
        closed: json['closed'] as bool,
        tier: json['tier'] as String,
        messages: (json['messages'] as List<dynamic>)
            .map((m) => ChatMessageEntity.fromJson((m as Map).cast<String, dynamic>()))
            .toList(),
      );

  @override
  List<Object?> get props => [threadId, closed, tier, messages];
}
