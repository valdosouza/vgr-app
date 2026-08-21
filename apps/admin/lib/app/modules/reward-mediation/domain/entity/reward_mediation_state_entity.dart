import 'package:equatable/equatable.dart';

/// One live resolution of the dual-control cycle (decisions 148/149):
/// proposed by mediator A, approved by a DIFFERENT mediator B, executed at
/// the rail only after the contest window.
class RewardResolutionEntity extends Equatable {
  const RewardResolutionEntity({
    required this.id,
    required this.outcome,
    required this.reason,
    required this.criteriaVersion,
    required this.proposedBy,
    required this.status,
    this.approvedBy,
    this.windowEndsAt,
  });

  final int id;
  final String outcome;
  final String reason;
  final String criteriaVersion;

  /// Panel user id — the approver must be a DIFFERENT user (decision 148).
  final int proposedBy;
  final String status;
  final int? approvedBy;
  final String? windowEndsAt;

  factory RewardResolutionEntity.fromJson(Map<String, dynamic> json) =>
      RewardResolutionEntity(
        id: json['id'] as int,
        outcome: json['outcome'] as String,
        reason: json['reason'] as String,
        criteriaVersion: json['criteriaVersion'] as String,
        proposedBy: json['proposedBy'] as int,
        status: json['status'] as String,
        approvedBy: json['approvedBy'] as int?,
        windowEndsAt: json['windowEndsAt'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, outcome, reason, criteriaVersion, proposedBy, status, approvedBy, windowEndsAt];
}

/// A party's open contest (decision 149) — blocks execution until a
/// mediator closes it with a note.
class RewardContestEntity extends Equatable {
  const RewardContestEntity({
    required this.id,
    required this.accountId,
    required this.body,
  });

  final int id;
  final int accountId;
  final String body;

  factory RewardContestEntity.fromJson(Map<String, dynamic> json) =>
      RewardContestEntity(
        id: json['id'] as int,
        accountId: json['accountId'] as int,
        body: json['body'] as String,
      );

  @override
  List<Object?> get props => [id, accountId, body];
}

/// One row of the append-only mediation trail (decisions 98/76).
class MediationLogEntryEntity extends Equatable {
  const MediationLogEntryEntity({
    required this.event,
    required this.actorRef,
    this.details,
    this.createdAt,
  });

  final String event;
  final String actorRef;
  final String? details;
  final String? createdAt;

  factory MediationLogEntryEntity.fromJson(Map<String, dynamic> json) =>
      MediationLogEntryEntity(
        event: json['event'] as String,
        actorRef: json['actorRef'] as String,
        details: json['details'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  @override
  List<Object?> get props => [event, actorRef, details, createdAt];
}

/// `GET /api/reward-mediation/:reportId` — everything the screen shows.
/// The report and its reward offer are 1:1, so the case id is the handle.
class RewardMediationStateEntity extends Equatable {
  const RewardMediationStateEntity({
    required this.reportId,
    required this.amountCents,
    required this.offerStatus,
    required this.criteriaVersion,
    this.resolution,
    this.openContests = const [],
    this.log = const [],
  });

  final int reportId;
  final int amountCents;
  final String offerStatus;

  /// Decision 150: the criteria version stamped at reserve time — the rule
  /// the mediation judges by, whatever is published later.
  final String criteriaVersion;
  final RewardResolutionEntity? resolution;
  final List<RewardContestEntity> openContests;
  final List<MediationLogEntryEntity> log;

  factory RewardMediationStateEntity.fromJson(Map<String, dynamic> json) {
    final offer = (json['offer'] as Map).cast<String, dynamic>();
    return RewardMediationStateEntity(
      reportId: offer['reportId'] as int,
      amountCents: offer['amountCents'] as int,
      offerStatus: offer['status'] as String,
      criteriaVersion: offer['criteriaVersion'] as String? ?? '',
      resolution: json['resolution'] == null
          ? null
          : RewardResolutionEntity.fromJson(
              (json['resolution'] as Map).cast<String, dynamic>()),
      openContests: (json['openContests'] as List<dynamic>? ?? const [])
          .map((c) => RewardContestEntity.fromJson((c as Map).cast<String, dynamic>()))
          .toList(),
      log: (json['log'] as List<dynamic>? ?? const [])
          .map((l) =>
              MediationLogEntryEntity.fromJson((l as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [reportId, amountCents, offerStatus, criteriaVersion, resolution, openContests, log];
}
