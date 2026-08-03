import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/auth/domain/repository/auth_repository.dart';
import 'package:vgr_admin/app/modules/auth/presentation/bloc/login_bloc.dart';
import 'package:vgr_admin/app/modules/auth/presentation/page/login_page.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('Home'));
}

class _TestModule extends Module {
  _TestModule(this.authRepository);

  final AuthRepository authRepository;

  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        Bind.factory<AuthRepository>((i) => authRepository),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/login',
          child: (_, __) => BlocProvider(
            create: (_) => LoginBloc(Modular.get<AuthRepository>(), Modular.get<IdentityBloc>()),
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
      when(() => authRepository.login('valdo@vgr.com.br', 'teste'))
          .thenAnswer((_) async => const Right('fake.jwt.token'));

      await tester.pumpWidget(
        ModularApp(module: _TestModule(authRepository), child: const _TestApp()),
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
