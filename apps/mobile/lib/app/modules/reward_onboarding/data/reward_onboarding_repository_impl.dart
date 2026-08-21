import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/reward_recipient_profile_entity.dart';
import '../domain/repository/reward_onboarding_repository.dart';

class RewardOnboardingRepositoryImpl implements RewardOnboardingRepository {
  RewardOnboardingRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, bool>> getStatus() async {
    try {
      final response = await _apiClient.get('/app-reward/onboarding');
      final data = response['data'] as Map<String, dynamic>;
      return Right(data['onboarded'] as bool);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<Either<Failure, void>> submit(RewardRecipientProfileEntity profile) async {
    try {
      await _apiClient.post('/app-reward/onboarding', {
        'legalName': profile.legalName,
        'email': profile.email,
        'taxId': profile.taxId,
        'mobilePhone': profile.mobilePhone,
        'monthlyIncome': profile.monthlyIncome,
        'address': {
          'street': profile.street,
          'number': profile.number,
          'neighborhood': profile.neighborhood,
          'postalCode': profile.postalCode,
        },
      });
      return const Right(null);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }
}
