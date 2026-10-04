import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/system_module_repository_impl.dart';
import 'presentation/bloc/system_module_bloc.dart';
import 'presentation/page/system_module_page.dart';

class SystemModulesModule extends Module {
  @override
  List<ModularRoute> get routes => [
        // ONE route: list and form alternate by the bloc's state (217); the
        // screen catalog loads once beside the list.
        ChildRoute(
          '/',
          child: (_, __) {
            final repository = SystemModuleRepositoryImpl(Modular.get<ApiClient>());
            return MultiBlocProvider(
              providers: [
                BlocProvider<SystemModuleBloc>(
                  create: (_) => SystemModuleBloc(repository)..add(const RegisterListRequested()),
                ),
                BlocProvider<InterfaceOptionsCubit>(
                  create: (_) => InterfaceOptionsCubit(repository.listInterfaceOptions)..load(),
                ),
              ],
              child: const SystemModulePage(),
            );
          },
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
