import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/entity/app_session_entity.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/register_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/register_bloc.dart';

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

  RegisterBloc build() => RegisterBloc(RegisterUsecase(repository), identityBloc, localPrefs);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('on success: identifies the account and persists the refresh token '
      '(decision 122 — no "keep signed in" choice for the app)', () async {
    when(() => repository.register(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          consentVersion: any(named: 'consentVersion'),
        )).thenAnswer((_) async => const Right(_session));

    final bloc = build()
      ..add(const RegisterSubmitted(
        displayName: 'Ana',
        email: 'ana@example.com',
        password: 'uma senha longa o suficiente',
        consentVersion: 'v1',
      ));
    await settle();

    expect(bloc.state, const RegisterSuccess());
    expect(identityBloc.state.token, 'access-1');
    expect(identityBloc.state.role, Role.reporter);
    expect(await localPrefs.getAppRefreshToken(), 'refresh-1');
  });

  test('a duplicate email keeps the form with the failure, IdentityBloc '
      'untouched', () async {
    const failure = Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE');
    when(() => repository.register(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          consentVersion: any(named: 'consentVersion'),
        )).thenAnswer((_) async => const Left(failure));

    final bloc = build()
      ..add(const RegisterSubmitted(
        displayName: 'Ana',
        email: 'ana@example.com',
        password: 'uma senha longa o suficiente',
        consentVersion: 'v1',
      ));
    await settle();

    expect(bloc.state, const RegisterReady(failure: failure));
    expect(identityBloc.state.token, isNull);
  });
}
