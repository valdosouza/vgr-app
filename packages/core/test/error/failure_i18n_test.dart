import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `failureText` resolves `core.errors.<code>` (decisions 80/83). A code
/// whose WORDING depends on a param value — not one that merely
/// interpolates it — holds a map keyed by param name and then value, plus
/// an `other` leaf, the same shape easy_localization gives gender/plural
/// forms. Exercised against an in-memory catalog through the public
/// `EasyLocalization` widget: the loader/`Localization` internals are not
/// exported by the package.
class _MapAssetLoader extends AssetLoader {
  const _MapAssetLoader(this.catalog);

  final Map<String, dynamic> catalog;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) => Future.value(catalog);
}

const _catalog = <String, dynamic>{
  'core': {
    'errors': {
      'NOT_FOUND': 'Record not found.',
      'RATE_LIMITED': 'Wait {seconds} seconds.',
      'RATING_CLOSED': {
        'reason': {
          'open': 'The case is still open.',
          'hidden': 'The case was hidden.',
        },
        'other': 'The case is not closed.',
      },
    },
  },
};

Future<void> _pumpCatalog(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en', 'US')],
      startLocale: const Locale('en', 'US'),
      path: 'unused',
      assetLoader: const _MapAssetLoader(_catalog),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Missing-key probes are expected below; keep the test output clean.
  setUpAll(() => EasyLocalization.logger.enableBuildModes = []);

  group('failureText', () {
    testWidgets('a plain string code translates as before', (tester) async {
      await _pumpCatalog(tester);

      const failure = Failure(message: 'Not found', code: 'NOT_FOUND');

      expect(failureText(failure), 'Record not found.');
    });

    testWidgets('params are still interpolated into a plain string', (tester) async {
      await _pumpCatalog(tester);

      const failure = Failure(message: 'Slow down', code: 'RATE_LIMITED', params: {'seconds': '30'});

      expect(failureText(failure), 'Wait 30 seconds.');
    });

    testWidgets('a param value selects its own sentence', (tester) async {
      await _pumpCatalog(tester);

      const open = Failure(message: 'Not resolved', code: 'RATING_CLOSED', params: {'reason': 'open'});
      const hidden = Failure(message: 'Hidden', code: 'RATING_CLOSED', params: {'reason': 'hidden'});

      expect(failureText(open), 'The case is still open.');
      expect(failureText(hidden), 'The case was hidden.');
    });

    testWidgets('a param value without its own sentence falls back to `other`', (tester) async {
      await _pumpCatalog(tester);

      const failure = Failure(message: 'Frozen', code: 'RATING_CLOSED', params: {'reason': 'frozen'});

      expect(failureText(failure), 'The case is not closed.');
    });

    testWidgets('a variant code with no params at all renders `other`, never throws', (tester) async {
      await _pumpCatalog(tester);

      const failure = Failure(message: 'Not resolved', code: 'RATING_CLOSED');

      expect(failureText(failure), 'The case is not closed.');
    });

    testWidgets('an unknown code falls back to the API message', (tester) async {
      await _pumpCatalog(tester);

      const failure = Failure(message: 'Something new', code: 'NEW_CODE', params: {'reason': 'open'});

      expect(failureText(failure), 'Something new');
    });

    testWidgets('no code at all -> the API message', (tester) async {
      await _pumpCatalog(tester);

      const failure = Failure(message: 'No connectivity');

      expect(failureText(failure), 'No connectivity');
    });
  });
}
