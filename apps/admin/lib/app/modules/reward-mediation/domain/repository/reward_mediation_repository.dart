import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/reward_mediation_state_entity.dart';

/// Contract of the mediation data layer (decisions 98/148/149/150). Every
/// mutation answers nothing — the bloc reloads the state afterwards, so
/// the screen only ever renders what the SERVER says the case is (the
/// distinct-approver and window rules, for two, only it can judge).
abstract class RewardMediationRepository {
  Future<Either<Failure, RewardMediationStateEntity>> getState(int reportId);
  Future<Either<Failure, void>> publishCriteria(String version, String body);
  Future<Either<Failure, void>> propose(int reportId, String outcome, String reason);
  Future<Either<Failure, void>> approve(int reportId);
  Future<Either<Failure, void>> cancel(int reportId);
  Future<Either<Failure, void>> execute(int reportId);
  Future<Either<Failure, void>> closeContest(int contestId, String note);
}
