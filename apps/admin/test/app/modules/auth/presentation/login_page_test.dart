import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/domain/login_result.dart';
import 'package:vgr_admin/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_bloc.dart';
import 'package:vgr_admin/app/modules/auth/presentation/page/login_page.dart';

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
    when(() => localPrefs.getRememberedEmail()).thenAnswer((_) async => null);
    when(() => localPrefs.getKeepConnected()).thenAnswer((_) async => false);
    when(() => localPrefs.setKeepConnected(any())).thenAnswer((_) async {});
    when(() => localPrefs.setSessionToken(any())).thenAnswer((_) async {});
    when(() => localPrefs.setRememberedEmail(any())).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => LoginBloc(authRepository, identityBloc, localPrefs),
          child: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('submitting valid credentials updates IdentityBloc to admin', (tester) async {
    when(() => authRepository.login('valdo@vgr.com.br', 'teste', totpCode: any(named: 'totpCode')))
        .thenAnswer((_) async => const Right(LoginSession('fake.jwt.token')));

    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('login-email-field')), 'valdo@vgr.com.br');
    await tester.enterText(find.byKey(const Key('login-password-field')), 'teste');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(identityBloc.state.role, Role.admin);
  });

  testWidgets('shows the error message on invalid credentials', (tester) async {
    when(() => authRepository.login('valdo@vgr.com.br', 'wrong', totpCode: any(named: 'totpCode'))).thenAnswer(
      (_) async => const Left(Failure(message: 'Invalid email or password', statusCode: 401)),
    );

    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('login-email-field')), 'valdo@vgr.com.br');
    await tester.enterText(find.byKey(const Key('login-password-field')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(identityBloc.state.role, Role.anonymous);
  });
}
