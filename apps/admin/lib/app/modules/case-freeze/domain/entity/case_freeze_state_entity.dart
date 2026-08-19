import 'package:equatable/equatable.dart';

/// Step 1 of the dual-control unfreeze, as served by the API (141d).
class PendingUnfreezeEntity extends Equatable {
  const PendingUnfreezeEntity({
    required this.reason,
    required this.requestedBy,
    required this.requestedAt,
  });

  final String reason;

  /// Panel user id — the approver must be a DIFFERENT user (141d).
  final int requestedBy;
  final String requestedAt;

  factory PendingUnfreezeEntity.fromJson(Map<String, dynamic> json) =>
      PendingUnfreezeEntity(
        reason: json['reason'] as String,
        requestedBy: json['requestedBy'] as int,
        requestedAt: json['requestedAt'] as String,
      );

  @override
  List<Object?> get props => [reason, requestedBy, requestedAt];
}

/// `GET /api/case-freeze/:id` — everything the minimal screen shows
/// (decision 142).
class CaseFreezeStateEntity extends Equatable {
  const CaseFreezeStateEntity({
    required this.reportId,
    required this.status,
    required this.frozen,
    this.frozenReason,
    this.frozenAt,
    this.pendingUnfreeze,
  });

  final int reportId;
  final String status;
  final bool frozen;
  final String? frozenReason;
  final String? frozenAt;
  final PendingUnfreezeEntity? pendingUnfreeze;

  factory CaseFreezeStateEntity.fromJson(Map<String, dynamic> json) =>
      CaseFreezeStateEntity(
        reportId: json['reportId'] as int,
        status: json['status'] as String,
        frozen: json['frozen'] as bool,
        frozenReason: json['frozenReason'] as String?,
        frozenAt: json['frozenAt'] as String?,
        pendingUnfreeze: json['pendingUnfreeze'] == null
            ? null
            : PendingUnfreezeEntity.fromJson(
                (json['pendingUnfreeze'] as Map).cast<String, dynamic>()),
      );

  @override
  List<Object?> get props =>
      [reportId, status, frozen, frozenReason, frozenAt, pendingUnfreeze];
}
