import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/monetization-config/domain/entity/fee_rule_entity.dart';
import 'package:vgr_admin/app/modules/monetization-config/domain/repository/fee_rule_repository.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/bloc/monetization_config_bloc.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/bloc/monetization_config_event.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/bloc/monetization_config_state.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/entity/risk_tier_config_entity.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/repository/risk_config_repository.dart';

class MockFeeRuleRepository extends Mock implements FeeRuleRepository {}

class MockRiskConfigRepository extends Mock implements RiskConfigRepository {}

void main() {
  late MockFeeRuleRepository feeRuleRepository;
  late MockRiskConfigRepository riskConfigRepository;
  late MonetizationConfigBloc bloc;

  const rules = [
    FeeRuleEntity(category: null, feePercent: 10, paymentModeAllowed: {PaymentMode.intermediated, PaymentMode.peerToPeer}),
    FeeRuleEntity(category: 'trafficking', feePercent: 5, paymentModeAllowed: {PaymentMode.intermediated}),
  ];

  const riskTiers = [
    RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.high),
    RiskTierConfigEntity(category: 'lost_pet', tier: RiskTier.low),
  ];

  setUp(() {
    feeRuleRepository = MockFeeRuleRepository();
    riskConfigRepository = MockRiskConfigRepository();
    bloc = MonetizationConfigBloc(feeRuleRepository, riskConfigRepository);
  });

  tearDown(() => bloc.close());

  test('emits [Loading, Loaded(rules, riskTiers)] on initial fetch', () async {
    when(() => feeRuleRepository.list()).thenAnswer((_) async => const Right(rules));
    when(() => riskConfigRepository.list()).thenAnswer((_) async => const Right(riskTiers));

    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<MonetizationConfigLoading>(),
        isA<MonetizationConfigLoaded>()
            .having((s) => s.rules, 'rules', rules)
            .having((s) => s.isHighTier('trafficking'), 'isHighTier(trafficking)', true)
            .having((s) => s.isHighTier('lost_pet'), 'isHighTier(lost_pet)', false),
      ]),
    );

    bloc.add(const FetchRequested());
  });

  test("editing a low-tier Category's rule persists and updates state without a full page reload", () async {
    when(() => feeRuleRepository.list()).thenAnswer((_) async => const Right(rules));
    when(() => riskConfigRepository.list()).thenAnswer((_) async => const Right(riskTiers));
    when(() => feeRuleRepository.upsert('lost_pet', 2, {PaymentMode.intermediated, PaymentMode.peerToPeer}))
        .thenAnswer((_) async => const Right(unit));

    bloc.add(const FetchRequested());
    await bloc.stream.firstWhere((s) => s is MonetizationConfigLoaded);

    expectLater(
      bloc.stream,
      emits(isA<MonetizationConfigLoaded>().having(
        (s) => s.rules,
        'rules',
        contains(const FeeRuleEntity(
          category: 'lost_pet',
          feePercent: 2,
          paymentModeAllowed: {PaymentMode.intermediated, PaymentMode.peerToPeer},
        )),
      )),
    );

    bloc.add(const RuleEdited(
      category: 'lost_pet',
      feePercent: 2,
      paymentModeAllowed: {PaymentMode.intermediated, PaymentMode.peerToPeer},
    ));

    await Future<void>.delayed(Duration.zero);
    verify(() => feeRuleRepository.list()).called(1);
  });

  test('rejects adding peer_to_peer to a high-tier Category (decision 58) without calling the repository', () async {
    when(() => feeRuleRepository.list()).thenAnswer((_) async => const Right(rules));
    when(() => riskConfigRepository.list()).thenAnswer((_) async => const Right(riskTiers));

    bloc.add(const FetchRequested());
    await bloc.stream.firstWhere((s) => s is MonetizationConfigLoaded);

    expectLater(bloc.stream, emits(isA<MonetizationConfigError>()));

    bloc.add(const RuleEdited(
      category: 'trafficking',
      feePercent: 5,
      paymentModeAllowed: {PaymentMode.intermediated, PaymentMode.peerToPeer},
    ));

    await Future<void>.delayed(Duration.zero);
    verifyNever(() => feeRuleRepository.upsert(any(), any(), any()));
  });
}
