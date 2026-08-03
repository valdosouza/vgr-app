import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/responder_approval_repository_impl.dart';
import 'domain/repository/responder_approval_repository.dart';
import 'presentation/bloc/responder_approval_bloc.dart';
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
          child: (_, __) => const ResponderApprovalQueuePage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
