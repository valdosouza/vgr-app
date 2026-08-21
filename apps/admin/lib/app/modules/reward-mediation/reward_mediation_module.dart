import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/reward_mediation_repository_impl.dart';
import 'domain/repository/reward_mediation_repository.dart';
import 'presentation/bloc/reward_mediation_bloc.dart';
import 'presentation/page/reward_mediation_page.dart';

class RewardMediationModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<RewardMediationRepository>(
          (i) => RewardMediationRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => RewardMediationBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<RewardMediationBloc>(),
            child: const RewardMediationPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
