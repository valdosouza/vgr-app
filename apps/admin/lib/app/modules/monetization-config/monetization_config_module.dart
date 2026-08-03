import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../risk-config/domain/repository/risk_config_repository.dart';
import '../risk-config/risk_config_module.dart';
import 'data/fee_rule_repository_impl.dart';
import 'domain/repository/fee_rule_repository.dart';
import 'presentation/bloc/monetization_config_bloc.dart';
import 'presentation/page/monetization_config_list_page.dart';

class MonetizationConfigModule extends Module {
  // Needs RiskConfigRepository to enforce "high-tier Categories can't
  // allow peer_to_peer" (decision 58) — flutter_modular scopes binds to
  // their own module by default, so RiskConfigModule is declared as an
  // import to make its binds resolvable here too.
  @override
  List<Module> get imports => [RiskConfigModule()];

  @override
  List<Bind> get binds => [
        Bind.lazySingleton<FeeRuleRepository>(
          (i) => FeeRuleRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => MonetizationConfigBloc(i(), i<RiskConfigRepository>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => const MonetizationConfigListPage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
