import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/entity/app_session_entity.dart';
import 'package:vgr_mobile/app/modules/auth/domain/gateway/social_sign_in_gateway.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/login_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/login_with_google_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/login_bloc.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/page/login_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSocialSignInGateway extends Mock implements SocialSignInGateway {}

const _session = AppSessionEntity(accessToken: 'access-1', refreshToken: 'refresh-1', accountId: 7);

void main() {
  late MockAuthRepository repository;
  late MockSocialSignInGateway socialGateway;
  late IdentityBloc identityBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    socialGateway = MockSocialSignInGateway();
    identityBloc = IdentityBloc();
  });

  Future<void> pumpPage(WidgetTester tester, {VoidCallback? onDone}) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => LoginBloc(
          LoginUsecase(repository),
          LoginWithGoogleUsecase(socialGateway, repository),
          identityBloc,
          LocalPrefs(),
        ),
        child: LoginPage(onDone: onDone),
      ),
    );
  }

  testWidgets('valid credentials call the done seam', (tester) async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Right(_session));
    var done = false;
    await pumpPage(tester, onDone: () => done = true);

    await tester.enterText(find.byKey(const Key('login-email-field')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('login-password-field')), 'senha certa');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(identityBloc.state.token, 'access-1');
  });

  testWidgets('two-factor: credentials accepted moves to the code step, '
      'submitting the code logs in', (tester) async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: null,
        )).thenAnswer((_) async => const Left(
        Failure(message: '2fa', statusCode: 401, code: 'TWO_FACTOR_REQUIRED')));
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: '123456',
        )).thenAnswer((_) async => const Right(_session));
    var done = false;
    await pumpPage(tester, onDone: () => done = true);

    await tester.enterText(find.byKey(const Key('login-email-field')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('login-password-field')), 'senha certa');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-totp-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-totp-field')), '123456');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
  });

  testWidgets('wrong credentials show an error, not the two-factor step',
      (tester) async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Left(
        Failure(message: 'bad', statusCode: 401, code: 'UNAUTHORIZED')));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('login-email-field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password-field')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.byKey(const Key('login-totp-field')), findsNothing);
  });

  testWidgets('Google button calls the done seam on success (decision 152)',
      (tester) async {
    when(() => socialGateway.signInWithGoogle()).thenAnswer((_) async => 'raw-id-token');
    when(() => repository.loginWithProvider(provider: 'google', idToken: 'raw-id-token'))
        .thenAnswer((_) async => const Right(_session));
    var done = false;
    await pumpPage(tester, onDone: () => done = true);

    await tester.tap(find.byKey(const Key('login-google-button')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(identityBloc.state.token, 'access-1');
  });

  testWidgets('Google button hidden during the two-factor step', (tester) async {
    when(() => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          totpCode: any(named: 'totpCode'),
        )).thenAnswer((_) async => const Left(
        Failure(message: '2fa', statusCode: 401, code: 'TWO_FACTOR_REQUIRED')));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('login-email-field')), 'ana@example.com');
    await tester.enterText(find.byKey(const Key('login-password-field')), 'senha certa');
    await tester.tap(find.byKey(const Key('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-google-button')), findsNothing);
  });
}
