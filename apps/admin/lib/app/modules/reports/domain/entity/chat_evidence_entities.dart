import 'package:equatable/equatable.dart';

/// `GET /api/reports/:id/chat` (C3, decision 175) — the panel's read of a
/// case's masked chat as EVIDENCE. Behind the `chat_evidence` grant (kind
/// 'R', VIEW, no bootstrap) stacked on `reports` VIEW; every read is
/// audited server-side (`tb_admin_audit`, entity `report_chat`). Read only:
/// nothing here can post, hide or delete a message.
///
/// The panel is the platform (60): the helper is always identifiable
/// internally, the reporter only when the report is not anonymous (160).
/// An anonymous reporter arrives with `accountId: null, displayName: null`
/// — the internal `reporter_account_id` / `client_key` NEVER travel (23).
/// Timestamps are EXACT (the panel is not a participant; 41 protects the
/// reporter-side correlation, not the platform's own record).
class ChatParticipantEvidenceEntity extends Equatable {
  const ChatParticipantEvidenceEntity({
    required this.role,
    required this.participantToken,
    required this.accountId,
    required this.displayName,
    required this.anonymousChoice,
  });

  /// `reporter | helper`.
  final String role;

  /// Opaque per (thread, participant) — what the messages' `sender` refers to.
  final String participantToken;
  final int? accountId;
  final String? displayName;

  /// The participant chose anonymity on the app side (helper offer
  /// `anonymous`, or an anonymous report) — a marker, never an identity.
  final bool anonymousChoice;

  factory ChatParticipantEvidenceEntity.fromJson(Map<String, dynamic> json) =>
      ChatParticipantEvidenceEntity(
        role: json['role'] as String,
        participantToken: json['participantToken'] as String,
        accountId: (json['accountId'] as num?)?.toInt(),
        displayName: json['displayName'] as String?,
        anonymousChoice: json['anonymousChoice'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [role, participantToken, accountId, displayName, anonymousChoice];
}

/// One message as stored: [text] is `null` once the case was purged (131,
/// 173 — the skeleton keeps counts and timestamps).
class ChatMessageEvidenceEntity extends Equatable {
  const ChatMessageEvidenceEntity({
    required this.messageId,
    required this.sender,
    required this.text,
    required this.purged,
    required this.createdAt,
  });

  final int messageId;

  /// A `participantToken` of the thread.
  final String sender;
  final String? text;
  final bool purged;
  final String createdAt;

  factory ChatMessageEvidenceEntity.fromJson(Map<String, dynamic> json) =>
      ChatMessageEvidenceEntity(
        messageId: (json['messageId'] as num).toInt(),
        sender: json['sender'] as String,
        text: json['text'] as String?,
        purged: json['purged'] as bool? ?? false,
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props => [messageId, sender, text, purged, createdAt];
}

/// One bilateral thread (report, helper) with its two masks and the
/// messages ascending by id, capped by `?limit` — [hasMore] says the cap
/// cut the page. `false` when the API does not send it.
class ChatThreadEvidenceEntity extends Equatable {
  const ChatThreadEvidenceEntity({
    required this.threadId,
    required this.helpOfferId,
    required this.createdAt,
    required this.closed,
    required this.participants,
    required this.messages,
    this.hasMore = false,
  });

  final int threadId;
  final int helpOfferId;
  final String createdAt;

  /// Derived from the case (173): resolved or hidden → writing closed,
  /// reading kept until the purge.
  final bool closed;
  final List<ChatParticipantEvidenceEntity> participants;
  final List<ChatMessageEvidenceEntity> messages;
  final bool hasMore;

  factory ChatThreadEvidenceEntity.fromJson(Map<String, dynamic> json) =>
      ChatThreadEvidenceEntity(
        threadId: (json['threadId'] as num).toInt(),
        helpOfferId: (json['helpOfferId'] as num).toInt(),
        createdAt: json['createdAt'] as String,
        closed: json['closed'] as bool? ?? false,
        participants: ((json['participants'] as List?) ?? const [])
            .map((e) =>
                ChatParticipantEvidenceEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        messages: ((json['messages'] as List?) ?? const [])
            .map((e) => ChatMessageEvidenceEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        hasMore: json['hasMore'] as bool? ?? false,
      );

  @override
  List<Object?> get props =>
      [threadId, helpOfferId, createdAt, closed, participants, messages, hasMore];
}

/// `{ reportId, tier, threads }`. A case with no thread is `threads: []`
/// (its existence is already known to a `reports` VIEW holder); a missing
/// or deleted case is a 404 that never reaches this type.
class ReportChatEntity extends Equatable {
  const ReportChatEntity({required this.reportId, required this.tier, required this.threads});

  final int reportId;
  final String tier;
  final List<ChatThreadEvidenceEntity> threads;

  factory ReportChatEntity.fromJson(Map<String, dynamic> json) => ReportChatEntity(
        reportId: (json['reportId'] as num).toInt(),
        tier: json['tier'] as String,
        threads: ((json['threads'] as List?) ?? const [])
            .map((e) => ChatThreadEvidenceEntity.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  @override
  List<Object?> get props => [reportId, tier, threads];
}
