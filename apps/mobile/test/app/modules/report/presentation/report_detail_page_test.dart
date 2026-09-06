import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/data/direction_sighting_local_store.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/domain/entity/direction_sighting_entities.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/domain/repository/direction_sighting_repository.dart';
import 'package:vgr_mobile/app/modules/direction_sighting/domain/usecase/log_sighting_usecase.dart';
import 'package:vgr_mobile/app/modules/rating/domain/entity/rating_entities.dart';
import 'package:vgr_mobile/app/modules/rating/domain/repository/rating_repository.dart';
import 'package:vgr_mobile/app/modules/rating/domain/usecase/rate_offer_usecase.dart';
import 'package:vgr_mobile/app/shared/data/my_reports_store.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_view_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/get_report_view_usecase.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/resolve_report_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_detail_bloc.dart';
import 'package:vgr_mobile/app/modules/report/presentation/page/report_detail_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockDirectionSightingRepository extends Mock implements DirectionSightingRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(Direction.n);
  });

  late MockReportRepository repository;
  late MockRatingRepository ratingRepository;
  late MockDirectionSightingRepository directionSightingRepository;
  late MyReportsStore myReports;
  late DirectionSightingLocalStore directionSightingLocalStore;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MockReportRepository();
    ratingRepository = MockRatingRepository();
    directionSightingRepository = MockDirectionSightingRepository();
    final prefs = await SharedPreferences.getInstance();
    myReports = MyReportsStore(prefs: prefs);
    directionSightingLocalStore = DirectionSightingLocalStore(prefs: prefs);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    int reportId = 5,
    void Function(int reportId)? onOfferHelp,
    void Function(String route)? onOpenChat,
  }) async {
    await pumpLocalized(
      tester,
      BlocProvider<ReportDetailBloc>(
        create: (_) => ReportDetailBloc(
          GetReportViewUsecase(repository),
          myReports,
          ResolveReportUsecase(repository),
          RateOfferUsecase(ratingRepository),
          LogSightingUsecase(directionSightingRepository),
          directionSightingLocalStore,
        ),
        child: ReportDetailPage(
          reportId: reportId,
          mediaBaseUrl: 'http://api.test',
          onOfferHelp: onOfferHelp,
          onOpenChat: onOpenChat,
        ),
      ),
    );
  }

  testWidgets('a non-participant on a Resolved case sees ONLY the closure '
      '(decision 50, spec scenario)', (tester) async {
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.summary,
            reportId: 5,
            category: 'robbery',
            subject: 'property',
            tier: 'medium',
            status: 'resolved',
            resolvedAt: '2026-08-04T18:00:00.000Z',
          ),
        ));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-summary-view')), findsOneWidget);
    expect(find.text('This case was resolved.'), findsOneWidget);
    // No timeline, no details, no offers — nothing but the closure.
    expect(find.text('Timeline'), findsNothing);
    expect(find.text('Details'), findsNothing);
    expect(find.text('Help offers'), findsNothing);
  });

  testWidgets('public open view renders the DEGRADED position as approximate '
      '(decision 135)', (tester) async {
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.public,
            reportId: 5,
            category: 'missing',
            subject: 'child',
            tier: 'medium',
            status: 'open',
            position: GeoPoint(lat: -23.505, lng: -46.605),
            detailFields: {'age': 8},
            createdAt: '2026-08-04T18:15:00.000Z',
            media: [ReportMediaRefEntity(publicId: 'pub-1')],
          ),
        ));

    await pumpPage(tester);

    expect(find.textContaining('Approximate area'), findsOneWidget);
    expect(find.text('age: 8'), findsOneWidget);
    expect(find.byKey(const Key('detail-media-pub-1')), findsOneWidget);
    expect(find.text('Timeline'), findsNothing); // public gets no timeline
  });

  testWidgets('the owner sees timeline and masked offers', (tester) async {
    await myReports.save(5, 'key-5');
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.owner,
            reportId: 5,
            category: 'assault',
            subject: 'adult',
            tier: 'high',
            status: 'open',
            position: GeoPoint(lat: -23.5, lng: -46.6),
            createdAt: '2026-08-04T18:12:33.000Z',
            timeline: [
              TimelineEventEntity(
                  eventType: 'created', createdAt: '2026-08-04T18:12:33.000Z'),
              TimelineEventEntity(
                  eventType: 'help_offered', createdAt: '2026-08-04T18:20:00.000Z'),
            ],
            offers: [
              // High tier: no identity, no timestamp (decisions 40/41/60).
              OfferViewEntity(helpOfferId: 1, helpType: 'physical_presence'),
            ],
          ),
        ));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-owner-badge')), findsOneWidget);
    expect(find.text('Report created'), findsOneWidget);
    expect(find.text('Someone offered help'), findsOneWidget);
    expect(find.text('Anonymous helper'), findsOneWidget);
    expect(find.text('Physical presence'), findsOneWidget);
  });

  testWidgets('a third party on an open case can offer help (A3, decision 10)',
      (tester) async {
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.public,
            reportId: 5,
            category: 'robbery',
            subject: 'property',
            tier: 'medium',
            status: 'open',
          ),
        ));

    int? offered;
    await pumpPage(tester, onOfferHelp: (id) => offered = id);

    final button = find.byKey(const Key('detail-offer-help-button'));
    expect(button, findsOneWidget);
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    expect(offered, 5);
  });

  testWidgets('the owner never sees the offer-help button (decision 20)',
      (tester) async {
    await myReports.save(5, 'key-5');
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.owner,
            reportId: 5,
            category: 'robbery',
            subject: 'property',
            tier: 'medium',
            status: 'open',
          ),
        ));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-offer-help-button')), findsNothing);
  });

  testWidgets('no new offers on a resolved case (decision 18)', (tester) async {
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.summary,
            reportId: 5,
            category: 'robbery',
            subject: 'property',
            tier: 'medium',
            status: 'resolved',
          ),
        ));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-offer-help-button')), findsNothing);
  });

  testWidgets('a failed load renders a retryable error', (tester) async {
    when(() => repository.getReport(5)).thenAnswer(
        (_) async => const Left(Failure(message: 'gone', statusCode: 404,
            code: 'NOT_FOUND')));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-error')), findsOneWidget);
    expect(find.text('Record not found.'), findsOneWidget);
  });

  testWidgets('a hidden case shows the owner the moderation mark — no reason, no action '
      '(B2, decision 167)', (tester) async {
    await myReports.save(5, 'key-5');
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.owner,
            reportId: 5,
            category: 'robbery',
            subject: 'property',
            tier: 'medium',
            status: 'open',
            hidden: true,
          ),
        ));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-hidden-notice')), findsOneWidget);
    expect(find.text('This report is hidden from the public feed by moderation.'),
        findsOneWidget);
    expect(find.textContaining('Reason'), findsNothing);
  });

  testWidgets('a visible case shows no moderation mark', (tester) async {
    await myReports.save(5, 'key-5');
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
          ReportViewEntity(
            access: ReportAccess.owner,
            reportId: 5,
            category: 'robbery',
            subject: 'property',
            tier: 'medium',
            status: 'open',
          ),
        ));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-hidden-notice')), findsNothing);
  });

  group('chat entry (C2, decision 169 — only when the served view carries `chat`)', () {
    testWidgets('owner with threads: button with the unread count → thread list', (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
              chat: ReportChatFacetEntity(threads: 2, unread: 3),
            ),
          ));

      String? route;
      await pumpPage(tester, onOpenChat: (r) => route = r);

      final button = find.byKey(const Key('detail-chat-button'));
      expect(button, findsOneWidget);
      expect(find.text('Chat (3 unread)'), findsOneWidget);
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      expect(route, '/chat/threads/5');
    });

    testWidgets('helper participant with a thread → straight to the conversation', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.participant,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
              chat: ReportChatFacetEntity(threadId: 9, unread: 0),
            ),
          ));

      String? route;
      await pumpPage(tester, onOpenChat: (r) => route = r);

      expect(find.text('Chat'), findsOneWidget);
      final button = find.byKey(const Key('detail-chat-button'));
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      expect(route, '/chat/5/thread/9');
    });

    testWidgets('helper participant with threadId null STILL gets the button — the first '
        'message creates the thread (173)', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.participant,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
              chat: ReportChatFacetEntity(threadId: null, unread: 0),
            ),
          ));

      String? route;
      await pumpPage(tester, onOpenChat: (r) => route = r);

      final button = find.byKey(const Key('detail-chat-button'));
      expect(button, findsOneWidget);
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      expect(route, '/chat/5/thread/new');
    });

    testWidgets('no `chat` facet (public view, anonymous helper) → no button', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-chat-button')), findsNothing);
    });
  });

  group('Encerrar denúncia (RT2, decisions 18/131/179)', () {
    testWidgets('the owner sees the close button on an open case; confirming resolves '
        'and the view reloads', (tester) async {
      await myReports.save(5, 'key-5');
      var reads = 0;
      when(() => repository.getReport(5)).thenAnswer((_) async {
        reads++;
        return Right(reads == 1
            ? const ReportViewEntity(
                access: ReportAccess.owner,
                reportId: 5,
                category: 'robbery',
                subject: 'property',
                tier: 'medium',
                status: 'open',
              )
            : const ReportViewEntity(
                access: ReportAccess.owner,
                reportId: 5,
                category: 'robbery',
                subject: 'property',
                tier: 'medium',
                status: 'resolved',
              ));
      });
      when(() => repository.resolve(5)).thenAnswer((_) async => const Right(null));

      await pumpPage(tester);

      final button = find.byKey(const Key('detail-resolve-button'));
      expect(button, findsOneWidget);
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-resolve-confirm')));
      await tester.pumpAndSettle();

      verify(() => repository.resolve(5)).called(1);
      expect(find.text('Resolved'), findsWidgets);
    });

    testWidgets('cancelling the confirm dialog never calls resolve', (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      final button = find.byKey(const Key('detail-resolve-button'));
      await tester.scrollUntilVisible(button, 200);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-resolve-cancel')));
      await tester.pumpAndSettle();

      verifyNever(() => repository.resolve(5));
    });

    testWidgets('a non-owner never sees the close button', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-resolve-button')), findsNothing);
    });

    testWidgets('an already-resolved owner view has no close button either', (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'resolved',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-resolve-button')), findsNothing);
    });
  });

  group('helper rating control on a resolved case (RT2, decisions 48/180-184)', () {
    testWidgets('a ratable offer shows interactive stars; tapping one dispatches the rating',
        (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'resolved',
              offers: [
                OfferViewEntity(
                  helpOfferId: 1,
                  helpType: 'physical_presence',
                  rating: OfferRatingEntity(score: null, ratable: true),
                ),
              ],
            ),
          ));
      when(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 4)).thenAnswer(
        (_) async => const Right(RateOutcome.online(RatingEntity(
          ratingId: 1, reportId: 5, helpOfferId: 1, score: 4, createdAt: 'now',
        ))),
      );

      await pumpPage(tester);

      final control = find.byKey(const Key('detail-offer-rating-1'));
      expect(control, findsOneWidget);
      final star4 = find.descendant(of: control, matching: find.byKey(const Key('rating-star-4')));
      await tester.scrollUntilVisible(star4, 200);
      await tester.tap(star4);
      await tester.pumpAndSettle();

      verify(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 4)).called(1);
    });

    testWidgets('an already-rated offer shows a read-only score, no tap dispatches anything',
        (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'resolved',
              offers: [
                OfferViewEntity(
                  helpOfferId: 1,
                  helpType: 'physical_presence',
                  rating: OfferRatingEntity(score: 4, ratable: false),
                ),
              ],
            ),
          ));

      await pumpPage(tester);

      final control = find.byKey(const Key('detail-offer-rating-1'));
      expect(control, findsOneWidget);
      final star5 = find.descendant(of: control, matching: find.byKey(const Key('rating-star-5')));
      await tester.scrollUntilVisible(star5, 200);
      await tester.tap(star5);
      await tester.pumpAndSettle();

      verifyNever(() => ratingRepository.rateOffer(
          reportId: any(named: 'reportId'),
          offerId: any(named: 'offerId'),
          score: any(named: 'score')));
    });

    testWidgets('a not-ratable offer with no score (helper has no account) shows no control',
        (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'resolved',
              offers: [
                OfferViewEntity(
                  helpOfferId: 1,
                  helpType: 'physical_presence',
                  rating: OfferRatingEntity(score: null, ratable: false),
                ),
              ],
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-offer-rating-1')), findsNothing);
    });

    testWidgets('an OPEN case never shows a rating control even if `rating` were present',
        (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
              offers: [
                OfferViewEntity(
                  helpOfferId: 1,
                  helpType: 'physical_presence',
                  rating: OfferRatingEntity(score: null, ratable: true),
                ),
              ],
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-offer-rating-1')), findsNothing);
    });
  });

  group('direction sighting (DS2 — decisions 200-207)', () {
    testWidgets('the shared read-only estimate shows whenever the server sent one '
        '(202-204) — regardless of eligibility for the picker', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'assault', // not in the eligible-category mirror
              subject: 'adult',
              tier: 'medium',
              status: 'resolved',
              directionEstimate: Direction.n,
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-direction-estimate')), findsOneWidget);
      expect(find.text('Estimated direction: North'), findsOneWidget);
    });

    testWidgets('no estimate on the view → nothing rendered', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-direction-estimate')), findsNothing);
    });

    testWidgets('an eligible non-owner viewer of an open, eligible-category report sees '
        'the picker; tapping a point dispatches and shows the read-only confirmation '
        'plus the private write-response feedback', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
            ),
          ));
      when(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.n))
          .thenAnswer((_) async => const Right(SightOutcome.online(DirectionSightingResult(
                sightingId: 501, reportId: 5, estimate: Direction.n, count: 6,
              ))));

      await pumpPage(tester);

      final picker = find.byKey(const Key('detail-direction-picker'));
      expect(picker, findsOneWidget);
      final pointN = find.descendant(of: picker, matching: find.byKey(const Key('direction-N')));
      await tester.scrollUntilVisible(pointN, 200);
      await tester.tap(pointN);
      await tester.pumpAndSettle();

      verify(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.n))
          .called(1);
      expect(find.byKey(const Key('detail-direction-picker')), findsNothing);
      expect(find.byKey(const Key('detail-direction-sighted')), findsOneWidget);
      expect(find.text('You pointed North — thanks!'), findsOneWidget);
      expect(find.byKey(const Key('detail-direction-feedback')), findsOneWidget);
      expect(find.text('Current best guess so far: North (6 sightings).'), findsOneWidget);
    });

    testWidgets('a device that already sighted this report (local record) sees the '
        'read-only confirmation instead of the picker, from the first frame', (tester) async {
      await directionSightingLocalStore.saveSighting(reportId: 5, direction: Direction.sw);
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'kidnapping',
              subject: 'adult',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-direction-picker')), findsNothing);
      expect(find.byKey(const Key('detail-direction-sighted')), findsOneWidget);
      expect(find.text('You pointed Southwest — thanks!'), findsOneWidget);
      verifyNever(() => directionSightingRepository.logSighting(
          reportId: any(named: 'reportId'), direction: any(named: 'direction')));
    });

    testWidgets('the owner never sees the picker, even on an open eligible-category case '
        '(200)', (tester) async {
      await myReports.save(5, 'key-5');
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.owner,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-direction-picker')), findsNothing);
      expect(find.byKey(const Key('detail-direction-sighted')), findsNothing);
    });

    testWidgets('a non-eligible category never shows the picker (client-side, '
        'non-authoritative mirror of decision 201)', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'assault',
              subject: 'adult',
              tier: 'medium',
              status: 'open',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-direction-picker')), findsNothing);
    });

    testWidgets('a resolved report never shows the picker', (tester) async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(
            ReportViewEntity(
              access: ReportAccess.public,
              reportId: 5,
              category: 'robbery',
              subject: 'property',
              tier: 'medium',
              status: 'resolved',
            ),
          ));

      await pumpPage(tester);

      expect(find.byKey(const Key('detail-direction-picker')), findsNothing);
    });
  });
}
