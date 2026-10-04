import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/privilege_repository_impl.dart';
import 'presentation/bloc/privilege_bloc.dart';
import 'presentation/page/privilege_page.dart';

class PrivilegesModule extends Module {
  @override
  List<ModularRoute> get routes => [
        // ONE route: list and form alternate by the bloc's state (217).
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider<PrivilegeBloc>(
            create: (_) => PrivilegeBloc(PrivilegeRepositoryImpl(Modular.get<ApiClient>()))
              ..add(const RegisterListRequested()),
            child: const PrivilegePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
