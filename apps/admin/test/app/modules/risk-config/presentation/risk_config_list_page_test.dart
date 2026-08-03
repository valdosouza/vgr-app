import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/entity/risk_tier_config_entity.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/repository/risk_config_repository.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/bloc/risk_config_bloc.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/bloc/risk_config_event.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/page/risk_config_list_page.dart';
import '../../../../helpers/session_access.dart';

class MockRiskConfigRepository extends Mock implements RiskConfigRepository {}

void main() {
  late MockRiskConfigRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockRiskConfigRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => RiskConfigBloc(repository)..add(const FetchRequested()),
          child: const RiskConfigListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one row per Category with its current tier', (tester) async {
    when(() => repository.list()).thenAnswer(
      (_) async => const Right([
        RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.high),
        RiskTierConfigEntity(category: 'traffic', tier: RiskTier.low),
      ]),
    );

    await pumpPage(tester);

    expect(find.text('trafficking'), findsOneWidget);
    expect(find.text('traffic'), findsOneWidget);
  });

  testWidgets("editing a row's tier persists without a page reload", (tester) async {
    when(() => repository.list()).thenAnswer(
      (_) async => const Right([
        RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.low),
      ]),
    );
    when(() => repository.upsert('trafficking', RiskTier.high))
        .thenAnswer((_) async => const Right(unit));

    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('risk-tier-dropdown-trafficking')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('high').last);
    await tester.pumpAndSettle();

    verify(() => repository.upsert('trafficking', RiskTier.high)).called(1);
    verify(() => repository.list()).called(1); // only the initial fetch — no reload
    expect(find.text('trafficking'), findsOneWidget);
  });
}
