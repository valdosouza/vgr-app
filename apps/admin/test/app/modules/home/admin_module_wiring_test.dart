import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/app_widget.dart';
import 'package:vgr_admin/app/modules/home/home_module.dart';
import 'package:vgr_admin/app/modules/home/interface_routes.dart';

import '../../../helpers/pump_localized.dart';
import '../../../helpers/session_access.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocalPrefs extends Mock implements LocalPrefs {}

/// Mounts the REAL shell (`HomeModule`, decision 215) under an already-admin
/// session, with the API client stubbed to fail — every screen then renders
/// its error state, which is enough to prove the route mounts a page inside
/// the outlet without throwing.
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
  List<ModularRoute> get routes => [ModuleRoute('/', module: HomeModule())];
}

void main() {
  late MockApiClient apiClient;
  late MockLocalPrefs localPrefs;

  setUp(() {
    apiClient = MockApiClient();
    localPrefs = MockLocalPrefs();
    when(() => apiClient.get(any(), token: any(named: 'token'), headers: any(named: 'headers')))
        .thenThrow(const Failure(message: 'offline', code: 'OFFLINE'));
    grantAllPrivileges();
  });

  tearDown(() {
    revokeAllPrivileges();
    Modular.destroy();
  });

  /// Regression class first found live on 2026-09-21: a screen reached
  /// through real navigation threw "Could not find the correct
  /// Provider<XBloc>" because its route mounted the page bare — page tests
  /// wrap a provider themselves and never catch that. Since the shell
  /// (decision 215) every screen is a child route of `/`, so this walks
  /// EVERY entry of `interfaceRoutes` through the real `HomeModule`.
  Future<void> open(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpLocalizedApp(
      tester,
      ModularApp(module: _TestModule(apiClient, localPrefs), child: const AppWidget()),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    Modular.to.navigate(route);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'route $route threw while building');
  }

  for (final entry in interfaceRoutes.entries) {
    testWidgets('${entry.value} (${entry.key}) mounts a page inside the shell outlet',
        (tester) async {
      await open(tester, entry.value);
      expect(Modular.to.path, entry.value);
      // Still inside the shell (the menu column is there) and the page
      // renders its content header, never its own app bar.
      expect(find.byKey(const Key('shell-modules-column')), findsOneWidget);
      expect(find.byKey(const Key('vgr-page-title')), findsOneWidget);
    });
  }

  testWidgets('$pendingRoute renders the placeholder inside the shell', (tester) async {
    await open(tester, pendingRoute);
    expect(find.byKey(const Key('vgr-page-title')), findsOneWidget);
  });

  test('interfaceKeyForPath maps a screen URL back to its menu key, longest match first', () {
    expect(interfaceKeyForPath('/users/'), 'users');
    expect(interfaceKeyForPath('/users'), 'users');
    expect(interfaceKeyForPath('/reports/7'), 'reports');
    expect(interfaceKeyForPath('/legal/rules/'), 'legal_rules');
    expect(interfaceKeyForPath('/'), isNull);
    expect(interfaceKeyForPath('/welcome'), isNull);
    expect(interfaceKeyForPath('/nowhere/'), isNull);
  });
}
