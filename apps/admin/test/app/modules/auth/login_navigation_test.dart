import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/domain/login_result.dart';
import 'package:vgr_admin/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_bloc.dart';
import 'package:vgr_admin/app/modules/auth/presentation/page/login_page.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockLocalPrefs extends Mock implements LocalPrefs {}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home'));
}

class _TestModule extends Module {
  _TestModule(this.authRepository, this.localPrefs);

  final AuthRepository authRepository;
  final LocalPrefs localPrefs;

  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        Bind.factory<AuthRepository>((i) => authRepository),
        Bind.factory<LocalPrefs>((i) => localPrefs),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/login',
          child: (_, __) => BlocProvider(
            create: (_) => LoginBloc(
              Modular.get<AuthRepository>(),
              Modular.get<IdentityBloc>(),
              Modular.get<LocalPrefs>(),
            ),
            child: const LoginPage(),
          ),
        ),
        ChildRoute('/', child: (_, __) => const _HomePage()),
      ];
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routeInformationParser: Modular.routeInformationParser,
      routerDelegate: Modular.routerDelegate,
    );
  }
}

void main() {
  tearDown(Modular.destroy);

  testWidgets(
    'submitting valid credentials navigates away from the login page',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.login('valdo@vgr.com.br', 'teste', totpCode: any(named: 'totpCode')))
          .thenAnswer((_) async => const Right(LoginSession('fake.jwt.token')));

      final localPrefs = MockLocalPrefs();
      when(() => localPrefs.getRememberedEmail()).thenAnswer((_) async => null);
      when(() => localPrefs.getKeepConnected()).thenAnswer((_) async => false);
      when(() => localPrefs.setKeepConnected(any())).thenAnswer((_) async {});
      when(() => localPrefs.setSessionToken(any())).thenAnswer((_) async {});
      when(() => localPrefs.setRememberedEmail(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ModularApp(module: _TestModule(authRepository, localPrefs), child: const _TestApp()),
      );
      await tester.pumpAndSettle();

      Modular.to.navigate('/login');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-email-field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login-email-field')), 'valdo@vgr.com.br');
      await tester.enterText(find.byKey(const Key('login-password-field')), 'teste');
      await tester.tap(find.byKey(const Key('login-submit-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-email-field')), findsNothing);
    },
  );
}
