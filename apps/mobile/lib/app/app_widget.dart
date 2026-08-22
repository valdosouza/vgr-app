import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'modules/auth/data/session_bootstrap.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget, same spirit as the offline queue's boot flush
    // (app_module.dart) — the UI never waits on this.
    // ignore: unawaited_futures
    restoreAppSession(
      apiClient: Modular.get<ApiClient>(),
      localPrefs: Modular.get<LocalPrefs>(),
      identityBloc: Modular.get<IdentityBloc>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => 'app_name'.tr(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      routeInformationParser: Modular.routeInformationParser,
      routerDelegate: Modular.routerDelegate,
    );
  }
}
