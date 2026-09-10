import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/shared/data/my_reports_store.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/feed_item_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/list_nearby_reports_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/nearby_feed_bloc.dart';
import 'package:vgr_mobile/app/modules/report/presentation/page/nearby_feed_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockLocationGateway extends Mock implements LocationGateway {}

FeedItemEntity _item(int id, {Direction? directionEstimate}) => FeedItemEntity(
      reportId: id,
      category: 'missing',
      subject: 'child',
      tier: 'medium',
      position: const GeoPoint(lat: -23.5, lng: -46.6),
      distanceKm: 1.5,
      createdAt: '2026-08-04T18:15:00.000Z',
      directionEstimate: directionEstimate,
    );

void main() {
  late MockReportRepository repository;
  late MockLocationGateway location;

  setUpAll(() {
    registerFallbackValue(const GeoPoint(lat: 0, lng: 0));
    registerFallbackValue(FeedOrder.recency);
  });

  setUp(() {
    repository = MockReportRepository();
    location = MockLocationGateway();
    when(() => location.currentPosition()).thenAnswer(
        (_) async => const Right(GeoPoint(lat: -23.5, lng: -46.6)));
  });

  Future<void> pumpPage(WidgetTester tester,
      {void Function(int)? onOpenReport,
      VoidCallback? onNewReport,
      VoidCallback? onOpenPanic,
      bool identified = false,
      MyReportsStore? myReports}) async {
    await pumpLocalized(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => IdentityBloc()
              ..add(identified
                  ? const ProviderLoginCompleted(
                      role: Role.reporter,
                      anonymityMode: AnonymityMode.identifiedNoReward,
                      token: 'jwt',
                    )
                  : const ProviderLoginCompleted(
                      role: Role.anonymous,
                      anonymityMode: AnonymityMode.anonymous,
                    )),
          ),
          BlocProvider<NearbyFeedBloc>(
            create: (_) => NearbyFeedBloc(ListNearbyReportsUsecase(repository), location,
                myReports: myReports),
          ),
        ],
        child: NearbyFeedPage(
          onOpenReport: onOpenReport,
          onNewReport: onNewReport,
          onOpenPanic: onOpenPanic,
        ),
      ),
    );
  }

  testWidgets('renders loaded items with degraded distance and time', (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(FeedPageEntity(
              items: [_item(1)],
              page: 1,
              hasMore: false,
              order: FeedOrder.recency,
            )));

    await pumpPage(tester);

    expect(find.byKey(const Key('feed-item-1')), findsOneWidget);
    expect(find.textContaining('Missing'), findsOneWidget);
    expect(find.textContaining('~1.5 km'), findsOneWidget);
    expect(find.byKey(const Key('feed-load-more-button')), findsNothing);
  });

  testWidgets('badges the reports registered from this device, and only those',
      (tester) async {
    // pumpLocalized resets the prefs mock, so hand the store an instance
    // that already holds the entry (its in-memory cache survives the reset).
    SharedPreferences.setMockInitialValues({});
    final store = MyReportsStore(prefs: await SharedPreferences.getInstance());
    await store.save(2, 'some-client-key');
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(FeedPageEntity(
              items: [_item(1), _item(2, directionEstimate: Direction.n)],
              page: 1,
              hasMore: false,
              order: FeedOrder.recency,
            )));

    await pumpPage(tester, myReports: store);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-item-1-mine')), findsNothing);
    expect(find.byKey(const Key('feed-item-2-mine')), findsOneWidget);
    expect(find.text('Your report'), findsOneWidget);
    // The badge shares the trailing slot with the direction indicator.
    expect(find.byKey(const Key('feed-item-2-direction')), findsOneWidget);
  });

  group('direction sighting trailing indicator (DS2 — decisions 202-204)', () {
    testWidgets('an item WITH a directionEstimate shows the read-only trailing label',
        (tester) async {
      when(() => repository.listNearby(any(), 1, FeedOrder.recency)).thenAnswer(
          (_) async => Right(FeedPageEntity(
                items: [_item(1, directionEstimate: Direction.n)],
                page: 1,
                hasMore: false,
                order: FeedOrder.recency,
              )));

      await pumpPage(tester);

      expect(find.byKey(const Key('feed-item-1-direction')), findsOneWidget);
      expect(find.text('North'), findsOneWidget);
    });

    testWidgets('an item with no estimate (below the floor / ineligible category) shows '
        'no trailing indicator at all', (tester) async {
      when(() => repository.listNearby(any(), 1, FeedOrder.recency))
          .thenAnswer((_) async => Right(FeedPageEntity(
                items: [_item(1)],
                page: 1,
                hasMore: false,
                order: FeedOrder.recency,
              )));

      await pumpPage(tester);

      expect(find.byKey(const Key('feed-item-1-direction')), findsNothing);
    });
  });

  testWidgets('empty state renders distinctly with a retry', (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => const Right(FeedPageEntity(
            items: [], page: 1, hasMore: false, order: FeedOrder.recency)));

    await pumpPage(tester);

    expect(find.byKey(const Key('feed-empty')), findsOneWidget);
  });

  testWidgets('error state renders the code-translated failure', (tester) async {
    when(() => location.currentPosition()).thenAnswer((_) async =>
        const Left(Failure(message: 'denied', code: 'LOCATION_DENIED')));

    await pumpPage(tester);

    expect(find.byKey(const Key('feed-error')), findsOneWidget);
    expect(
        find.text('Location permission denied — the report needs where it happened.'),
        findsOneWidget);
  });

  testWidgets('load more fetches and appends the next page', (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(FeedPageEntity(
            items: [_item(1)], page: 1, hasMore: true, order: FeedOrder.recency)));
    when(() => repository.listNearby(any(), 2, FeedOrder.recency))
        .thenAnswer((_) async => Right(FeedPageEntity(
            items: [_item(2)], page: 2, hasMore: false, order: FeedOrder.recency)));

    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('feed-load-more-button')));
    await tester.tap(find.byKey(const Key('feed-load-more-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feed-item-1')), findsOneWidget);
    expect(find.byKey(const Key('feed-item-2')), findsOneWidget);
  });

  testWidgets('tapping an item opens its detail', (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => Right(FeedPageEntity(
            items: [_item(7)], page: 1, hasMore: false, order: FeedOrder.recency)));

    int? opened;
    await pumpPage(tester, onOpenReport: (id) => opened = id);
    await tester.tap(find.byKey(const Key('feed-item-7')));

    expect(opened, 7);
  });

  testWidgets('the new-report action is always one tap away (123)', (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency))
        .thenAnswer((_) async => const Right(FeedPageEntity(
            items: [], page: 1, hasMore: false, order: FeedOrder.recency)));

    var newReport = false;
    await pumpPage(tester, onNewReport: () => newReport = true);
    await tester.tap(find.byKey(const Key('feed-new-report-button')));

    expect(newReport, isTrue);
  });

  testWidgets('anonymous visitor sees the login action, not the account one '
      '(decisions 119/123 — auth is optional and never blocks the feed)',
      (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency)).thenAnswer(
        (_) async => const Right(FeedPageEntity(
            items: [], page: 1, hasMore: false, order: FeedOrder.recency)));

    await pumpPage(tester, identified: false);

    expect(find.byKey(const Key('feed-login-button')), findsOneWidget);
    expect(find.byKey(const Key('feed-account-button')), findsNothing);
  });

  testWidgets('the panic action is reachable from the feed at any time (decision 62), '
      'independent of the report flow', (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency)).thenAnswer(
        (_) async => const Right(FeedPageEntity(
            items: [], page: 1, hasMore: false, order: FeedOrder.recency)));

    var openedPanic = false;
    await pumpPage(tester, onOpenPanic: () => openedPanic = true);
    await tester.tap(find.byKey(const Key('feed-panic-button')));

    expect(openedPanic, isTrue);
  });

  testWidgets('identified user sees the account action, not the login one',
      (tester) async {
    when(() => repository.listNearby(any(), 1, FeedOrder.recency)).thenAnswer(
        (_) async => const Right(FeedPageEntity(
            items: [], page: 1, hasMore: false, order: FeedOrder.recency)));

    await pumpPage(tester, identified: true);

    expect(find.byKey(const Key('feed-account-button')), findsOneWidget);
    expect(find.byKey(const Key('feed-login-button')), findsNothing);
  });
}
