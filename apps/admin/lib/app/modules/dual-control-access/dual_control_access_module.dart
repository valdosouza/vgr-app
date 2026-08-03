import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/dual_control_access_repository_impl.dart';
import 'domain/repository/dual_control_access_repository.dart';
import 'presentation/bloc/dual_control_access_bloc.dart';
import 'presentation/page/dual_control_request_page.dart';

class DualControlAccessModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<DualControlAccessRepository>(
          (i) => DualControlAccessRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => DualControlAccessBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => const DualControlRequestPage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
