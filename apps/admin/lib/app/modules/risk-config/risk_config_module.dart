import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/risk_config_repository_impl.dart';
import 'domain/repository/risk_config_repository.dart';
import 'presentation/bloc/risk_config_bloc.dart';
import 'presentation/bloc/risk_config_event.dart';
import 'presentation/page/risk_config_list_page.dart';

class RiskConfigModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<RiskConfigRepository>(
          (i) => RiskConfigRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => RiskConfigBloc(i())),
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
            create: (_) => Modular.get<RiskConfigBloc>()..add(const FetchRequested()),
            child: const RiskConfigListPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
