import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/reward_mediation_state_entity.dart';
import '../domain/repository/reward_mediation_repository.dart';

class RewardMediationRepositoryImpl implements RewardMediationRepository {
  RewardMediationRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, RewardMediationStateEntity>> getState(int reportId) async {
    try {
      final json = await _apiClient.get('/api/reward-mediation/$reportId');
      final data = (json['data'] as Map).cast<String, dynamic>();
      return Right(RewardMediationStateEntity.fromJson(data));
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, void>> publishCriteria(String version, String body) =>
      _post('/api/reward-mediation/criteria', {'version': version, 'body': body});

  @override
  Future<Either<Failure, void>> propose(int reportId, String outcome, String reason) =>
      _post('/api/reward-mediation/$reportId/propose',
          {'outcome': outcome, 'reason': reason});

  @override
  Future<Either<Failure, void>> approve(int reportId) =>
      _post('/api/reward-mediation/$reportId/approve', {});

  @override
  Future<Either<Failure, void>> cancel(int reportId) =>
      _post('/api/reward-mediation/$reportId/cancel', {});

  @override
  Future<Either<Failure, void>> execute(int reportId) =>
      _post('/api/reward-mediation/$reportId/execute', {});

  @override
  Future<Either<Failure, void>> closeContest(int contestId, String note) =>
      _post('/api/reward-mediation/contests/$contestId/close', {'note': note});

  Future<Either<Failure, void>> _post(String path, Map<String, dynamic> body) async {
    try {
      await _apiClient.post(path, body);
      return const Right(null);
    } on Failure catch (f) {
      return Left(f);
    }
  }
}
