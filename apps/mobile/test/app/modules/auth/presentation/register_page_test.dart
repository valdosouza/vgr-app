import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/auth/domain/entity/app_session_entity.dart';
import 'package:vgr_mobile/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_mobile/app/modules/auth/domain/usecase/register_usecase.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/bloc/register_bloc.dart';
import 'package:vgr_mobile/app/modules/auth/presentation/page/register_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _session = AppSessionEntity(accessToken: 'access-1', refreshToken: 'refresh-1', accountId: 7);

void main() {
  late MockAuthRepository repository;
  late IdentityBloc identityBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockAuthRepository();
    identityBloc = IdentityBloc();
  });

  Future<void> pumpPage(WidgetTester tester, {VoidCallback? onDone}) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => RegisterBloc(RegisterUsecase(repository), identityBloc, LocalPrefs()),
        child: RegisterPage(onDone: onDone),
      ),
    );
  }

  bool submitEnabled(WidgetTester tester) => tester
      .widget<VgrPrimaryButton>(find.byKey(const Key('register-submit-button')))
      .onPressed !=
      null;

  testWidgets('submit stays disabled until consent is checked', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('register-display-name-field')), 'Ana');
    await tester.enterText(
        find.byKey(const Key('register-email-field')), 'ana@example.com');
    await tester.enterText(
        find.byKey(const Key('register-password-field')), 'uma senha longa o suficiente');
    expect(submitEnabled(tester), isFalse);

    await tester.tap(find.byKey(const Key('register-consent-checkbox')));
    await tester.pump();
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('a successful registration calls the done seam', (tester) async {
    when(() => repository.register(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          consentVersion: any(named: 'consentVersion'),
        )).thenAnswer((_) async => const Right(_session));
    var done = false;
    await pumpPage(tester, onDone: () => done = true);

    await tester.enterText(find.byKey(const Key('register-display-name-field')), 'Ana');
    await tester.enterText(
        find.byKey(const Key('register-email-field')), 'ana@example.com');
    await tester.enterText(
        find.byKey(const Key('register-password-field')), 'uma senha longa o suficiente');
    await tester.tap(find.byKey(const Key('register-consent-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(identityBloc.state.token, 'access-1');
  });

  testWidgets('a duplicate email shows the translated error', (tester) async {
    when(() => repository.register(
          displayName: any(named: 'displayName'),
          email: any(named: 'email'),
          password: any(named: 'password'),
          consentVersion: any(named: 'consentVersion'),
        )).thenAnswer((_) async => const Left(
        Failure(message: 'dup', statusCode: 409, code: 'DUPLICATE')));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('register-display-name-field')), 'Ana');
    await tester.enterText(
        find.byKey(const Key('register-email-field')), 'ana@example.com');
    await tester.enterText(
        find.byKey(const Key('register-password-field')), 'uma senha longa o suficiente');
    await tester.tap(find.byKey(const Key('register-consent-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register-error')), findsOneWidget);
  });
}
