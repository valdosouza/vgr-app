import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/sign_out_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/account_bloc.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late IdentityBloc identityBloc;
  late LocalPrefs localPrefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    localPrefs = LocalPrefs();
    identityBloc = IdentityBloc()
      ..add(const ProviderLoginCompleted(
        role: Role.reporter,
        anonymityMode: AnonymityMode.identifiedNoReward,
        token: 'jwt',
      ));
  });

  AccountBloc build() => AccountBloc(SignOutUsecase(repository), identityBloc, localPrefs);

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
}
