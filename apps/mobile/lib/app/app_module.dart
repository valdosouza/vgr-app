import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/help_offer/help_offer_module.dart';
import 'modules/report/data/my_reports_store.dart';
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
        Bind.singleton((i) => MyReportsStore()),
        // Offline queue (decision 28): handlers wired before anything can
        // flush; boot flush drains what a previous run left behind, the
        // periodic retry covers connectivity coming back mid-session.
        Bind.singleton((i) {
          final queue = OfflineQueueService();
          ReportQueueTasks.register(queue, i.get<ApiClient>(),
              myReports: i.get<MyReportsStore>());
          queue.startAutoFlush();
          // ignore: unawaited_futures
          queue.flush();
          return queue;
        }),
      ];

  @override
  List<ModularRoute> get routes => [
        // Offering help lives in its own module (spec task 10); listed
        // before '/' so the prefix wins the match.
        ModuleRoute('/offer', module: HelpOfferModule()),
        // The feed is the home (A2); the form stays one tap away (123).
        ModuleRoute('/', module: ReportModule()),
      ];
}
