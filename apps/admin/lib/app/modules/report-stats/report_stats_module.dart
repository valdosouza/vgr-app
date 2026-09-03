import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'data/report_stats_repository_impl.dart';
import 'domain/repository/report_stats_repository.dart';
import 'presentation/bloc/report_stats_bloc.dart';
import 'presentation/page/report_stats_page.dart';

/// Aggregated report statistics on the panel plane (B4, decisions 164/165).
/// `/report-stats`, behind the admin session. The grant (`report_stats`
/// VIEW, own interface — 165) is enforced by the API (72); the menu simply
/// does not show the screen without it (71). Own folder: modules never
/// import each other, so nothing here reaches into `modules/reports`.
class ReportStatsModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.lazySingleton<ReportStatsRepository>(
          (i) => ReportStatsRepositoryImpl(i<ApiClient>()),
        ),
        Bind.factory((i) => ReportStatsBloc(i())),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<ReportStatsBloc>(),
            child: const ReportStatsPage(),
          ),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
