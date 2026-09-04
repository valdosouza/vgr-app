import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/panic/domain/entity/panic_entities.dart';
import 'package:vgr_mobile/app/modules/panic/domain/repository/panic_repository.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/check_active_panic_alert_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/resolve_panic_alert_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/trigger_panic_alert_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/presentation/bloc/panic_hub_bloc.dart';

class MockPanicRepository extends Mock implements PanicRepository {}

/// PP2's trigger/resolve status flow (decisions 62/65/191/196-198). The
/// CONFIRM gate lives in the page (`showVgrConfirm`, like
/// `report_detail_page.dart`'s close flow) — this bloc only ever sees
/// `PanicTriggerPressed` AFTER the user already confirmed, so it never
/// re-derives that rule.
void main() {
  late MockPanicRepository repository;

  setUp(() {
    repository = MockPanicRepository();
  });

  PanicHubBloc build() => PanicHubBloc(
        CheckActivePanicAlertUsecase(repository),
        TriggerPanicAlertUsecase(repository),
        ResolvePanicAlertUsecase(repository),
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('start-up (no PP1 read endpoint — local bookkeeping only)', () {
    test('nothing remembered locally -> idle, offering the trigger button', () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);

      final bloc = build()..add(const PanicHubStarted());
      await settle();

      expect(bloc.state.phase, PanicPhase.idle);
      expect(bloc.state.alertId, isNull);
    });

    test('a remembered active alert -> active, even after a fresh app start', () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => 42);

      final bloc = build()..add(const PanicHubStarted());
      await settle();

      expect(bloc.state.phase, PanicPhase.active);
      expect(bloc.state.alertId, 42);
    });
  });

  group('trigger', () {
    test('a location failure never calls trigger a second time and shows a retryable error',
        () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);
      when(() => repository.trigger()).thenAnswer(
          (_) async => const Left(Failure(message: 'off', code: 'LOCATION_OFF')));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicTriggerPressed());
      await settle();

      expect(bloc.state.phase, PanicPhase.idle);
      expect(bloc.state.failure?.code, 'LOCATION_OFF');
      verify(() => repository.trigger()).called(1);
    });

    test('online success shows the active-alert state with the server\'s numbers', () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);
      when(() => repository.trigger()).thenAnswer((_) async => const Right(
            TriggerOutcome.online(
              TriggeredAlertEntity(alertId: 42, createdAt: 'now', recipientCount: 3),
            ),
          ));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicTriggerPressed());
      await settle();

      expect(bloc.state.phase, PanicPhase.active);
      expect(bloc.state.alertId, 42);
      expect(bloc.state.recipientCount, 3);
      expect(bloc.state.queued, isFalse);
    });

    test('a transport failure (queued) still shows something sensible, never a hard error '
        '(decision 28)', () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);
      when(() => repository.trigger())
          .thenAnswer((_) async => const Right(TriggerOutcome.queued()));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicTriggerPressed());
      await settle();

      expect(bloc.state.phase, PanicPhase.active);
      expect(bloc.state.queued, isTrue);
      // The alertId does not exist server-side yet — nothing to resolve
      // until the queue actually lands it (surfaced by the page as "no
      // resolve action yet", never a crash).
      expect(bloc.state.alertId, isNull);
      expect(bloc.state.failure, isNull);
    });

    test('a Failure the API judged (409 PANIC_ALERT_ACTIVE) surfaces as an error, never '
        'crashes — the local record simply disagreed with the server (known PP1 gap)',
        () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);
      when(() => repository.trigger()).thenAnswer((_) async => const Left(
            Failure(message: 'active', statusCode: 409, code: 'PANIC_ALERT_ACTIVE'),
          ));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicTriggerPressed());
      await settle();

      expect(bloc.state.phase, PanicPhase.idle);
      expect(bloc.state.failure?.code, 'PANIC_ALERT_ACTIVE');
    });
  });

  group('resolve ("I\'m safe now")', () {
    test('reachable from the active-alert view; success clears it back to idle', () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => 42);
      when(() => repository.resolve(42)).thenAnswer((_) async => const Right(null));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicResolvePressed());
      await settle();

      expect(bloc.state.phase, PanicPhase.idle);
      expect(bloc.state.alertId, isNull);
    });

    test('a refusal stays on the active view with the failure shown, retryable', () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => 42);
      when(() => repository.resolve(42))
          .thenAnswer((_) async => const Left(Failure(message: 'nf', code: 'NOT_FOUND')));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicResolvePressed());
      await settle();

      expect(bloc.state.phase, PanicPhase.active);
      expect(bloc.state.alertId, 42);
      expect(bloc.state.failure?.code, 'NOT_FOUND');
    });

    test('no alertId yet (still queued) -> resolve is a no-op, never calls the repository',
        () async {
      when(() => repository.currentActiveAlertId()).thenAnswer((_) async => null);
      when(() => repository.trigger())
          .thenAnswer((_) async => const Right(TriggerOutcome.queued()));

      final bloc = build()..add(const PanicHubStarted());
      await settle();
      bloc.add(const PanicTriggerPressed());
      await settle();
      bloc.add(const PanicResolvePressed());
      await settle();

      verifyNever(() => repository.resolve(any()));
    });
  });
}
