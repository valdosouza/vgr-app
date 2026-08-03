import 'package:equatable/equatable.dart';

/// Mirrors the API's `MembershipStatus` (decisions 51-52).
enum ResponderApprovalStatus { pending, approved, denied }

extension ResponderApprovalStatusJson on ResponderApprovalStatus {
  static ResponderApprovalStatus fromJson(String value) => ResponderApprovalStatus.values.byName(value);
}

class ResponderApprovalEntity extends Equatable {
  const ResponderApprovalEntity({
    required this.id,
    required this.userId,
    required this.status,
    required this.criteriaNotes,
  });

  final int id;
  final int userId;
  final ResponderApprovalStatus status;

  /// Free text pending decision 52's resolution — no eligibility rules
  /// are decided yet, so it's displayed as-is, not validated.
  final String? criteriaNotes;

  @override
  List<Object?> get props => [id, userId, status, criteriaNotes];
}
