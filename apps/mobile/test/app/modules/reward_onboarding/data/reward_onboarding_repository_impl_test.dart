import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/data/reward_onboarding_repository_impl.dart';
import 'package:vgr_mobile/app/modules/reward_onboarding/domain/entity/reward_recipient_profile_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

const _profile = RewardRecipientProfileEntity(
  legalName: 'Helper Name',
  email: 'helper@example.com',
  taxId: '12345678900',
  mobilePhone: '11999998888',
  monthlyIncome: 3000,
  street: 'Rua A',
  number: '10',
  neighborhood: 'Centro',
  postalCode: '01001000',
);

void main() {
  late MockApiClient apiClient;
  late RewardOnboardingRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = RewardOnboardingRepositoryImpl(apiClient);
  });

  group('getStatus', () {
    test('reads the onboarded flag from the app plane', () async {
      when(() => apiClient.get('/app-reward/onboarding')).thenAnswer(
        (_) async => {
          'ok': true,
          'data': {'onboarded': true},
        },
      );

      final result = await repository.getStatus();

      expect(result.getOrElse(() => false), isTrue);
    });

    test('transport failure becomes OFFLINE', () async {
      when(() => apiClient.get('/app-reward/onboarding'))
          .thenThrow(Exception('socket'));

      final result = await repository.getStatus();

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
    });
  });

  group('submit', () {
    test('posts the KYC data (decision 143) — the rail sees it, the VGR '
        'never persists it', () async {
      when(() => apiClient.post('/app-reward/onboarding', any()))
          .thenAnswer((_) async => {'ok': true});

      final result = await repository.submit(_profile);

      expect(result.isRight(), isTrue);
      final body = verify(
        () => apiClient.post('/app-reward/onboarding', captureAny()),
      ).captured.single as Map<String, dynamic>;
      expect(body, {
        'legalName': 'Helper Name',
        'email': 'helper@example.com',
        'taxId': '12345678900',
        'mobilePhone': '11999998888',
        'monthlyIncome': 3000,
        'address': {
          'street': 'Rua A',
          'number': '10',
          'neighborhood': 'Centro',
          'postalCode': '01001000',
        },
      });
    });

    test('a repeat onboarding (409) surfaces as Left(DUPLICATE)', () async {
      when(() => apiClient.post('/app-reward/onboarding', any())).thenThrow(
        const Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE'),
      );

      final result = await repository.submit(_profile);

      expect(result.fold((f) => f.code, (_) => null), 'DUPLICATE');
    });

    test('transport failure becomes OFFLINE', () async {
      when(() => apiClient.post('/app-reward/onboarding', any()))
          .thenThrow(Exception('socket'));

      final result = await repository.submit(_profile);

      expect(result.fold((f) => f.code, (_) => null), 'OFFLINE');
    });
  });
}
