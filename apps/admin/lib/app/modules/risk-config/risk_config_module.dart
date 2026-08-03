import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/risk_config_repository_impl.dart';
import 'domain/repository/risk_config_repository.dart';
import 'presentation/bloc/risk_config_bloc.dart';
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
          child: (_, __) => const RiskConfigListPage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
