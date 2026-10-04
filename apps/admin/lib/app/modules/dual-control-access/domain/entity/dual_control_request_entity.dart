import 'package:equatable/equatable.dart';

/// One request of the decision 45 gate as `GET /api/dual-control-access`
/// answers it since round 18 (decisions 223–227): who opened it and who
/// approved it are panel users from the session, shown by NAME — never
/// e-mail. One approval by a user other than the requester grants it.
class DualControlRequestEntity extends Equatable {
  const DualControlRequestEntity({
    required this.id,
    required this.accountabilityLogEntryId,
    required this.legalBasis,
    required this.status,
    this.requestedBy,
    this.requestedByName,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    required this.createdAt,
  });

  final int id;
  final int accountabilityLogEntryId;
  final String legalBasis;

  /// pending | granted | void — `void` is a request from before round 18
  /// whose approvers were typed (decision 225): it never counts.
  final String status;

  /// Null only on a voided request.
  final int? requestedBy;
  final String? requestedByName;
  final int? approvedBy;
  final String? approvedByName;
  final String? approvedAt;
  final String createdAt;

  bool get isPending => status == 'pending';

  factory DualControlRequestEntity.fromJson(Map<String, dynamic> json) => DualControlRequestEntity(
        id: (json['id'] as num).toInt(),
        accountabilityLogEntryId: (json['accountabilityLogEntryId'] as num).toInt(),
        legalBasis: json['legalBasis'] as String,
        status: json['status'] as String,
        requestedBy: (json['requestedBy'] as num?)?.toInt(),
        requestedByName: json['requestedByName'] as String?,
        approvedBy: (json['approvedBy'] as num?)?.toInt(),
        approvedByName: json['approvedByName'] as String?,
        approvedAt: json['approvedAt'] as String?,
        createdAt: json['createdAt'] as String,
      );

  @override
  List<Object?> get props => [
        id, accountabilityLogEntryId, legalBasis, status, requestedBy,
        requestedByName, approvedBy, approvedByName, approvedAt, createdAt,
      ];
}

/// What the request form sends (`dualControlCreateDto`): WHAT is asked and
/// WHY — never who asks; the API takes the requester from the session
/// (decision 223).
class DualControlRequestDraft extends Equatable {
  const DualControlRequestDraft({required this.accountabilityLogEntryId, required this.legalBasis});

  final int accountabilityLogEntryId;
  final String legalBasis;

  Map<String, dynamic> toJson() => {
        'accountabilityLogEntryId': accountabilityLogEntryId,
        'legalBasis': legalBasis,
      };

  @override
  List<Object?> get props => [accountabilityLogEntryId, legalBasis];
}
