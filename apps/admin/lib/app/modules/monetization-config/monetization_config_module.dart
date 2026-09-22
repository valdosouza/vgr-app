import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../risk-config/domain/repository/risk_config_repository.dart';
import '../risk-config/data/risk_config_repository_impl.dart';
import 'data/fee_rule_repository_impl.dart';
import 'domain/repository/fee_rule_repository.dart';
import 'presentation/bloc/monetization_config_bloc.dart';
import 'presentation/bloc/monetization_config_event.dart';
import 'presentation/page/monetization_config_list_page.dart';

class MonetizationConfigModule extends Module {
  // Needs RiskConfigRepository to enforce "high-tier Categories can't
  // allow peer_to_peer" (decision 58). It is bound HERE, not imported:
  // flutter_modular 5.0.3 only shares binds marked `export: true`, and an
  // exported bind disappears from its own module's lookup — importing
  // RiskConfigModule left this module with no repository, so its bloc
  // could not be built (found live 2026-09-21; admin_module_wiring_test).
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<RiskConfigRepository>(
          (i) => RiskConfigRepositoryImpl(i<ApiClient>()),
        ),
        Bind.lazySingleton<FeeRuleRepository>(
          (i) => FeeRuleRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => MonetizationConfigBloc(i(), i<RiskConfigRepository>())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
        // The page reads its bloc from the tree (BlocBuilder / context.read),
        // so the ROUTE must provide it — the page tests wrap a provider
        // themselves and never caught this (found live 2026-09-21: every
        // phase-1 screen threw ProviderNotFound on open).
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<MonetizationConfigBloc>()..add(const FetchRequested()),
            child: const MonetizationConfigListPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
