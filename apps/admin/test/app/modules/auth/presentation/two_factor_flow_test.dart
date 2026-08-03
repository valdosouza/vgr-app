import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/domain/login_result.dart';
import 'package:vgr_admin/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_bloc.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_event.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_state.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/two_factor_bloc.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLocalPrefs extends Mock implements LocalPrefs {}

void main() {
  late MockAuthRepository authRepository;
  late IdentityBloc identityBloc;
  late MockLocalPrefs localPrefs;

  setUp(() {
    authRepository = MockAuthRepository();
    identityBloc = IdentityBloc();
    localPrefs = MockLocalPrefs();
    when(() => localPrefs.setKeepConnected(any())).thenAnswer((_) async {});
    when(() => localPrefs.setSessionToken(any())).thenAnswer((_) async {});
    when(() => localPrefs.setRememberedEmail(any())).thenAnswer((_) async {});
  });

  tearDown(() => identityBloc.close());

  group('LoginBloc — two-factor branches (decision 114)', () {
    test('TWO_FACTOR_REQUIRED becomes the code step, not an error', () async {
      when(() => authRepository.login(any(), any(), totpCode: any(named: 'totpCode'))).thenAnswer(
        (_) async => const Left(Failure(
          message: 'Two-factor code required',
          statusCode: 401,
          code: 'TWO_FACTOR_REQUIRED',
        )),
      );
      final bloc = LoginBloc(authRepository, identityBloc, localPrefs);

      bloc.add(const LoginSubmitted(email: 'valdo@vgr.com.br', password: 'teste'));
      await expectLater(
        bloc.stream,
        emitsInOrder([isA<LoginLoading>(), isA<LoginTwoFactorRequired>()]),
      );
      // Credentials were fine — the session must NOT have opened.
      expect(identityBloc.state.token, isNull);
      await bloc.close();
    });

    test('a wrong code marks invalidCode so the field shows the error', () async {
      when(() => authRepository.login(any(), any(), totpCode: any(named: 'totpCode'))).thenAnswer(
        (_) async => const Left(Failure(
          message: 'Two-factor code required',
          statusCode: 401,
          code: 'TWO_FACTOR_REQUIRED',
        )),
      );
      final bloc = LoginBloc(authRepository, identityBloc, localPrefs);

      bloc.add(const LoginSubmitted(
        email: 'valdo@vgr.com.br',
        password: 'teste',
        totpCode: '000000',
      ));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<LoginLoading>(),
          isA<LoginTwoFactorRequired>().having((s) => s.invalidCode, 'invalidCode', isTrue),
        ]),
      );
      await bloc.close();
    });

    test('the enrollment branch opens NO session — enrollment is mandatory', () async {
      when(() => authRepository.login(any(), any(), totpCode: any(named: 'totpCode')))
          .thenAnswer((_) async => const Right(LoginEnrollmentRequired('enroll.token')));
      final bloc = LoginBloc(authRepository, identityBloc, localPrefs);

      bloc.add(const LoginSubmitted(email: 'valdo@vgr.com.br', password: 'teste'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<LoginLoading>(),
          isA<LoginEnrollmentPending>()
              .having((s) => s.enrollToken, 'enrollToken', 'enroll.token'),
        ]),
      );
      expect(identityBloc.state.token, isNull);
      verifyNever(() => localPrefs.setSessionToken(any()));
      await bloc.close();
    });

    test('completing enrollment opens the session and persists only under keep-connected', () async {
      final bloc = LoginBloc(authRepository, identityBloc, localPrefs);

      bloc.add(const LoginEnrollmentCompleted(jwt: 'fresh.jwt', keepConnected: true));
      await expectLater(bloc.stream, emitsInOrder([isA<LoginSuccess>()]));

      expect(identityBloc.state.role, Role.admin);
      expect(identityBloc.state.token, 'fresh.jwt');
      verify(() => localPrefs.setSessionToken('fresh.jwt')).called(1);
      await bloc.close();
    });
  });

  group('TwoFactorBloc', () {
    test('a wrong code keeps the QR on screen instead of losing the enrollment', () async {
      when(() => authRepository.startTwoFactorSetup(any())).thenAnswer(
        (_) async => const Right(TwoFactorSetup(secret: 'ABC', otpauthUri: 'otpauth://x')),
      );
      when(() => authRepository.activateTwoFactor(any(), any())).thenAnswer(
        (_) async => const Left(Failure(message: 'Invalid or expired code', statusCode: 401)),
      );
      final bloc = TwoFactorBloc(authRepository);

      bloc.add(const TwoFactorSetupRequested('enroll.token'));
      await expectLater(
        bloc.stream,
        emitsInOrder([isA<TwoFactorLoading>(), isA<TwoFactorSetupReady>()]),
      );

      bloc.add(const TwoFactorCodeSubmitted(enrollToken: 'enroll.token', code: '000000'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<TwoFactorLoading>(),
          isA<TwoFactorSetupReady>()
              .having((s) => s.invalidCode, 'invalidCode', isTrue)
              .having((s) => s.setup.secret, 'secret kept', 'ABC'),
        ]),
      );
      await bloc.close();
    });

    test('a valid code activates and surfaces the one-time recovery codes', () async {
      when(() => authRepository.startTwoFactorSetup(any())).thenAnswer(
        (_) async => const Right(TwoFactorSetup(secret: 'ABC', otpauthUri: 'otpauth://x')),
      );
      when(() => authRepository.activateTwoFactor(any(), any())).thenAnswer(
        (_) async => const Right(TwoFactorActivation(
          jwt: 'fresh.jwt',
          recoveryCodes: ['AAAA1111', 'BBBB2222'],
        )),
      );
      final bloc = TwoFactorBloc(authRepository);

      bloc.add(const TwoFactorSetupRequested('enroll.token'));
      await expectLater(
        bloc.stream,
        emitsInOrder([isA<TwoFactorLoading>(), isA<TwoFactorSetupReady>()]),
      );

      bloc.add(const TwoFactorCodeSubmitted(enrollToken: 'enroll.token', code: '123456'));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<TwoFactorLoading>(),
          isA<TwoFactorActivated>()
              .having((s) => s.activation.recoveryCodes.length, 'codes', 2),
        ]),
      );
      await bloc.close();
    });
  });
}
