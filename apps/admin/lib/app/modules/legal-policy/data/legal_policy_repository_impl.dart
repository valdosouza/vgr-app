import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/legal_policy_entities.dart';
import '../domain/repository/legal_policy_repository.dart';

class LegalPolicyRepositoryImpl implements LegalPolicyRepository {
  LegalPolicyRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<JurisdictionEntity>>> listJurisdictions() async {
    try {
      final json = await _apiClient.get('/api/legal-policy/jurisdictions');
      return Right(_rows(json).map(JurisdictionEntity.fromJson).toList());
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
  Future<Either<Failure, List<CapabilityOverviewEntity>>> listCapabilities(
      String jurisdiction) async {
    try {
      final json = await _apiClient
          .get('/api/legal-policy/capabilities?jurisdiction=$jurisdiction');
      return Right(_rows(json).map(CapabilityOverviewEntity.fromJson).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, List<LegalRuleEntity>>> listRules({
    String? capability,
    String? jurisdiction,
  }) async {
    try {
      final query = [
        if (capability != null && capability.isNotEmpty) 'capability=$capability',
        if (jurisdiction != null && jurisdiction.isNotEmpty)
          'jurisdiction=$jurisdiction',
      ].join('&');
      final json = await _apiClient
          .get('/api/legal-policy/rules${query.isEmpty ? '' : '?$query'}');
      return Right(_rows(json).map(LegalRuleEntity.fromJson).toList());
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

  List<Map<String, dynamic>> _rows(Map<String, dynamic> json) =>
      (json['data'] as List<dynamic>)
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList();

  Map<String, dynamic> _row(Map<String, dynamic> json) =>
      (json['data'] as Map).cast<String, dynamic>();
}
