import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/reward_recipient_profile_entity.dart';
import '../repository/reward_onboarding_repository.dart';

class SubmitOnboardingUsecase {
  const SubmitOnboardingUsecase(this._repository);

  final RewardOnboardingRepository _repository;

  Future<Either<Failure, void>> call(RewardRecipientProfileEntity profile) =>
      _repository.submit(profile);
}
