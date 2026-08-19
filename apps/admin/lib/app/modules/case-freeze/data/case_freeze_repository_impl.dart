import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/case_freeze_state_entity.dart';
import '../domain/repository/case_freeze_repository.dart';

class CaseFreezeRepositoryImpl implements CaseFreezeRepository {
  CaseFreezeRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, CaseFreezeStateEntity>> getState(int reportId) async {
    try {
      final json = await _apiClient.get('/api/case-freeze/$reportId');
      return Right(CaseFreezeStateEntity.fromJson(json));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> freeze(int reportId, String reason) async {
    try {
      await _apiClient.post('/api/case-freeze/$reportId/freeze', {'reason': reason});
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> requestUnfreeze(int reportId, String reason) async {
    try {
      await _apiClient
          .post('/api/case-freeze/$reportId/unfreeze-request', {'reason': reason});
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> approveUnfreeze(int reportId) async {
    try {
      await _apiClient.post('/api/case-freeze/$reportId/unfreeze-approve', {});
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
