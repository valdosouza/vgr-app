import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/interface_repository_impl.dart';
import 'presentation/bloc/interface_bloc.dart';
import 'presentation/page/interface_page.dart';

class InterfacesModule extends Module {
  @override
  List<ModularRoute> get routes => [
        // ONE route: list and form alternate by the bloc's state (217); the
        // privilege catalog loads once beside the list.
        ChildRoute(
          '/',
          child: (_, __) {
            final repository = InterfaceRepositoryImpl(Modular.get<ApiClient>());
            return MultiBlocProvider(
              providers: [
                BlocProvider<InterfaceBloc>(
                  create: (_) => InterfaceBloc(repository)..add(const RegisterListRequested()),
                ),
                BlocProvider<PrivilegeOptionsCubit>(
                  create: (_) => PrivilegeOptionsCubit(repository.listPrivilegeOptions)..load(),
                ),
              ],
              child: const InterfacePage(),
            );
          },
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
