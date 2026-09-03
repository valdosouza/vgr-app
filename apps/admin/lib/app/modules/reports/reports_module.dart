import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/reports_repository_impl.dart';
import 'domain/repository/reports_repository.dart';
import 'presentation/bloc/report_detail_bloc.dart';
import 'presentation/bloc/report_detail_event.dart';
import 'presentation/bloc/reports_list_bloc.dart';
import 'presentation/bloc/reports_queue_bloc.dart';
import 'presentation/bloc/reports_queue_event.dart';
import 'presentation/page/report_detail_page.dart';
import 'presentation/page/reports_list_page.dart';
import 'presentation/page/reports_queue_page.dart';

/// Report search + case detail on the panel plane (B1, decisions 158–167)
/// and the proactive moderation queue (B3, decision 161).
/// `/reports` list, `/reports/queue` queue, `/reports/:id` detail; all
/// behind the admin session. The grant (`reports` VIEW) is enforced per
/// route by the API (72) — the menu simply does not show the screen
/// without it (71).
class ReportsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ReportsRepository>(
          (i) => ReportsRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => ReportsListBloc(i())),
        Bind.factory((i) => ReportDetailBloc(i())),
        Bind.factory((i) => ReportsQueueBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<ReportsListBloc>(),
            child: const ReportsListPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        // Literal segment BEFORE `/:id`: flutter_modular resolves routes in
        // registration order and `/:id` would otherwise swallow `queue`
        // (same rule the API applies to `/queue` and `/stats`).
        ChildRoute(
          '/queue',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<ReportsQueueBloc>()..add(const ReportsQueueRequested()),
            child: const ReportsQueuePage(autoload: false),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
        ChildRoute(
          '/:id',
          child: (_, args) {
            final reportId = int.parse(args.params['id'] as String);
            return BlocProvider(
              create: (_) => Modular.get<ReportDetailBloc>()
                ..add(ReportDetailRequested(reportId)),
              child: ReportDetailPage(reportId: reportId, autoload: false),
            );
          },
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
