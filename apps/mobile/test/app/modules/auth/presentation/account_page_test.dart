import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/sign_out_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/account_bloc.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/page/account_page.dart';
import 'package:vgr_mobile/app/modules/rating/domain/entity/rating_entities.dart';
import 'package:vgr_mobile/app/modules/rating/domain/repository/rating_repository.dart';
import 'package:vgr_mobile/app/modules/rating/domain/usecase/get_my_reputation_usecase.dart';

import '../../../../helpers/pump_localized.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

/// "My reputation" section (RT2, decisions 184/185): the app renders
/// exactly `{count, average}` as served — `average` null below the
/// k-anonymity floor is NEVER recomputed here, only rendered as the
/// "not enough yet" copy.
void main() {
  late MockAuthRepository repository;
  late MockRatingRepository ratingRepository;
  late IdentityBloc identityBloc;
  late LocalPrefs localPrefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    ratingRepository = MockRatingRepository();
    localPrefs = LocalPrefs();
    identityBloc = IdentityBloc();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider<AccountBloc>(
        create: (_) => AccountBloc(
          SignOutUsecase(repository),
          identityBloc,
          localPrefs,
          GetMyReputationUsecase(ratingRepository),
        ),
        child: const AccountPage(),
      ),
    );
  }

  testWidgets('count at/above the floor shows both count and average', (tester) async {
    when(() => ratingRepository.getMyReputation())
        .thenAnswer((_) async => const Right(ReputationEntity(count: 7, average: 4.29)));

    await pumpPage(tester);

    expect(find.byKey(const Key('account-reputation-count')), findsOneWidget);
    expect(find.byKey(const Key('account-reputation-average')), findsOneWidget);
    expect(find.byKey(const Key('account-reputation-not-enough')), findsNothing);
  });

  testWidgets('below the floor shows count and the "not enough yet" caption, no average',
      (tester) async {
    when(() => ratingRepository.getMyReputation())
        .thenAnswer((_) async => const Right(ReputationEntity(count: 2, average: null)));

    await pumpPage(tester);

    expect(find.byKey(const Key('account-reputation-count')), findsOneWidget);
    expect(find.byKey(const Key('account-reputation-not-enough')), findsOneWidget);
    expect(find.byKey(const Key('account-reputation-average')), findsNothing);
  });

  testWidgets('a failed read shows neither section — never blocks sign-out', (tester) async {
    when(() => ratingRepository.getMyReputation()).thenAnswer(
        (_) async => const Left(Failure(message: 'boom', statusCode: 500, code: 'INTERNAL')));

    await pumpPage(tester);

    expect(find.byKey(const Key('account-reputation-count')), findsNothing);
    expect(find.byKey(const Key('account-sign-out-button')), findsOneWidget);
  });
}
