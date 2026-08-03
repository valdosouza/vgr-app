import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/auth/data/auth_repository_impl.dart';
import 'modules/auth/presentation/bloc/login_bloc.dart';
import 'modules/auth/presentation/page/login_page.dart';
import 'modules/category-forms/category_forms_module.dart';
import 'modules/dual-control-access/dual_control_access_module.dart';
import 'modules/home/home_module.dart';
import 'modules/monetization-config/monetization_config_module.dart';
import 'modules/panic-responders/panic_responders_module.dart';
import 'modules/risk-config/risk_config_module.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        // TODO: base URL must become environment-configurable (dev/staging/prod)
        // once that decision is made — hardcoded to the local API for now.
        Bind.singleton((i) => ApiClient(baseUrl: 'http://localhost:3002')),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/login',
          child: (_, __) => BlocProvider(
            create: (_) => LoginBloc(AuthRepositoryImpl(Modular.get<ApiClient>()), Modular.get<IdentityBloc>()),
            child: const LoginPage(),
          ),
        ),
        ModuleRoute('/', module: HomeModule()),
        ModuleRoute('/risk-config', module: RiskConfigModule()),
        ModuleRoute('/category-forms', module: CategoryFormsModule()),
        ModuleRoute('/panic-responders', module: PanicRespondersModule()),
        ModuleRoute('/dual-control-access', module: DualControlAccessModule()),
        ModuleRoute('/monetization-config', module: MonetizationConfigModule()),
      ];
}
