import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_localized.dart';

class MockPreferenceRepository extends Mock implements PreferenceRepository {}

void main() {
  late MockPreferenceRepository repository;

  setUp(() {
    repository = MockPreferenceRepository();
    when(() => repository.saveLocale(any())).thenAnswer((_) async => const Right(unit));
  });

  Widget page({required bool persist}) => Scaffold(
        appBar: AppBar(
          actions: [LanguageSelector(persist: persist, repository: repository)],
        ),
        body: Builder(builder: (context) => Text('home.retry'.tr())),
      );

  testWidgets('switching to pt-BR changes the app locale and persists the choice (phase 5)', (tester) async {
    await pumpLocalized(tester, page(persist: true));
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-pt-BR')));
    await tester.pumpAndSettle();

    verify(() => repository.saveLocale('pt-BR')).called(1);
    final context = tester.element(find.byKey(const Key('language-selector')));
    expect(EasyLocalization.of(context)!.locale, const Locale('pt', 'BR'));
  });

  testWidgets('with persist=false (login) the switch is local only', (tester) async {
    await pumpLocalized(tester, page(persist: false));

    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-option-pt-BR')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byKey(const Key('language-selector')));
    expect(EasyLocalization.of(context)!.locale, const Locale('pt', 'BR'));
    verifyNever(() => repository.saveLocale(any()));
  });

  testWidgets('applyUserLocale switches to the server-saved locale', (tester) async {
    when(() => repository.getMyLocale()).thenAnswer((_) async => const Right('pt-BR'));

    await pumpLocalized(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              Text('home.retry'.tr()),
              ElevatedButton(
                key: const Key('sync-button'),
                onPressed: () => applyUserLocale(context, repository: repository),
                child: const Text('sync'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('sync-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
