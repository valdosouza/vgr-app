import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/panic/domain/entity/panic_entities.dart';
import 'package:vgr_mobile/app/modules/panic/domain/repository/panic_repository.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/list_panic_alerts_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/presentation/bloc/panic_alerts_bloc.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';

class MockPanicRepository extends Mock implements PanicRepository {}

class MockLocationGateway extends Mock implements LocationGateway {}

const _here = GeoPoint(lat: -23.55, lng: -46.63);

/// The responder inbox (192: polling only, no push) — mirrors
/// `ChatConversationBloc`'s exact ticker/lifecycle shape: an injectable
/// ticker so no real `Duration(seconds:...)` timer ever runs in a test,
/// started on load/resume, stopped on pause/dispose.
void main() {
  late MockPanicRepository repository;
  late MockLocationGateway locationGateway;
  late StreamController<void> ticks;
  late int tickerCalls;

  setUpAll(() => registerFallbackValue(const GeoPoint(lat: 0, lng: 0)));

  setUp(() {
    repository = MockPanicRepository();
    locationGateway = MockLocationGateway();
    ticks = StreamController<void>.broadcast();
    tickerCalls = 0;
    when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(_here));
  });

  tearDown(() async => ticks.close());

  PanicAlertsBloc build() => PanicAlertsBloc(
        ListPanicAlertsUsecase(repository),
        locationGateway,
        ticker: (_) {
          tickerCalls++;
          return ticks.stream;
        },
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void stubList(int after, List<ResponderAlertEntity> alerts) => when(() => repository.listAlerts(
      after: after, limit: any(named: 'limit'), position: _here)).thenAnswer((_) async => Right(alerts));

  const alert1 = ResponderAlertEntity(alertId: 1, distanceKm: 2.0, createdAt: 't1', resolved: false);
  const alert2 = ResponderAlertEntity(alertId: 2, distanceKm: 1.0, createdAt: 't2', resolved: true);

  test('initial load fetches from 0 with the responder\'s own position and starts polling',
      () async {
    stubList(0, [alert1]);

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();

    expect(bloc.state, isA<PanicAlertsLoaded>());
    expect((bloc.state as PanicAlertsLoaded).alerts, [alert1]);
    expect(tickerCalls, 1);
    await bloc.close();
  });

  test('a location failure never fetches and never starts polling', () async {
    when(() => locationGateway.currentPosition()).thenAnswer(
        (_) async => const Left(Failure(message: 'off', code: 'LOCATION_OFF')));

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();

    expect(bloc.state, isA<PanicAlertsError>());
    expect((bloc.state as PanicAlertsError).failure.code, 'LOCATION_OFF');
    expect(tickerCalls, 0);
    verifyNever(() => repository.listAlerts(
        after: any(named: 'after'), limit: any(named: 'limit'), position: any(named: 'position')));
    await bloc.close();
  });

  test('a poll tick fetches after the highest alertId and APPENDS only what is new (with '
      'each row\'s distance/resolved rendered as served)', () async {
    stubList(0, [alert1]);
    stubList(1, [alert2]);

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();
    ticks.add(null);
    await settle();

    final loaded = bloc.state as PanicAlertsLoaded;
    expect(loaded.alerts, [alert1, alert2]);
    expect(loaded.alerts[0].distanceKm, 2.0);
    expect(loaded.alerts[0].resolved, isFalse);
    expect(loaded.alerts[1].distanceKm, 1.0);
    expect(loaded.alerts[1].resolved, isTrue);
    verify(() => repository.listAlerts(after: 1, limit: any(named: 'limit'), position: _here))
        .called(1);
    await bloc.close();
  });

  test('a poll tick that fails keeps the inbox as it was (transient)', () async {
    stubList(0, [alert1]);
    when(() => repository.listAlerts(after: 1, limit: any(named: 'limit'), position: _here))
        .thenAnswer((_) async => const Left(Failure(message: 'off', code: 'OFFLINE')));

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();
    ticks.add(null);
    await settle();

    expect((bloc.state as PanicAlertsLoaded).alerts, [alert1]);
    await bloc.close();
  });

  test('paused stops the ticker; resumed re-locates (best effort) and polls again', () async {
    stubList(0, [alert1]);
    stubList(1, [alert2]);

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();
    bloc.add(const PanicAlertsPaused());
    await settle();
    ticks.add(null);
    await settle();
    expect((bloc.state as PanicAlertsLoaded).alerts, [alert1]);

    bloc.add(const PanicAlertsResumed());
    await settle();
    verify(() => locationGateway.currentPosition()).called(greaterThanOrEqualTo(2));
    expect((bloc.state as PanicAlertsLoaded).alerts, [alert1, alert2]);
    expect(tickerCalls, 2);
    await bloc.close();
  });

  test('resume keeps the last known position when re-locating fails (best effort, never '
      'loses the screen over a transient blip)', () async {
    stubList(0, [alert1]);
    stubList(1, [alert2]);

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();
    bloc.add(const PanicAlertsPaused());
    await settle();

    when(() => locationGateway.currentPosition()).thenAnswer(
        (_) async => const Left(Failure(message: 'off', code: 'LOCATION_OFF')));
    bloc.add(const PanicAlertsResumed());
    await settle();

    // Still polling with the STALE position — the resume did not crash
    // the screen over a transient relocation blip.
    expect((bloc.state as PanicAlertsLoaded).alerts, [alert1, alert2]);
    await bloc.close();
  });

  test('an empty inbox is a valid loaded state (non-responder or nothing yet)', () async {
    stubList(0, []);

    final bloc = build()..add(const PanicAlertsStarted());
    await settle();

    expect((bloc.state as PanicAlertsLoaded).alerts, isEmpty);
    await bloc.close();
  });
}
