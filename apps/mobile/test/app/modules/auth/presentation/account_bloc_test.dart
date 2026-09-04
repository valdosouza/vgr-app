import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/sign_out_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/account_bloc.dart';
import 'package:vgr_mobile/app/modules/rating/domain/entity/rating_entities.dart';
import 'package:vgr_mobile/app/modules/rating/domain/repository/rating_repository.dart';
import 'package:vgr_mobile/app/modules/rating/domain/usecase/get_my_reputation_usecase.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

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
    identityBloc = IdentityBloc()
      ..add(const ProviderLoginCompleted(
        role: Role.reporter,
        anonymityMode: AnonymityMode.identifiedNoReward,
        token: 'jwt',
      ));
  });

  AccountBloc build() => AccountBloc(
        SignOutUsecase(repository),
        identityBloc,
        localPrefs,
        GetMyReputationUsecase(ratingRepository),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('sign-out resets identity to anonymous and clears the refresh token '
      'even when the API call fails', () async {
    when(() => repository.signOutEverywhere())
        .thenAnswer((_) async => const Left(Failure(message: 'gone', code: 'UNAUTHORIZED')));
    await localPrefs.setAppRefreshToken('refresh-1');

    final bloc = build()..add(const AccountSignOutPressed());
    await settle();

    expect(bloc.state, const AccountSignedOut());
    expect(identityBloc.state.role, Role.anonymous);
    expect(identityBloc.state.token, isNull);
    expect(await localPrefs.getAppRefreshToken(), isNull);
  });

  group('AccountStarted — my reputation (decisions 184/185)', () {
    test('loads the aggregate and stops the loading flag', () async {
      when(() => ratingRepository.getMyReputation())
          .thenAnswer((_) async => const Right(ReputationEntity(count: 7, average: 4.29)));

      final bloc = build()..add(const AccountStarted());
      await settle();

      final state = bloc.state as AccountReady;
      expect(state.reputation, const ReputationEntity(count: 7, average: 4.29));
      expect(state.reputationLoading, isFalse);
    });

    test('below the k-anonymity floor: count only, average null — rendered as-is', () async {
      when(() => ratingRepository.getMyReputation())
          .thenAnswer((_) async => const Right(ReputationEntity(count: 2, average: null)));

      final bloc = build()..add(const AccountStarted());
      await settle();

      final state = bloc.state as AccountReady;
      expect(state.reputation!.count, 2);
      expect(state.reputation!.average, isNull);
    });

    test('a failed read is best-effort (123, optional section) — clears the loading '
        'flag without wedging the page', () async {
      when(() => ratingRepository.getMyReputation()).thenAnswer(
          (_) async => const Left(Failure(message: 'boom', statusCode: 500, code: 'INTERNAL')));

      final bloc = build()..add(const AccountStarted());
      await settle();

      final state = bloc.state as AccountReady;
      expect(state.reputation, isNull);
      expect(state.reputationLoading, isFalse);
    });
  });
}
