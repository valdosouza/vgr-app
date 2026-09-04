import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/panic/domain/entity/panic_entities.dart';
import 'package:vgr_mobile/app/modules/panic/domain/repository/panic_repository.dart';
import 'package:vgr_mobile/app/modules/panic/domain/usecase/list_panic_alerts_usecase.dart';
import 'package:vgr_mobile/app/modules/panic/presentation/bloc/panic_alerts_bloc.dart';
import 'package:vgr_mobile/app/modules/panic/presentation/page/panic_alerts_page.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';

import '../../../../helpers/pump_localized.dart';

class MockPanicRepository extends Mock implements PanicRepository {}

class MockLocationGateway extends Mock implements LocationGateway {}

const _here = GeoPoint(lat: -23.55, lng: -46.63);

/// The responder inbox (192, decisions 195/197): each row is the FIXED
/// client-side template built from {alertId, distanceKm} (196) — never
/// any free text, since the API stores none for a panic alert.
void main() {
  late MockPanicRepository repository;
  late MockLocationGateway locationGateway;
  late StreamController<void> ticks;

  setUpAll(() => registerFallbackValue(const GeoPoint(lat: 0, lng: 0)));

  setUp(() {
    repository = MockPanicRepository();
    locationGateway = MockLocationGateway();
    ticks = StreamController<void>.broadcast();
    when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(_here));
  });

  tearDown(() async => ticks.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => PanicAlertsBloc(
          ListPanicAlertsUsecase(repository),
          locationGateway,
          ticker: (_) => ticks.stream,
        ),
        child: const PanicAlertsPage(),
      ),
    );
  }

  testWidgets('renders the fixed template with distance, oldest first', (tester) async {
    when(() => repository.listAlerts(after: 0, limit: any(named: 'limit'), position: _here))
        .thenAnswer((_) async => const Right([
              ResponderAlertEntity(
                  alertId: 7, distanceKm: 2.0, createdAt: '2026-09-04T09:00:00.000Z', resolved: false),
            ]));

    await pumpPage(tester);

    expect(find.byKey(const Key('panic-alert-7')), findsOneWidget);
    expect(find.textContaining('2.0 km'), findsOneWidget);
  });

  testWidgets('a resolved alert renders distinctly, read only (197 — no action button)',
      (tester) async {
    when(() => repository.listAlerts(after: 0, limit: any(named: 'limit'), position: _here))
        .thenAnswer((_) async => const Right([
              ResponderAlertEntity(
                  alertId: 7, distanceKm: 1.0, createdAt: '2026-09-04T09:00:00.000Z', resolved: true),
            ]));

    await pumpPage(tester);

    expect(find.textContaining('Resolved'), findsOneWidget);
  });

  testWidgets('an empty inbox shows a plain caption, never an error', (tester) async {
    when(() => repository.listAlerts(after: 0, limit: any(named: 'limit'), position: _here))
        .thenAnswer((_) async => const Right([]));

    await pumpPage(tester);

    expect(find.byKey(const Key('panic-alerts-empty')), findsOneWidget);
  });

  testWidgets('a location failure shows an error with a retry', (tester) async {
    when(() => locationGateway.currentPosition()).thenAnswer(
        (_) async => const Left(Failure(message: 'off', code: 'LOCATION_OFF')));

    await pumpPage(tester);

    expect(find.byKey(const Key('panic-alerts-error')), findsOneWidget);
    expect(find.byKey(const Key('panic-alerts-retry-button')), findsOneWidget);
  });

  testWidgets('retry re-fetches after a failure', (tester) async {
    when(() => locationGateway.currentPosition()).thenAnswer(
        (_) async => const Left(Failure(message: 'off', code: 'LOCATION_OFF')));
    await pumpPage(tester);

    when(() => locationGateway.currentPosition()).thenAnswer((_) async => const Right(_here));
    when(() => repository.listAlerts(after: 0, limit: any(named: 'limit'), position: _here))
        .thenAnswer((_) async => const Right([]));
    await tester.tap(find.byKey(const Key('panic-alerts-retry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('panic-alerts-empty')), findsOneWidget);
  });
}
