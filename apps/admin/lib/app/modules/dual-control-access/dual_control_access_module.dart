import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/dual_control_access_repository_impl.dart';
import 'domain/repository/dual_control_access_repository.dart';
import 'presentation/bloc/dual_control_bloc.dart';
import 'presentation/page/dual_control_access_page.dart';

/// The decision 45 gate (decisions 223–227): ONE route, list and request
/// form alternating by the bloc's state (217).
class DualControlAccessModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<DualControlAccessRepository>(
          (i) => DualControlAccessRepositoryImpl(i<ApiClient>()),
        ),
      ];

  @override
  List<ModularRoute> get routes => [
        // Provided under the factory's base type, the one RegisterScreen
        // looks up; the approve action is DualControlBloc's own. The session
        // user comes from the token the API judges on — the guard has set
        // it on the ApiClient before the route builds.
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider<DualControlRegisterBloc>(
            create: (_) => DualControlBloc(Modular.get<DualControlAccessRepository>())
              ..add(const RegisterListRequested()),
            child: DualControlAccessPage(sessionUserId: sessionUserIdOf(Modular.get<ApiClient>().token)),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
