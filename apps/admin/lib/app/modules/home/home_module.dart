import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/home_page.dart';
import 'presentation/pending_page.dart';

/// Every route in this module requires a live session (decision 56).
class HomeModule extends Module {
  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => MenuBloc(MenuRepositoryImpl(Modular.get<ApiClient>()))
              ..add(const MenuRequested()),
            child: const HomePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/pending',
          child: (_, __) => const PendingPage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
