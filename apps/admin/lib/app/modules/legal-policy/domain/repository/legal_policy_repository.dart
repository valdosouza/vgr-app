import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/legal_policy_entities.dart';

/// Contract of the Legal Gate admin surface (L3, decisions 103-109).
abstract class LegalPolicyRepository {
  Future<Either<Failure, List<JurisdictionEntity>>> listJurisdictions();

  /// Kill switch (107): tightening applies immediately; loosening comes
  /// back as a pending state on the row.
  Future<Either<Failure, JurisdictionEntity>> requestState(String code, String state);

  /// Confirms a pending loosening — DIFFERENT user, judged server-side.
  Future<Either<Failure, JurisdictionEntity>> confirmState(String code);

  Future<Either<Failure, List<CapabilityOverviewEntity>>> listCapabilities(
      String jurisdiction);

  Future<Either<Failure, List<LegalRuleEntity>>> listRules({
    String? capability,
    String? jurisdiction,
  });

  Future<Either<Failure, LegalRuleEntity>> proposeRule(LegalRuleProposal proposal);

  /// Activates the rule and supersedes the previous version (107) —
  /// DIFFERENT user than the proposer, judged server-side.
  Future<Either<Failure, LegalRuleEntity>> approveRule(int id);

  Future<Either<Failure, LegalRuleEntity>> rejectRule(int id);
}
