import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/legal_policy_entities.dart';

/// Contract of the Legal Gate admin surface (L3, decisions 103-109).
abstract class LegalPolicyRepository {
  /// Paged, `filter` on code / name (PS0, decision 220).
  Future<Either<Failure, PagedResult<JurisdictionEntity>>> listJurisdictions(PagedQuery query);

  /// Kill switch (107): tightening applies immediately; loosening comes
  /// back as a pending state on the row.
  Future<Either<Failure, JurisdictionEntity>> requestState(String code, String state);

  /// Confirms a pending loosening — DIFFERENT user, judged server-side.
  Future<Either<Failure, JurisdictionEntity>> confirmState(String code);

  /// Paged, per jurisdiction (mandatory), `filter` on capability /
  /// description.
  Future<Either<Failure, PagedResult<CapabilityOverviewEntity>>> listCapabilities(
    String jurisdiction,
    PagedQuery query,
  );

  /// Paged, `filter` on capability / jurisdiction code / legal basis.
  Future<Either<Failure, PagedResult<LegalRuleEntity>>> listRules(PagedQuery query);

  Future<Either<Failure, LegalRuleEntity>> proposeRule(LegalRuleProposal proposal);

  /// Activates the rule and supersedes the previous version (107) —
  /// DIFFERENT user than the proposer, judged server-side.
  Future<Either<Failure, LegalRuleEntity>> approveRule(int id);

  Future<Either<Failure, LegalRuleEntity>> rejectRule(int id);
}
