import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/interface_repository_impl.dart';
import 'presentation/bloc/interface_bloc.dart';
import 'presentation/page/interface_page.dart';

class InterfacesModule extends Module {
  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => InterfaceBloc(InterfaceRepositoryImpl(Modular.get<ApiClient>()))
              ..add(const InterfaceFetchRequested()),
            child: const InterfacePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
