import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/entity/app_session_entity.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/login_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/login_bloc.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _session = AppSessionEntity(accessToken: 'access-1', refreshToken: 'refresh-1', accountId: 7);

void main() {
  late MockAuthRepository repository;
  late IdentityBloc identityBloc;
  late LocalPrefs localPrefs;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    identityBloc = IdentityBloc();
    localPrefs = LocalPrefs();
  });

  LoginBloc build() => LoginBloc(LoginUsecase(repository), identityBloc, localPrefs);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('valid credentials: identifies the account and persists the refresh '
      'token', () async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Right(_session));

    final bloc = build()
      ..add(const LoginSubmitted(email: 'ana@example.com', password: 'senha certa'));
    await settle();

    expect(bloc.state, const LoginSuccess());
    expect(identityBloc.state.token, 'access-1');
    expect(await localPrefs.getAppRefreshToken(), 'refresh-1');
  });

  test('TWO_FACTOR_REQUIRED switches to the code step instead of an error '
      '(decision 124 — TOTP only when the account enabled it)', () async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Left(
        Failure(message: '2fa', statusCode: 401, code: 'TWO_FACTOR_REQUIRED')));

    final bloc = build()
      ..add(const LoginSubmitted(email: 'ana@example.com', password: 'senha certa'));
    await settle();

    expect(
      bloc.state,
      const LoginTwoFactorRequired(email: 'ana@example.com', password: 'senha certa'),
    );
    expect(identityBloc.state.token, isNull);
  });

  test('a wrong TOTP code re-shows the step with invalidCode set', () async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Left(
        Failure(message: '2fa', statusCode: 401, code: 'TWO_FACTOR_REQUIRED')));

    final bloc = build()
      ..add(const LoginSubmitted(
        email: 'ana@example.com',
        password: 'senha certa',
        totpCode: '000000',
      ));
    await settle();

    expect(
      bloc.state,
      const LoginTwoFactorRequired(
        email: 'ana@example.com',
        password: 'senha certa',
        invalidCode: true,
      ),
    );
  });

  test('wrong credentials show a plain error, not the two-factor step', () async {
    const failure = Failure(message: 'bad', statusCode: 401, code: 'UNAUTHORIZED');
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const LoginSubmitted(email: 'a@b.com', password: 'wrong'));
    await settle();

    expect(bloc.state, const LoginReady(failure: failure));
  });
}
