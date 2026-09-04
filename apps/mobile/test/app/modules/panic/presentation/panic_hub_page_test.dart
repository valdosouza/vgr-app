import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/panic/domain/entity/panic_entities.dart';
import 'package:vgr_mobile/app/modules/panic/domain/repository/panic_repository.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/check_active_panic_alert_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/resolve_panic_alert_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/trigger_panic_alert_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/presentation/bloc/panic_hub_bloc.dart';
import 'package:vgr_mobile/app/modules/panic/presentation/page/panic_hub_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockPanicRepository extends Mock implements PanicRepository {}

/// The panic hub (decisions 62/65/191/196-198): confirm gate before
/// firing, active-alert status, and the "I'm safe now" resolve action.
void main() {
  late MockPanicRepository repository;

  setUp(() {
    repository = MockPanicRepository();
    when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => PanicHubBloc(
          CheckActivePanicAlertUsecase(repository),
          TriggerPanicAlertUsecase(repository),
          ResolvePanicAlertUsecase(repository),
        ),
        child: const PanicHubPage(),
      ),
    );
  }

  testWidgets('idle renders the trigger button', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('panic-hub-trigger-button')), findsOneWidget);
  });

  testWidgets('confirming the dialog fires the trigger and shows the active state',
      (tester) async {
    when(() => repository.trigger()).thenAnswer((_) async => const Right(
          TriggerOutcome.online(
            TriggeredAlertEntity(alertId: 42, createdAt: 'now', recipientCount: 3),
          ),
        ));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('panic-hub-trigger-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panic-hub-confirm-confirm')));
    await tester.pumpAndSettle();

    verify(() => repository.trigger()).called(1);
    expect(find.byKey(const Key('panic-hub-active-title')), findsOneWidget);
    expect(find.byKey(const Key('panic-hub-resolve-button')), findsOneWidget);
  });

  testWidgets('cancelling the confirm dialog never calls trigger', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('panic-hub-trigger-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panic-hub-confirm-cancel')));
    await tester.pumpAndSettle();

    verifyNever(() => repository.trigger());
    expect(find.byKey(const Key('panic-hub-trigger-button')), findsOneWidget);
  });

  testWidgets('a queued trigger shows the queued caption, no resolve action yet',
      (tester) async {
    when(() => repository.trigger())
        .thenAnswer((_) async => const Right(TriggerOutcome.queued()));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('panic-hub-trigger-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panic-hub-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('panic-hub-queued-caption')), findsOneWidget);
    expect(find.byKey(const Key('panic-hub-resolve-button')), findsNothing);
  });

  testWidgets('a judged refusal (409 PANIC_ALERT_ACTIVE) surfaces inline, never crashes',
      (tester) async {
    when(() => repository.trigger()).thenAnswer((_) async => const Left(
          Failure(message: 'active', statusCode: 409, code: 'PANIC_ALERT_ACTIVE'),
        ));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('panic-hub-trigger-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('panic-hub-confirm-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('panic-hub-error')), findsOneWidget);
    // Still offers the trigger button — the local record simply
    // disagreed with the server (known PP1 gap), not a crash.
    expect(find.byKey(const Key('panic-hub-trigger-button')), findsOneWidget);
  });

  testWidgets('a remembered active alert renders the resolve action on load, even '
      'without a fresh recipient count', (tester) async {
    when(() => repository.currentActiveAlertId()).thenAnswer((_) async => 42);

    await pumpPage(tester);

    expect(find.byKey(const Key('panic-hub-active-title')), findsOneWidget);
    expect(find.byKey(const Key('panic-hub-resolve-button')), findsOneWidget);
  });

  testWidgets('"I\'m safe now" resolves without a confirm dialog and returns to idle',
      (tester) async {
    when(() => repository.currentActiveAlertId()).thenAnswer((_) async => 42);
    when(() => repository.resolve(42)).thenAnswer((_) async => const Right(null));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('panic-hub-resolve-button')));
    await tester.pumpAndSettle();

    verify(() => repository.resolve(42)).called(1);
    expect(find.byKey(const Key('panic-hub-trigger-button')), findsOneWidget);
  });

  testWidgets('a resolve refusal stays on the active view with the error shown',
      (tester) async {
    when(() => repository.currentActiveAlertId()).thenAnswer((_) async => 42);
    when(() => repository.resolve(42))
        .thenAnswer((_) async => const Left(Failure(message: 'nf', code: 'NOT_FOUND')));

    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('panic-hub-resolve-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('panic-hub-error')), findsOneWidget);
    expect(find.byKey(const Key('panic-hub-resolve-button')), findsOneWidget);
  });
}
