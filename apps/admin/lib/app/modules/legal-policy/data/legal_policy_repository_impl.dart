import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/legal_policy_entities.dart';
import '../domain/repository/legal_policy_repository.dart';

class LegalPolicyRepositoryImpl implements LegalPolicyRepository {
  LegalPolicyRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, PagedResult<JurisdictionEntity>>> listJurisdictions(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/legal-policy/jurisdictions?${query.toQueryString()}');
      return Right(PagedResult.fromJson(_row(json), JurisdictionEntity.fromJson));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, JurisdictionEntity>> requestState(
      String code, String state) async {
    try {
      final json = await _apiClient
          .put('/api/legal-policy/jurisdictions/$code/state', {'state': state});
      return Right(JurisdictionEntity.fromJson(_row(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, JurisdictionEntity>> confirmState(String code) async {
    try {
      final json = await _apiClient
          .post('/api/legal-policy/jurisdictions/$code/state/confirm', {});
      return Right(JurisdictionEntity.fromJson(_row(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PagedResult<CapabilityOverviewEntity>>> listCapabilities(
    String jurisdiction,
    PagedQuery query,
  ) async {
    try {
      final json = await _apiClient.get(
        '/api/legal-policy/capabilities'
        '?jurisdiction=${Uri.encodeQueryComponent(jurisdiction)}&${query.toQueryString()}',
      );
      return Right(PagedResult.fromJson(_row(json), CapabilityOverviewEntity.fromJson));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, PagedResult<LegalRuleEntity>>> listRules(PagedQuery query) async {
    try {
      final json = await _apiClient.get('/api/legal-policy/rules?${query.toQueryString()}');
      return Right(PagedResult.fromJson(_row(json), LegalRuleEntity.fromJson));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, LegalRuleEntity>> proposeRule(
      LegalRuleProposal proposal) async {
    try {
      final json =
          await _apiClient.post('/api/legal-policy/rules', proposal.toJson());
      return Right(LegalRuleEntity.fromJson(_row(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, LegalRuleEntity>> approveRule(int id) async {
    try {
      final json = await _apiClient.post('/api/legal-policy/rules/$id/approve', {});
      return Right(LegalRuleEntity.fromJson(_row(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, LegalRuleEntity>> rejectRule(int id) async {
    try {
      final json = await _apiClient.post('/api/legal-policy/rules/$id/reject', {});
      return Right(LegalRuleEntity.fromJson(_row(json)));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  Map<String, dynamic> _row(Map<String, dynamic> json) =>
      (json['data'] as Map).cast<String, dynamic>();
}
