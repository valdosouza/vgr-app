import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/monetization-config/data/fee_rule_repository_impl.dart';
import 'package:vgr_admin/app/modules/monetization-config/domain/entity/fee_rule_entity.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient apiClient;
  late FeeRuleRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = FeeRuleRepositoryImpl(apiClient);
  });

  test('list returns Right(entities) mapped in full from the API response, including the global (null-category) rule', () async {
    when(() => apiClient.get('/api/monetization-config')).thenAnswer(
      (_) async => {
        'ok': true,
        'data': [
          {'category': null, 'feePercent': 10, 'paymentModeAllowed': ['intermediated', 'peer_to_peer']},
          {'category': 'trafficking', 'feePercent': 5, 'paymentModeAllowed': ['intermediated']},
        ],
      },
    );

    final result = await repository.list();

    result.fold(
      (failure) => fail('expected Right, got Left($failure)'),
      (entities) => expect(entities, [
        const FeeRuleEntity(category: null, feePercent: 10, paymentModeAllowed: {PaymentMode.intermediated, PaymentMode.peerToPeer}),
        const FeeRuleEntity(category: 'trafficking', feePercent: 5, paymentModeAllowed: {PaymentMode.intermediated}),
      ]),
    );
  });

  test('list converts an ApiClient Failure into Left', () async {
    when(() => apiClient.get(any())).thenThrow(const Failure(message: 'No connectivity'));

    final result = await repository.list();

    expect(result, const Left<Failure, List<FeeRuleEntity>>(Failure(message: 'No connectivity')));
  });

  test('upsert reaches the Category endpoint and returns Right(unit) on success', () async {
    when(() => apiClient.put('/api/monetization-config/trafficking', {
          'feePercent': 5.0,
          'paymentModeAllowed': ['intermediated'],
        })).thenAnswer((_) async => {'ok': true, 'data': {}});

    final result = await repository.upsert('trafficking', 5, {PaymentMode.intermediated});

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('upsert reaches the "global" endpoint when category is null', () async {
    when(() => apiClient.put('/api/monetization-config/global', {
          'feePercent': 10.0,
          'paymentModeAllowed': ['intermediated', 'peer_to_peer'],
        })).thenAnswer((_) async => {'ok': true, 'data': {}});

    final result = await repository.upsert(null, 10, {PaymentMode.intermediated, PaymentMode.peerToPeer});

    expect(result, const Right<Failure, Unit>(unit));
  });

  test('upsert converts an ApiClient Failure into Left', () async {
    when(() => apiClient.put(any(), any())).thenThrow(const Failure(message: 'Forbidden', statusCode: 403));

    final result = await repository.upsert('trafficking', 5, {PaymentMode.intermediated});

    expect(result, const Left<Failure, Unit>(Failure(message: 'Forbidden', statusCode: 403)));
  });
}
