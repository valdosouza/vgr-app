import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../report/domain/gateway/location_gateway.dart';
import 'domain/repository/panic_repository.dart';
import 'domain/usecase/check_active_panic_alert_usecase.dart';
import 'domain/usecase/list_panic_alerts_usecase.dart';
import 'domain/usecase/resolve_panic_alert_usecase.dart';
import 'domain/usecase/trigger_panic_alert_usecase.dart';
import 'presentation/bloc/panic_alerts_bloc.dart';
import 'presentation/bloc/panic_hub_bloc.dart';
import 'presentation/page/panic_alerts_page.dart';
import 'presentation/page/panic_hub_page.dart';

/// Panic button — PP2 (decisions 62/65/191/196-198), mounted at `/panic`.
/// `PanicRepository` AND `LocationGateway` are both bound once in
/// `AppModule` (reachable from both this module and the auth module's
/// account page, like `RatingRepository`) — `PanicRepositoryImpl.trigger`
/// itself needs `LocationGateway` and lives at that level, so unlike
/// `ReportModule` this module does not re-declare the gateway: it simply
/// resolves the parent bind via `i.get<LocationGateway>()` for
/// `PanicAlertsBloc`'s own "my current position" query.
class PanicModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.factory((i) => PanicHubBloc(
              CheckActivePanicAlertUsecase(i.get<PanicRepository>()),
              TriggerPanicAlertUsecase(i.get<PanicRepository>()),
              ResolvePanicAlertUsecase(i.get<PanicRepository>()),
            )),
        Bind.factory((i) => PanicAlertsBloc(
              ListPanicAlertsUsecase(i.get<PanicRepository>()),
              i.get<LocationGateway>(),
            )),
      ];

  @override
  List<ModularRoute> get routes => [
        // The cold trigger (62/65): reachable from the feed's panic
        // action at any time.
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<PanicHubBloc>(),
            child: const PanicHubPage(),
          ),
        ),
        // The responder's own inbox (192 — polling only).
        ChildRoute(
          '/alerts',
          child: (_, __) => BlocProvider(
            create: (_) => Modular.get<PanicAlertsBloc>(),
            child: const PanicAlertsPage(),
          ),
        ),
      ];
}
