import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/responder_approval_repository_impl.dart';
import 'domain/repository/responder_approval_repository.dart';
import 'presentation/bloc/responder_approval_bloc.dart';
import 'presentation/bloc/responder_approval_event.dart';
import 'presentation/page/responder_approval_queue_page.dart';

class PanicRespondersModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ResponderApprovalRepository>(
          (i) => ResponderApprovalRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => ResponderApprovalBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
        // The page reads its bloc from the tree (BlocBuilder / context.read),
        // so the ROUTE must provide it — the page tests wrap a provider
        // themselves and never caught this (found live 2026-09-21: every
        // phase-1 screen threw ProviderNotFound on open).
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<ResponderApprovalBloc>()..add(const FetchRequested()),
            child: const ResponderApprovalQueuePage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
