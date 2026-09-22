import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../admin-audit/admin_audit_module.dart';
import '../case-freeze/case_freeze_module.dart';
import '../category-forms/category_forms_module.dart';
import '../dual-control-access/dual_control_access_module.dart';
import '../interfaces/interfaces_module.dart';
import '../legal-policy/legal_policy_module.dart';
import '../monetization-config/monetization_config_module.dart';
import '../panic-responders/panic_responders_module.dart';
import '../privileges/privileges_module.dart';
import '../report-stats/report_stats_module.dart';
import '../reports/reports_module.dart';
import '../reward-mediation/reward_mediation_module.dart';
import '../risk-config/risk_config_module.dart';
import '../system-modules/system_modules_module.dart';
import '../users/users_module.dart';
import 'presentation/home_page.dart';
import 'presentation/pending_page.dart';
import 'presentation/welcome_page.dart';

/// The post-login SHELL (decision 215, the setes-app layout): `/` draws
/// the app bar and the two navigation columns, and every screen of the
/// panel is a child route rendered in its `RouterOutlet`. Mounted at `/`
/// so the screens keep their root URLs (`/reports`, `/users`… — decision
/// 216); `interface_routes.dart` and bookmarks are untouched.
///
/// Registering a new screen = one entry in `interface_routes.dart` + one
/// `ModuleRoute` below (the setes rule). Every route requires a live
/// admin session (decision 56) — the guard sits on the shell route and
/// each module repeats it on its own routes.
class HomeModule extends Module {
  @override
  List<Bind> get binds => [
        // One bloc for the whole shell life: the selection (which module,
        // which screen) must survive navigation inside the outlet.
        Bind.singleton((i) => MenuBloc(MenuRepositoryImpl(i.get<ApiClient>()))),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider.value(
            value: Modular.get<MenuBloc>(),
            child: const HomePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
          children: [
            // Outlet content with no screen picked yet (setes' welcome).
            ChildRoute('/welcome', child: (_, __) => const WelcomePage()),
            // Cataloged screen without a page yet (setes' pending rule).
            ChildRoute('/pending', child: (_, __) => const PendingPage()),
            // The report front's ONE panel screen (decisions 141/142).
            ModuleRoute('/case-freeze', module: CaseFreezeModule()),
            // Report search + case detail (B1, decisions 158-167).
            ModuleRoute('/reports', module: ReportsModule()),
            // Aggregated statistics, k = 5 floor (B4, decisions 164/165).
            ModuleRoute('/report-stats', module: ReportStatsModule()),
            // Admin audit trail, read only (B5, decisions 116/165/166).
            ModuleRoute('/admin-audit', module: AdminAuditModule()),
            ModuleRoute('/reward-mediation', module: RewardMediationModule()),
            // Legal Gate admin screens (L3, decisions 103-109).
            ModuleRoute('/legal', module: LegalPolicyModule()),
            ModuleRoute('/risk-config', module: RiskConfigModule()),
            ModuleRoute('/category-forms', module: CategoryFormsModule()),
            ModuleRoute('/panic-responders', module: PanicRespondersModule()),
            ModuleRoute('/dual-control-access', module: DualControlAccessModule()),
            ModuleRoute('/monetization-config', module: MonetizationConfigModule()),
            // Access-control screens (phase 4 — decisions 70-75).
            ModuleRoute('/privileges', module: PrivilegesModule()),
            ModuleRoute('/interfaces', module: InterfacesModule()),
            ModuleRoute('/system-modules', module: SystemModulesModule()),
            ModuleRoute('/users', module: UsersModule()),
          ],
        ),
      ];
}
