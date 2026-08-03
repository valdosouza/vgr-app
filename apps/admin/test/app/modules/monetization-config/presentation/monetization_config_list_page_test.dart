import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_widgets/vgr_widgets.dart';
import 'package:vgr_admin/app/modules/monetization-config/domain/entity/fee_rule_entity.dart';
import 'package:vgr_admin/app/modules/monetization-config/domain/repository/fee_rule_repository.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/bloc/monetization_config_bloc.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/bloc/monetization_config_event.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/page/monetization_config_list_page.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/entity/risk_tier_config_entity.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/repository/risk_config_repository.dart';
import '../../../../helpers/session_access.dart';

import '../../../../helpers/pump_localized.dart';

class MockFeeRuleRepository extends Mock implements FeeRuleRepository {}

class MockRiskConfigRepository extends Mock implements RiskConfigRepository {}


void main() {
  late MockFeeRuleRepository feeRuleRepository;
  late MockRiskConfigRepository riskConfigRepository;

  const rules = [
    FeeRuleEntity(category: null, feePercent: 10, paymentModeAllowed: {PaymentMode.intermediated, PaymentMode.peerToPeer}),
    FeeRuleEntity(category: 'trafficking', feePercent: 5, paymentModeAllowed: {PaymentMode.intermediated}),
    FeeRuleEntity(category: 'lost_pet', feePercent: 2, paymentModeAllowed: {PaymentMode.intermediated}),
  ];

  const riskTiers = [
    RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.high),
    RiskTierConfigEntity(category: 'lost_pet', tier: RiskTier.low),
  ];

  setUp(() {
    grantAllPrivileges();
    feeRuleRepository = MockFeeRuleRepository();
    riskConfigRepository = MockRiskConfigRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => MonetizationConfigBloc(feeRuleRepository, riskConfigRepository)..add(const FetchRequested()),
        child: const MonetizationConfigListPage(),
      ),
    );
  }

  testWidgets('renders the global default row and one row per configured Category', (tester) async {
    when(() => feeRuleRepository.list()).thenAnswer((_) async => const Right(rules));
    when(() => riskConfigRepository.list()).thenAnswer((_) async => const Right(riskTiers));

    await pumpPage(tester);

    expect(find.text('Global default'), findsOneWidget);
    expect(find.text('trafficking'), findsOneWidget);
    expect(find.text('lost_pet'), findsOneWidget);
  });

  testWidgets('the peer-to-peer checkbox is disabled for a high-tier Category', (tester) async {
    when(() => feeRuleRepository.list()).thenAnswer((_) async => const Right(rules));
    when(() => riskConfigRepository.list()).thenAnswer((_) async => const Right(riskTiers));

    await pumpPage(tester);

    final trafficking = tester.widget<VgrCheckbox>(find.byKey(const Key('peer-to-peer-checkbox-trafficking')));
    final lostPet = tester.widget<VgrCheckbox>(find.byKey(const Key('peer-to-peer-checkbox-lost_pet')));

    expect(trafficking.onChanged, isNull);
    expect(lostPet.onChanged, isNotNull);
  });

  testWidgets("editing a low-tier Category's fee percent persists without a page reload", (tester) async {
    when(() => feeRuleRepository.list()).thenAnswer((_) async => const Right(rules));
    when(() => riskConfigRepository.list()).thenAnswer((_) async => const Right(riskTiers));
    when(() => feeRuleRepository.upsert('lost_pet', 3, {PaymentMode.intermediated}))
        .thenAnswer((_) async => const Right(unit));

    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('fee-percent-field-lost_pet')), '3');
    await tester.tap(find.byKey(const Key('save-button-lost_pet')));
    await tester.pumpAndSettle();

    verify(() => feeRuleRepository.upsert('lost_pet', 3, {PaymentMode.intermediated})).called(1);
    verify(() => feeRuleRepository.list()).called(1);
  });
}
