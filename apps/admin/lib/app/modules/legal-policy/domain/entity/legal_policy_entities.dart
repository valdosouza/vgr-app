import 'package:equatable/equatable.dart';

/// `GET /api/legal-policy/jurisdictions` (decisions 76/107). A pending
/// state exists only for LOOSENING — tightening applied immediately.
class JurisdictionEntity extends Equatable {
  const JurisdictionEntity({
    required this.code,
    required this.name,
    required this.operationalState,
    required this.isSandbox,
    this.pendingState,
    this.pendingBy,
  });

  final String code;
  final String name;
  final String operationalState;
  final bool isSandbox;
  final String? pendingState;
  final int? pendingBy;

  factory JurisdictionEntity.fromJson(Map<String, dynamic> json) =>
      JurisdictionEntity(
        code: json['code'] as String,
        name: json['name'] as String,
        operationalState: json['operationalState'] as String,
        isSandbox: json['isSandbox'] as bool,
        pendingState: json['pendingState'] as String?,
        pendingBy: json['pendingBy'] as int?,
      );

  @override
  List<Object?> get props =>
      [code, name, operationalState, isSandbox, pendingState, pendingBy];
}

/// One catalog row with the verdict the gate would give TODAY in the
/// selected jurisdiction (decision 103).
class CapabilityOverviewEntity extends Equatable {
  const CapabilityOverviewEntity({
    required this.capability,
    required this.description,
    required this.module,
    required this.effectiveStatus,
    this.activeRuleId,
    this.activeRuleVersion,
    this.activeRuleReviewState,
    this.activeRuleExpiresAt,
  });

  final String capability;
  final String description;
  final String module;

  /// allowed | restricted | blocked | unreviewed.
  final String effectiveStatus;
  final int? activeRuleId;
  final int? activeRuleVersion;
  final String? activeRuleReviewState;
  final String? activeRuleExpiresAt;

  factory CapabilityOverviewEntity.fromJson(Map<String, dynamic> json) {
    final rule = json['activeRule'] as Map?;
    return CapabilityOverviewEntity(
      capability: json['capability'] as String,
      description: json['description'] as String,
      module: json['module'] as String,
      effectiveStatus: json['effectiveStatus'] as String,
      activeRuleId: rule?['id'] as int?,
      activeRuleVersion: rule?['version'] as int?,
      activeRuleReviewState: rule?['reviewState'] as String?,
      activeRuleExpiresAt: rule?['expiresAt'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        capability, description, module, effectiveStatus,
        activeRuleId, activeRuleVersion, activeRuleReviewState, activeRuleExpiresAt,
      ];
}

/// Full versioned rule row (plan §6 — "what applied on day X?" must have
/// an answer, so versions are rows, never destructive updates).
class LegalRuleEntity extends Equatable {
  const LegalRuleEntity({
    required this.id,
    required this.capability,
    required this.jurisdictionCode,
    required this.version,
    required this.status,
    this.reason,
    this.legalBasis,
    required this.reviewState,
    required this.ruleState,
    this.effectiveFrom,
    this.expiresAt,
    required this.proposedBy,
    this.approvedBy,
  });

  final int id;
  final String capability;
  final String jurisdictionCode;
  final int version;
  final String status;
  final String? reason;
  final String? legalBasis;
  final String reviewState;

  /// proposed | active | rejected | superseded (decision 107).
  final String ruleState;
  final String? effectiveFrom;
  final String? expiresAt;
  final int proposedBy;
  final int? approvedBy;

  factory LegalRuleEntity.fromJson(Map<String, dynamic> json) => LegalRuleEntity(
        id: json['id'] as int,
        capability: json['capability'] as String,
        jurisdictionCode: json['jurisdictionCode'] as String,
        version: json['version'] as int,
        status: json['status'] as String,
        reason: json['reason'] as String?,
        legalBasis: json['legalBasis'] as String?,
        reviewState: json['reviewState'] as String,
        ruleState: json['ruleState'] as String,
        effectiveFrom: json['effectiveFrom'] as String?,
        expiresAt: json['expiresAt'] as String?,
        proposedBy: json['proposedBy'] as int,
        approvedBy: json['approvedBy'] as int?,
      );

  @override
  List<Object?> get props => [
        id, capability, jurisdictionCode, version, status, reason, legalBasis,
        reviewState, ruleState, effectiveFrom, expiresAt, proposedBy, approvedBy,
      ];
}

/// Proposal body for `POST /api/legal-policy/rules` (decision 107 — born
/// 'proposed'; reason mandatory whenever not allowed, decision 78).
class LegalRuleProposal extends Equatable {
  const LegalRuleProposal({
    required this.capability,
    required this.jurisdictionCode,
    required this.status,
    this.reason,
    this.legalBasis,
    this.expiresInDays = 180,
  });

  final String capability;
  final String jurisdictionCode;
  final String status;
  final String? reason;
  final String? legalBasis;
  final int expiresInDays;

  Map<String, dynamic> toJson() => {
        'capability': capability,
        'jurisdictionCode': jurisdictionCode,
        'status': status,
        if (reason != null) 'reason': reason,
        if (legalBasis != null) 'legalBasis': legalBasis,
        'expiresInDays': expiresInDays,
      };

  @override
  List<Object?> get props =>
      [capability, jurisdictionCode, status, reason, legalBasis, expiresInDays];
}
