import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/report/data/report_queue_tasks.dart';
import 'modules/report/report_module.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        Bind.singleton((i) => LocalPrefs()),
        // TODO: base URL must become environment-configurable (dev/staging/
        // prod) once that decision is made — same note as apps/admin.
        Bind.singleton((i) => ApiClient(baseUrl: 'http://localhost:3002')),
        // Offline queue (decision 28): handlers wired before anything can
        // flush; boot flush drains what a previous run left behind, the
        // periodic retry covers connectivity coming back mid-session.
        Bind.singleton((i) {
          final queue = OfflineQueueService();
          ReportQueueTasks.register(queue, i.get<ApiClient>());
          queue.startAutoFlush();
          // ignore: unawaited_futures
          queue.flush();
          return queue;
        }),
      ];

  @override
  List<ModularRoute> get routes => [
        // The report form IS the app's front door while A2 (feed) doesn't
        // exist — "a denúncia nunca espera" (decision 123) starts here.
        ModuleRoute('/', module: ReportModule()),
      ];
}
