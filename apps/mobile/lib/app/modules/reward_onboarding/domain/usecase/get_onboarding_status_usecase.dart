import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/reward_onboarding_repository.dart';

class GetOnboardingStatusUsecase {
  const GetOnboardingStatusUsecase(this._repository);

  final RewardOnboardingRepository _repository;

  Future<Either<Failure, bool>> call() => _repository.getStatus();
}
