import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Loader extends AssetLoader {
  const _Loader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      Future.value({'hello': locale.languageCode == 'pt' ? 'Olá' : 'Hello'});
}

/// A screen the way the apps write them: const, translating with `.tr()`
/// without a context — so nothing subscribes it to the locale.
class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) => Text('hello'.tr());
}

class _Typed extends StatefulWidget {
  const _Typed();

  @override
  State<_Typed> createState() => _TypedState();
}

class _TypedState extends State<_Typed> {
  int builds = 0;

  @override
  Widget build(BuildContext context) => Text('builds ${++builds}');
}

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  const body = Column(children: [_Screen(), _Typed()]);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
      startLocale: const Locale('en', 'US'),
      saveLocale: false,
      path: 'unused',
      assetLoader: const _Loader(),
      child: Builder(builder: (context) {
        final app = MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const Scaffold(body: body),
        );
        return LocaleRefresh(child: app);
      }),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _switchToPortuguese(WidgetTester tester) async {
  await tester.element(find.byType(_Screen)).setLocale(const Locale('pt', 'BR'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  testWidgets('with it, the open screen follows the switch and keeps its State', (tester) async {
    await _pump(tester);
    expect(find.text('Hello'), findsOneWidget);
    final state = tester.state<_TypedState>(find.byType(_Typed));

    await _switchToPortuguese(tester);

    expect(find.text('Olá'), findsOneWidget);
    // Same State object, rebuilt — nothing was recreated.
    expect(tester.state<_TypedState>(find.byType(_Typed)), same(state));
    expect(state.builds, greaterThan(1));
  });
}
