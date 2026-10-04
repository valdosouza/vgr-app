import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/app_widget.dart';
import 'package:vgr_admin/app/modules/home/home_module.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../helpers/pump_localized.dart';
import '../../../helpers/session_access.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocalPrefs extends Mock implements LocalPrefs {}

/// The REAL shell (`HomeModule`) under an already-admin session, with the
/// API client stubbed: the menu tree comes from `/api/core/menus`, every
/// other call fails so screens render their error state — enough to prove
/// the shell mounts them inside its outlet (decision 215).
class _TestModule extends Module {
  _TestModule(this.apiClient, this.localPrefs);

  final ApiClient apiClient;
  final LocalPrefs localPrefs;

  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()
          ..add(const ProviderLoginCompleted(
            role: Role.admin,
            anonymityMode: AnonymityMode.anonymous,
            token: 'jwt',
          ))),
        Bind.factory<ApiClient>((i) => apiClient),
        Bind.factory<LocalPrefs>((i) => localPrefs),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/login', child: (_, __) => const SizedBox.shrink(key: Key('login-stub'))),
        ModuleRoute('/', module: HomeModule()),
      ];
}

const _menus = {
  'data': [
    {
      'id': null,
      'description': 'Operations',
      'interfaces': [
        {'id': 1, 'description': 'Risk Tier Configuration', 'i18nKey': 'risk_config', 'privileges': ['VIEW', 'UPDATE']},
        {'id': 5, 'description': 'Monetization Config', 'i18nKey': 'monetization_config', 'privileges': ['VIEW']},
      ],
    },
    {
      'id': null,
      'description': 'Administration',
      'interfaces': [
        {'id': 6, 'description': 'Users', 'i18nKey': 'users', 'privileges': ['VIEW', 'UPDATE']},
      ],
    },
  ],
};

void main() {
  late MockApiClient apiClient;
  late MockLocalPrefs localPrefs;

  setUp(() {
    apiClient = MockApiClient();
    localPrefs = MockLocalPrefs();
    SessionAccess.instance.clear();
    when(() => apiClient.get(any(), token: any(named: 'token'), headers: any(named: 'headers')))
        .thenThrow(const Failure(message: 'offline', code: 'OFFLINE'));
    when(() => apiClient.get('/api/core/menus', token: any(named: 'token'), headers: any(named: 'headers')))
        .thenAnswer((_) async => _menus);
    when(() => localPrefs.clearSession()).thenAnswer((_) async {});
    when(() => localPrefs.setKeepConnected(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    revokeAllPrivileges();
    Modular.destroy();
  });

  Future<void> pumpShell(WidgetTester tester, {double width = 1400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalizedApp(
      tester,
      ModularApp(module: _TestModule(apiClient, localPrefs), child: const AppWidget()),
    );
    // flutter_modular 5.0.3 debounces navigate() by ~500 ms on the widget
    // test's fake clock (same as login_navigation_test).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Every list tile of the two navigation columns, by key.
  bool selected(WidgetTester tester, String key) =>
      tester.widget<VgrListTile>(find.byKey(Key(key))).selected;

  testWidgets('after login the shell opens the welcome content and lists the modules '
      '(decision 215)', (tester) async {
    await pumpShell(tester);

    expect(Modular.to.path, '/welcome');
    expect(find.byKey(const Key('home-welcome')), findsOneWidget);
    expect(find.byKey(const Key('shell-modules-column')), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);
    expect(find.text('Administration'), findsOneWidget);
    // No module picked yet → no second column.
    expect(find.byKey(const Key('shell-screens-column')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu is in the semantics tree beside the outlet — screen readers reach it '
      '(browser test of 2026-10-04)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpShell(tester);

    // The outlet's route barrier used to block every sibling painted before
    // it: the whole menu was missing, only the outlet's content remained.
    expect(find.semantics.byLabel('Operations'), findsOne);
    expect(find.semantics.byLabel('Administration'), findsOne);
    expect(find.semantics.byLabel('Welcome'), findsOne);

    await tester.tap(find.byKey(const Key('menu-module-Operations')));
    await tester.pumpAndSettle();
    expect(find.semantics.byLabel('Risk Config'), findsOne);
    semantics.dispose();
  });

  testWidgets('switching the language repaints the open screen, not only the selector '
      '(browser test of 2026-10-04)', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byKey(const Key('menu-module-Operations')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Operations'), findsOneWidget);

    await tester.element(find.byKey(const Key('home-welcome'))).setLocale(const Locale('pt', 'BR'));
    await tester.pumpAndSettle();

    // The outlet's content and the menu, not just the widgets that read the
    // locale, follow the switch.
    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.text('Welcome'), findsNothing);
    expect(find.text('Operações'), findsOneWidget);
  });

  testWidgets('clicking a module shows its screens; clicking a screen opens it in the outlet '
      'and highlights both', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const Key('menu-module-Operations')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-screens-column')), findsOneWidget);
    expect(find.text('Risk Config'), findsOneWidget);
    expect(find.text('Monetization Config'), findsOneWidget);
    expect(selected(tester, 'menu-module-Operations'), isTrue);
    expect(selected(tester, 'menu-module-Administration'), isFalse);

    await tester.tap(find.byKey(const Key('menu-interface-risk_config')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(Modular.to.path, '/risk-config/');
    // The screen renders INSIDE the shell: menu columns still there, and the
    // page header (not an app bar) shows the screen title.
    expect(find.byKey(const Key('shell-modules-column')), findsOneWidget);
    expect(find.byKey(const Key('vgr-page-title')), findsOneWidget);
    expect(selected(tester, 'menu-interface-risk_config'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refresh on a screen URL keeps the screen and highlights it in the columns',
      (tester) async {
    await pumpShell(tester);
    Modular.to.navigate('/users/');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    // Simulates the post-frame sync the shell runs on start: the URL says
    // /users/, so the Administration module and the Users screen light up.
    Modular.get<MenuBloc>().add(const MenuInterfaceSelected('users'));
    await tester.pumpAndSettle();

    expect(selected(tester, 'menu-module-Administration'), isTrue);
    expect(selected(tester, 'menu-interface-users'), isTrue);
    expect(find.byKey(const Key('vgr-page-title')), findsOneWidget);
  });

  testWidgets('loading the menu feeds SessionAccess (can() reflects the grants)', (tester) async {
    await pumpShell(tester);

    // Permissions endpoint failed (stub) → the tree is the fallback source.
    expect(SessionAccess.instance.can('risk_config', Privileges.update), isTrue);
    expect(SessionAccess.instance.can('risk_config', Privileges.delete), isFalse);
    expect(SessionAccess.instance.can('privileges', Privileges.view), isFalse);
  });

  testWidgets('a user with zero grants sees the empty-menu message in the column', (tester) async {
    when(() => apiClient.get('/api/core/menus', token: any(named: 'token'), headers: any(named: 'headers')))
        .thenAnswer((_) async => const {'data': <dynamic>[]});
    await pumpShell(tester);

    expect(find.text('No screens available for your user — ask an Admin for access.'), findsOneWidget);
    expect(find.byKey(const Key('home-welcome')), findsOneWidget);
  });

  testWidgets('a failed menu load shows the error with retry, and the outlet still works',
      (tester) async {
    when(() => apiClient.get('/api/core/menus', token: any(named: 'token'), headers: any(named: 'headers')))
        .thenThrow(const Failure(message: 'Internal error', statusCode: 500));
    await pumpShell(tester);

    expect(find.text('Internal error'), findsOneWidget);
    expect(find.byKey(const Key('menu-retry-button')), findsOneWidget);
    expect(find.byKey(const Key('home-welcome')), findsOneWidget);
  });

  testWidgets('below 850 px the menu becomes a drawer with the same screens', (tester) async {
    await pumpShell(tester, width: 600);

    expect(find.byKey(const Key('shell-modules-column')), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-drawer')), findsOneWidget);
    expect(find.byKey(const Key('menu-interface-users')), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu-interface-users')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(Modular.to.path, '/users/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign out clears the persisted session, the privileges and the identity, then '
      'goes to the login page', (tester) async {
    await pumpShell(tester);
    expect(SessionAccess.instance.can('risk_config', Privileges.view), isTrue);

    await tester.tap(find.byKey(const Key('user-badge-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-badge-logout')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    verify(() => localPrefs.clearSession()).called(1);
    verify(() => localPrefs.setKeepConnected(false)).called(1);
    verify(() => apiClient.setToken(null)).called(1);
    expect(SessionAccess.instance.can('risk_config', Privileges.view), isFalse);
    expect(Modular.get<IdentityBloc>().state.role, Role.anonymous);
    expect(Modular.to.path, '/login');
    expect(find.byKey(const Key('login-stub')), findsOneWidget);
  });
}
