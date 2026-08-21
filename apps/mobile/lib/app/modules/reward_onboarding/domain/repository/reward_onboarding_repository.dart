import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/reward_recipient_profile_entity.dart';

/// Contract of the reward-onboarding data layer (`/app-reward/onboarding`).
abstract class RewardOnboardingRepository {
  /// Whether this account can already be targeted by a reserve.
  Future<Either<Failure, bool>> getStatus();

  /// Sends the KYC data through to the rail. Left(DUPLICATE) when this
  /// account already onboarded (409, one profile per account).
  Future<Either<Failure, void>> submit(RewardRecipientProfileEntity profile);
}
