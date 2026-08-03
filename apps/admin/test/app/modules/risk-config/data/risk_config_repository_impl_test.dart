import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/risk-config/data/risk_config_repository_impl.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/entity/risk_tier_config_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late RiskConfigRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = RiskConfigRepositoryImpl(apiClient);
  });

  test('upsert reaches the RiskTierConfig endpoint and returns Right(unit) on success', () async {
    when(() => apiClient.put('/api/risk-config/trafficking', {'tier': 'high'})).thenAnswer(
      (_) async => {
        'ok': true,
        'data': {'category': 'trafficking', 'tier': 'high'},
      },
    );

    final result = await repository.upsert('trafficking', RiskTier.high);

    expect(result, const Right<Failure, Unit>(unit));
    verify(() => apiClient.put('/api/risk-config/trafficking', {'tier': 'high'})).called(1);
  });

  test('upsert converts an ApiClient Failure into Left', () async {
    when(() => apiClient.put(any(), any())).thenThrow(
      const Failure(message: 'Forbidden', statusCode: 403),
    );

    final result = await repository.upsert('trafficking', RiskTier.high);

    expect(result, const Left<Failure, Unit>(Failure(message: 'Forbidden', statusCode: 403)));
  });

  test('list returns Right(entities) mapped in full from the API response', () async {
    when(() => apiClient.get('/api/risk-config')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': [
          {'category': 'trafficking', 'tier': 'high'},
          {'category': 'traffic', 'tier': 'low'},
        ],
      },
    );

    final result = await repository.list();

    // dartz's Right.== does not deep-compare a wrapped List — unwrap first
    // so the matcher package's collection-aware equality actually applies.
    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (entities) => expect(entities, [
        const RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.high),
        const RiskTierConfigEntity(category: 'traffic', tier: RiskTier.low),
      ]),
    );
  });

  test('list converts an ApiClient Failure into Left', () async {
    when(() => apiClient.get(any())).thenThrow(
      const Failure(message: 'No connectivity'),
    );

    final result = await repository.list();

    expect(result, const Left<Failure, List<RiskTierConfigEntity>>(Failure(message: 'No connectivity')));
  });
}
