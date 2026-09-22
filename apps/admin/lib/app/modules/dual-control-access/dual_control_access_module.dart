import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        // The page reads its bloc from the tree (BlocBuilder / context.read),
        // so the ROUTE must provide it — the page tests wrap a provider
        // themselves and never caught this (found live 2026-09-21: every
        // phase-1 screen threw ProviderNotFound on open).
          // No initial fetch: the flow starts on the request form (Initial).
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<DualControlAccessBloc>(),
            child: const DualControlRequestPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
