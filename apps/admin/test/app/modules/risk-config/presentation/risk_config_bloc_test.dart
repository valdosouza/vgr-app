import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/entity/risk_tier_config_entity.dart';
import 'package:vgr_admin/app/modules/risk-config/domain/repository/risk_config_repository.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/bloc/risk_config_bloc.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/bloc/risk_config_event.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/bloc/risk_config_state.dart';

class MockRiskConfigRepository extends Mock implements RiskConfigRepository {}

void main() {
  late MockRiskConfigRepository repository;
  late RiskConfigBloc bloc;

  const items = [
    RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.high),
    RiskTierConfigEntity(category: 'traffic', tier: RiskTier.low),
  ];

  setUp(() {
    repository = MockRiskConfigRepository();
    bloc = RiskConfigBloc(repository);
  });

  tearDown(() => bloc.close());

  test('emits [Loading, Loaded(list)] on initial fetch', () async {
    when(() => repository.list()).thenAnswer((_) async => const Right(items));

    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<RiskConfigLoading>(),
        const RiskConfigLoaded(items),
      ]),
    );

    bloc.add(const FetchRequested());
  });

  test('emits an updated Loaded state after a successful tier edit, without a full page reload', () async {
    when(() => repository.list()).thenAnswer((_) async => const Right(items));
    when(() => repository.upsert('trafficking', RiskTier.medium))
        .thenAnswer((_) async => const Right(unit));

    bloc.add(const FetchRequested());
    await bloc.stream.firstWhere((s) => s is RiskConfigLoaded);

    expectLater(
      bloc.stream,
      emits(const RiskConfigLoaded([
        RiskTierConfigEntity(category: 'trafficking', tier: RiskTier.medium),
        RiskTierConfigEntity(category: 'traffic', tier: RiskTier.low),
      ])),
    );

    bloc.add(const TierEdited(category: 'trafficking', tier: RiskTier.medium));

    // list() must have run exactly once (the initial fetch) — the edit
    // updates local state directly instead of re-fetching the whole
    // list, which is the "no full page reload" guarantee.
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.list()).called(1);
  });
}
