import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'app/app_module.dart';
import 'app/app_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // en-US is the source locale, pt-BR the first translation (app ADR
  // §INTERNATIONALIZATION). Keys always added to BOTH JSONs in the same edit.
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: ModularApp(module: AppModule(), child: const AppWidget()),
    ),
  );
}
