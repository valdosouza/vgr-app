import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/admin_audit_repository_impl.dart';
import 'domain/repository/admin_audit_repository.dart';
import 'presentation/bloc/admin_audit_detail_bloc.dart';
import 'presentation/bloc/admin_audit_detail_event.dart';
import 'presentation/bloc/admin_audit_list_bloc.dart';
import 'presentation/page/admin_audit_detail_page.dart';
import 'presentation/page/admin_audit_list_page.dart';

/// The admin audit trail screen (B5, decisions 116/158/165/166).
/// `/admin-audit` list, `/admin-audit/:id` detail; behind the admin
/// session. The grant (`admin_audit` VIEW, own interface — 165) is
/// enforced by the API (72); the menu simply does not show the screen
/// without it (71). READ only: nothing here writes, and the API has no
/// write route to call (116). Own folder — modules never import each other.
class AdminAuditModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<AdminAuditRepository>(
          (i) => AdminAuditRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => AdminAuditListBloc(i())),
        Bind.factory((i) => AdminAuditDetailBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<AdminAuditListBloc>(),
            child: const AdminAuditListPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/:id',
          child: (_, args) {
            final id = int.parse(args.params['id'] as String);
            return BlocProvider(
              create: (_) => Modular.get<AdminAuditDetailBloc>()..add(AdminAuditDetailRequested(id)),
              child: AdminAuditDetailPage(entryId: id, autoload: false),
            );
          },
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
