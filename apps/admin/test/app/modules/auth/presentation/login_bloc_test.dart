import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_bloc.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_event.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLocalPrefs extends Mock implements LocalPrefs {}

void main() {
  late MockAuthRepository authRepository;
  late IdentityBloc identityBloc;
  late MockLocalPrefs localPrefs;
  late LoginBloc bloc;

  setUp(() {
    authRepository = MockAuthRepository();
    identityBloc = IdentityBloc();
    localPrefs = MockLocalPrefs();
    when(() => localPrefs.getRememberedEmail()).thenAnswer((_) async => null);
    when(() => localPrefs.getKeepConnected()).thenAnswer((_) async => false);
    when(() => localPrefs.setKeepConnected(any())).thenAnswer((_) async {});
    when(() => localPrefs.setSessionToken(any())).thenAnswer((_) async {});
    when(() => localPrefs.setRememberedEmail(any())).thenAnswer((_) async {});
    bloc = LoginBloc(authRepository, identityBloc, localPrefs);
  });

  tearDown(() {
    bloc.close();
    identityBloc.close();
  });

  test('emits [Loading, Success] and updates IdentityBloc to admin with the JWT on success', () async {
    when(() => authRepository.login('valdo@vgr.com.br', 'teste')).thenAnswer((_) async => const Right('fake.jwt.token'));

    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<LoginLoading>(),
        isA<LoginSuccess>(),
      ]),
    );

    bloc.add(const LoginSubmitted(email: 'valdo@vgr.com.br', password: 'teste'));

    await Future<void>.delayed(Duration.zero);
    expect(identityBloc.state.role, Role.admin);
    expect(identityBloc.state.token, 'fake.jwt.token');
  });

  test('emits [Loading, Error] and leaves IdentityBloc untouched on failure', () async {
    when(() => authRepository.login('valdo@vgr.com.br', 'wrong')).thenAnswer(
      (_) async => const Left(Failure(message: 'Invalid email or password', statusCode: 401)),
    );

    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<LoginLoading>(),
        isA<LoginError>().having((s) => s.message, 'message', 'Invalid email or password'),
      ]),
    );

    bloc.add(const LoginSubmitted(email: 'valdo@vgr.com.br', password: 'wrong'));

    await Future<void>.delayed(Duration.zero);
    expect(identityBloc.state.role, Role.anonymous);
  });
}
