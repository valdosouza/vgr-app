import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/app_widget.dart';
import 'package:vgr_admin/app/modules/category-forms/category_forms_module.dart';
import 'package:vgr_admin/app/modules/category-forms/presentation/bloc/category_form_bloc.dart';
import 'package:vgr_admin/app/modules/dual-control-access/dual_control_access_module.dart';
import 'package:vgr_admin/app/modules/dual-control-access/presentation/bloc/dual_control_access_bloc.dart';
import 'package:vgr_admin/app/modules/monetization-config/monetization_config_module.dart';
import 'package:vgr_admin/app/modules/monetization-config/presentation/bloc/monetization_config_bloc.dart';
import 'package:vgr_admin/app/modules/panic-responders/panic_responders_module.dart';
import 'package:vgr_admin/app/modules/panic-responders/presentation/bloc/responder_approval_bloc.dart';
import 'package:vgr_admin/app/modules/risk-config/presentation/bloc/risk_config_bloc.dart';
import 'package:vgr_admin/app/modules/risk-config/risk_config_module.dart';

import '../../../helpers/pump_localized.dart';
import '../../../helpers/session_access.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockLocalPrefs extends Mock implements LocalPrefs {}

/// Mounts the REAL admin modules under an already-admin session, with the
/// API client stubbed to fail — the pages then render their error state,
/// which is enough to prove the route wired a provider above the page.
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
        ChildRoute('/', child: (_, __) => const SizedBox.shrink()),
        ModuleRoute('/risk-config', module: RiskConfigModule()),
        ModuleRoute('/category-forms', module: CategoryFormsModule()),
        ModuleRoute('/panic-responders', module: PanicRespondersModule()),
        ModuleRoute('/dual-control-access', module: DualControlAccessModule()),
        ModuleRoute('/monetization-config', module: MonetizationConfigModule()),
      ];
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

  /// Regression for the live finding of 2026-09-21: every phase-1 admin
  /// screen threw "Could not find the correct Provider<XBloc>" on open,
  /// because the route mounted the page bare while the page reads its bloc
  /// from the tree. The page tests never caught it — they wrap a provider
  /// themselves — so this one goes through the REAL module routes.
  Future<void> open(WidgetTester tester, String route) async {
    await pumpLocalizedApp(
      tester,
      ModularApp(module: _TestModule(apiClient, localPrefs), child: const AppWidget()),
    );
    Modular.to.navigate(route);
    // flutter_modular 5.0.3 debounces navigate() by ~500 ms on the widget
    // test's fake clock (same as login_navigation_test).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'route $route threw while building');
  }

  testWidgets('/risk-config/ mounts its page under BlocProvider<RiskConfigBloc>', (tester) async {
    await open(tester, '/risk-config/');
    expect(find.byType(BlocProvider<RiskConfigBloc>), findsOneWidget);
  });

  testWidgets('/category-forms/ mounts its page under BlocProvider<CategoryFormBloc>',
      (tester) async {
    await open(tester, '/category-forms/');
    expect(find.byType(BlocProvider<CategoryFormBloc>), findsOneWidget);
  });

  testWidgets('/panic-responders/ mounts its page under BlocProvider<ResponderApprovalBloc>',
      (tester) async {
    await open(tester, '/panic-responders/');
    expect(find.byType(BlocProvider<ResponderApprovalBloc>), findsOneWidget);
  });

  testWidgets('/dual-control-access/ mounts its page under BlocProvider<DualControlAccessBloc>',
      (tester) async {
    await open(tester, '/dual-control-access/');
    expect(find.byType(BlocProvider<DualControlAccessBloc>), findsOneWidget);
  });

  testWidgets('/monetization-config/ mounts its page under BlocProvider<MonetizationConfigBloc>',
      (tester) async {
    await open(tester, '/monetization-config/');
    expect(find.byType(BlocProvider<MonetizationConfigBloc>), findsOneWidget);
  });
}
