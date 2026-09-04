import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/auth/auth_module.dart';
import 'modules/chat/chat_module.dart';
import 'modules/chat/data/chat_queue_tasks.dart';
import 'modules/chat/data/chat_send_outcomes.dart';
import 'modules/help_offer/help_offer_module.dart';
import 'modules/panic/data/panic_local_store.dart';
import 'modules/panic/data/panic_queue_tasks.dart';
import 'modules/panic/data/panic_repository_impl.dart';
import 'modules/panic/domain/repository/panic_repository.dart';
import 'modules/panic/panic_module.dart';
import 'modules/rating/data/rating_queue_tasks.dart';
import 'modules/rating/data/rating_repository_impl.dart';
import 'modules/rating/domain/repository/rating_repository.dart';
import 'modules/report/data/geolocator_location_gateway.dart';
import 'modules/report/data/my_reports_store.dart';
import 'modules/report/data/report_queue_tasks.dart';
import 'modules/report/domain/gateway/location_gateway.dart';
import 'modules/report/report_module.dart';
import 'modules/reward_onboarding/reward_onboarding_module.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        Bind.singleton((i) => LocalPrefs()),
        // TODO: base URL must become environment-configurable (dev/staging/
        // prod) once that decision is made — same note as apps/admin.
        Bind.singleton((i) => ApiClient(baseUrl: 'http://localhost:3002')),
        Bind.singleton((i) => MyReportsStore()),
        // Settles/fails optimistic chat bubbles from the queue (172).
        Bind.singleton((i) => ChatSendOutcomes()),
        // RT2 (decisions 48/178-189): reachable from both the report
        // module (rating an offer) and the auth module (reading "my
        // reputation") — bound once here, same as `MyReportsStore`.
        Bind.lazySingleton<RatingRepository>(
          (i) => RatingRepositoryImpl(
            i.get<ApiClient>(),
            i.get<OfflineQueueService>(),
            i.get<MyReportsStore>(),
          ),
        ),
        // PP2's own "remember an id locally" store (decisions 62/65/191/
        //198) — mirrors `MyReportsStore`'s shape, a different entity.
        Bind.singleton((i) => PanicLocalStore()),
        // `ReportModule` binds this too (module-scoped, sibling modules
        // never import each other — ARCHITECTURE.md); it is ALSO needed
        // here because `PanicRepositoryImpl.trigger()` reads the device's
        // position itself (see `panic_repository.dart`), and
        // `PanicRepository` must live at THIS level to be reachable from
        // both the panic module and the auth module's account page (like
        // `RatingRepository` above). Bound once here, `PanicModule`'s own
        // blocs resolve it from this parent bind rather than re-declaring
        // it a third time.
        Bind.lazySingleton<LocationGateway>((i) => const GeolocatorLocationGateway()),
        // PP2 (decisions 62/65/191/196-198): reachable from both the
        // panic module (trigger/resolve/inbox) and the auth module (the
        // responder-request tile) — bound once here, same as
        // `RatingRepository`/`MyReportsStore`.
        Bind.lazySingleton<PanicRepository>(
          (i) => PanicRepositoryImpl(
            i.get<ApiClient>(),
            i.get<OfflineQueueService>(),
            i.get<PanicLocalStore>(),
            i.get<LocationGateway>(),
          ),
        ),
        // Offline queue (decision 28): handlers wired before anything can
        // flush; boot flush drains what a previous run left behind, the
        // periodic retry covers connectivity coming back mid-session.
        Bind.singleton((i) {
          final queue = OfflineQueueService();
          ReportQueueTasks.register(queue, i.get<ApiClient>(),
              myReports: i.get<MyReportsStore>());
          // Masked chat rides the same queue (decision 172).
          ChatQueueTasks.register(queue, i.get<ApiClient>(), i.get<MyReportsStore>(),
              outcomes: i.get<ChatSendOutcomes>());
          // Helper rating rides the same queue too (decision 181/RT2).
          RatingQueueTasks.register(queue, i.get<ApiClient>(),
              myReports: i.get<MyReportsStore>());
          // The panic trigger/resolve ride it too (decision 28 applied to
          // PP2).
          PanicQueueTasks.register(queue, i.get<ApiClient>(),
              localStore: i.get<PanicLocalStore>());
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
        // Reward payout onboarding (decisions 104/143) — reachable once a
        // helper decides to become eligible, not tied to one report.
        ModuleRoute('/reward-onboarding', module: RewardOnboardingModule()),
        // Email+password auth (decisions 119/151/152) — optional, never a
        // gate in front of reporting (decision 123).
        ModuleRoute('/auth', module: AuthModule()),
        // Masked chat (decisions 54/168-177) — reached from the report detail.
        ModuleRoute('/chat', module: ChatModule()),
        // Panic button (PP2, decisions 62/65/191/196-198) — reachable
        // from the feed's action at any time, independent of reporting.
        ModuleRoute('/panic', module: PanicModule()),
        // The feed is the home (A2); the form stays one tap away (123).
        ModuleRoute('/', module: ReportModule()),
      ];
}
