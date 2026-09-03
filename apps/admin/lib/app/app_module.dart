import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/auth/data/auth_repository_impl.dart';
import 'modules/auth/presentation/bloc/login_bloc.dart';
import 'modules/auth/presentation/bloc/login_event.dart';
import 'modules/auth/presentation/bloc/recovery_bloc.dart';
import 'modules/auth/presentation/bloc/two_factor_bloc.dart';
import 'modules/auth/presentation/page/change_password_page.dart';
import 'modules/auth/presentation/page/login_page.dart';
import 'modules/auth/presentation/page/recovery_password_page.dart';
import 'modules/auth/presentation/page/two_factor_recover_page.dart';
import 'modules/auth/presentation/page/two_factor_setup_page.dart';
import 'modules/case-freeze/case_freeze_module.dart';
import 'modules/category-forms/category_forms_module.dart';
import 'modules/dual-control-access/dual_control_access_module.dart';
import 'modules/home/home_module.dart';
import 'modules/interfaces/interfaces_module.dart';
import 'modules/legal-policy/legal_policy_module.dart';
import 'modules/monetization-config/monetization_config_module.dart';
import 'modules/panic-responders/panic_responders_module.dart';
import 'modules/privileges/privileges_module.dart';
import 'modules/reports/reports_module.dart';
import 'modules/reward-mediation/reward_mediation_module.dart';
import 'modules/risk-config/risk_config_module.dart';
import 'modules/system-modules/system_modules_module.dart';
import 'modules/users/users_module.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        Bind.singleton((i) => LocalPrefs()),
        // TODO: base URL must become environment-configurable (dev/staging/prod)
        // once that decision is made — hardcoded to the local API for now.
        // Silent renewal (decision 112): the 15-minute token is exchanged
        // before expiry, and the fresh one is persisted only under
        // "keep me signed in" (decision 73 — honored by LocalPrefs, which
        // holds no token when the box is unchecked).
        Bind.singleton((i) => ApiClient(
              baseUrl: 'http://localhost:3002',
              onTokenRenewed: (jwt) async {
                final prefs = Modular.get<LocalPrefs>();
                if (await prefs.getKeepConnected()) {
                  await prefs.setSessionToken(jwt);
                }
              },
            )),
        // Singleton so the 2FA enrollment page can complete the session on
        // the same bloc the login page started (decision 114 flow).
        Bind.singleton((i) => LoginBloc(
              AuthRepositoryImpl(i.get<ApiClient>()),
              i.get<IdentityBloc>(),
              i.get<LocalPrefs>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/login',
          child: (_, __) => BlocProvider.value(
            value: Modular.get<LoginBloc>(),
            child: const LoginPage(),
          ),
        ),
        ChildRoute(
          '/recovery-password',
          child: (_, __) => BlocProvider(
            create: (_) => RecoveryBloc(AuthRepositoryImpl(Modular.get<ApiClient>())),
            child: const RecoveryPasswordPage(),
          ),
        ),
        ChildRoute(
          '/change-password',
          child: (_, args) => BlocProvider(
            create: (_) => RecoveryBloc(AuthRepositoryImpl(Modular.get<ApiClient>())),
            child: ChangePasswordPage(email: args.data as String?),
          ),
        ),
        // Mandatory TOTP enrollment (decision 114) — reached from login
        // with the enroll-scope token; no session exists yet.
        ChildRoute(
          '/two-factor-setup',
          child: (_, args) {
            final data = args.data as Map<String, dynamic>;
            return BlocProvider(
              create: (_) => TwoFactorBloc(AuthRepositoryImpl(Modular.get<ApiClient>())),
              child: TwoFactorSetupPage(
                enrollToken: data['enrollToken'] as String,
                onActivated: (jwt) {
                  Modular.get<LoginBloc>().add(LoginEnrollmentCompleted(
                    jwt: jwt,
                    keepConnected: data['keepConnected'] as bool? ?? false,
                  ));
                  Modular.to.navigate('/');
                },
              ),
            );
          },
        ),
        ChildRoute(
          '/two-factor-recover',
          child: (_, args) => TwoFactorRecoverPage(
            repository: AuthRepositoryImpl(Modular.get<ApiClient>()),
            initialEmail: args.data as String?,
            onRecovered: (jwt) {
              Modular.get<LoginBloc>().add(
                LoginEnrollmentCompleted(jwt: jwt, keepConnected: false),
              );
              Modular.to.navigate('/');
            },
          ),
        ),
        ModuleRoute('/', module: HomeModule()),
        // The report front's ONE panel screen (decisions 141/142).
        ModuleRoute('/case-freeze', module: CaseFreezeModule()),
        // Report search + case detail on the panel plane (B1, decisions 158-167).
        ModuleRoute('/reports', module: ReportsModule()),
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
      ];
}
