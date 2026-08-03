import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/auth/data/auth_repository_impl.dart';
import 'modules/auth/presentation/bloc/login_bloc.dart';
import 'modules/auth/presentation/bloc/recovery_bloc.dart';
import 'modules/auth/presentation/page/change_password_page.dart';
import 'modules/auth/presentation/page/login_page.dart';
import 'modules/auth/presentation/page/recovery_password_page.dart';
import 'modules/category-forms/category_forms_module.dart';
import 'modules/dual-control-access/dual_control_access_module.dart';
import 'modules/home/home_module.dart';
import 'modules/interfaces/interfaces_module.dart';
import 'modules/monetization-config/monetization_config_module.dart';
import 'modules/panic-responders/panic_responders_module.dart';
import 'modules/privileges/privileges_module.dart';
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
        Bind.singleton((i) => ApiClient(baseUrl: 'http://localhost:3002')),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/login',
          child: (_, __) => BlocProvider(
            create: (_) => LoginBloc(
              AuthRepositoryImpl(Modular.get<ApiClient>()),
              Modular.get<IdentityBloc>(),
              Modular.get<LocalPrefs>(),
            ),
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
        ModuleRoute('/', module: HomeModule()),
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
