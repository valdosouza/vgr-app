import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/system_module_repository_impl.dart';
import 'presentation/bloc/system_module_bloc.dart';
import 'presentation/page/system_module_page.dart';

class SystemModulesModule extends Module {
  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => SystemModuleBloc(SystemModuleRepositoryImpl(Modular.get<ApiClient>()))
              ..add(const SystemModuleFetchRequested()),
            child: const SystemModulePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
