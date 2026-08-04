import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the real translation catalogs from disk synchronously — the
/// rootBundle-based default loader hangs under flutter_test's fake async
/// after the first test, leaving MaterialApp waiting on the localization
/// delegate forever.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) {
    final file = File('$path/${locale.toStringWithSeparator(separator: '-')}.json');
    return Future.value(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }
}

/// Wraps [home] with EasyLocalization + MaterialApp loading the real en-US
/// catalog, so widget tests assert the same English strings users see
/// (instead of raw i18n keys).
Future<void> pumpLocalized(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
      startLocale: const Locale('en', 'US'),
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      assetLoader: const _FileAssetLoader(),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Same, for ModularApp-based tests where the widget builds its own
/// MaterialApp.router (AppWidget reads the locale from this ancestor).
Future<void> pumpLocalizedApp(WidgetTester tester, Widget app) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      assetLoader: const _FileAssetLoader(),
      child: app,
    ),
  );
  await tester.pumpAndSettle();
}
