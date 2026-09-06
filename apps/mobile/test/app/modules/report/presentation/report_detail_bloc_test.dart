import 'dart:async';

import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
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
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/get_report_view_usecase.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/resolve_report_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_detail_bloc.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockRatingRepository extends Mock implements RatingRepository {}

class MockDirectionSightingRepository extends Mock implements DirectionSightingRepository {}

const _view = ReportViewEntity(
  access: ReportAccess.public,
  reportId: 5,
  category: 'robbery',
  subject: 'property',
  tier: 'medium',
  status: 'open',
);

const _resolvedOwnerView = ReportViewEntity(
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
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  ReportDetailBloc build() => ReportDetailBloc(
        GetReportViewUsecase(repository),
        myReports,
        ResolveReportUsecase(repository),
        RateOfferUsecase(ratingRepository),
        LogSightingUsecase(directionSightingRepository),
        directionSightingLocalStore,
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('loads the server-resolved view', () async {
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));

    final bloc = build()..add(const DetailStarted(5));
    await settle();

    final loaded = bloc.state as DetailLoaded;
    expect(loaded.view.access, ReportAccess.public);
    expect(loaded.clientKey, isNull);
  });

  test('carries the clientKey when this device owns the report (134)', () async {
    await myReports.save(5, 'key-5');
    when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));

    final bloc = build()..add(const DetailStarted(5));
    await settle();

    expect((bloc.state as DetailLoaded).clientKey, 'key-5');
  });

  test('a failed load is a retryable Error state', () async {
    when(() => repository.getReport(5)).thenAnswer(
        (_) async => const Left(Failure(message: 'gone', statusCode: 404)));

    final bloc = build()..add(const DetailStarted(5));
    await settle();

    expect((bloc.state as DetailError).failure.statusCode, 404);
  });

  test('thumbVariant protects the blur-only rule for public high tier (128)', () {
    const highPublic = ReportViewEntity(
      access: ReportAccess.public,
      reportId: 1,
      category: 'assault',
      subject: 'adult',
      tier: 'high',
      status: 'open',
    );
    const highOwner = ReportViewEntity(
      access: ReportAccess.owner,
      reportId: 1,
      category: 'assault',
      subject: 'adult',
      tier: 'high',
      status: 'open',
    );
    expect(highPublic.thumbVariant, 'blur');
    expect(highOwner.thumbVariant, 'thumb');
    expect(_view.thumbVariant, 'thumb');
  });

  group('DetailResolvePressed (decisions 18/131/179)', () {
    const openOwnerView = ReportViewEntity(
      access: ReportAccess.owner,
      reportId: 5,
      category: 'robbery',
      subject: 'property',
      tier: 'medium',
      status: 'open',
    );

    test('success reloads the view (now resolved)', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(openOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => repository.resolve(5)).thenAnswer((_) async => const Right(null));
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));

      bloc.add(const DetailResolvePressed());
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.view.status, 'resolved');
      expect(loaded.resolving, isFalse);
    });

    test('sets resolving true while in flight', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(openOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      final completer = Completer<Either<Failure, void>>();
      when(() => repository.resolve(5)).thenAnswer((_) => completer.future);

      bloc.add(const DetailResolvePressed());
      await settle();

      expect((bloc.state as DetailLoaded).resolving, isTrue);
      completer.complete(const Right(null));
    });

    test('422 BUSINESS_RULE "already resolved" is treated as success (judgment call) — '
        'the view still reloads', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(openOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => repository.resolve(5)).thenAnswer((_) async => const Left(
          Failure(message: 'Report is already resolved', statusCode: 422, code: 'BUSINESS_RULE')));
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));

      bloc.add(const DetailResolvePressed());
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.view.status, 'resolved');
    });

    test('a genuine refusal (404 non-owner) surfaces without wedging the queue — the view '
        'stays as loaded, resolving resets', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(openOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => repository.resolve(5)).thenAnswer(
          (_) async => const Left(Failure(message: 'nf', statusCode: 404, code: 'NOT_FOUND')));

      bloc.add(const DetailResolvePressed());
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.resolving, isFalse);
      expect(loaded.actionFailure?.code, 'NOT_FOUND');
      expect(loaded.view.status, 'open'); // unchanged — no reload on refusal
      verify(() => repository.getReport(5)).called(1); // never reloaded a second time
    });

    test('a transport failure (queued) is also treated as success — the view reloads',
        () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(openOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => repository.resolve(5)).thenAnswer((_) async => const Right(null));
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));

      bloc.add(const DetailResolvePressed());
      await settle();

      expect((bloc.state as DetailLoaded).view.status, 'resolved');
    });
  });

  group('DetailRatePressed (decisions 48/180-184)', () {
    test('a successful ONLINE rate patches the offer locally — no reload needed', () async {
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 4)).thenAnswer(
        (_) async => const Right(RateOutcome.online(RatingEntity(
          ratingId: 9, reportId: 5, helpOfferId: 1, score: 4, createdAt: 'now',
        ))),
      );

      bloc.add(const DetailRatePressed(offerId: 1, score: 4));
      await settle();

      final loaded = bloc.state as DetailLoaded;
      final offer = loaded.view.offers!.single;
      expect(offer.rating!.score, 4);
      expect(offer.rating!.ratable, isFalse);
      expect(loaded.ratingOfferId, isNull);
      // Patched locally — the only getReport call is DetailStarted's own.
      verify(() => repository.getReport(5)).called(1);
    });

    test('a QUEUED (offline) rate patches optimistically with the submitted score', () async {
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 2))
          .thenAnswer((_) async => const Right(RateOutcome.queued()));

      bloc.add(const DetailRatePressed(offerId: 1, score: 2));
      await settle();

      final offer = (bloc.state as DetailLoaded).view.offers!.single;
      expect(offer.rating!.score, 2);
      expect(offer.rating!.ratable, isFalse);
    });

    test('sets ratingOfferId while in flight so the control can disable itself', () async {
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      final completer = Completer<Either<Failure, RateOutcome>>();
      when(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 3))
          .thenAnswer((_) => completer.future);

      bloc.add(const DetailRatePressed(offerId: 1, score: 3));
      await settle();

      expect((bloc.state as DetailLoaded).ratingOfferId, 1);
      completer.complete(const Right(RateOutcome.queued()));
    });

    test('a failure surfaces via actionFailure and clears ratingOfferId, offer unchanged',
        () async {
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 5)).thenAnswer(
          (_) async => const Left(Failure(message: 'dup', statusCode: 409, code: 'ALREADY_RATED')));

      bloc.add(const DetailRatePressed(offerId: 1, score: 5));
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.ratingOfferId, isNull);
      expect(loaded.actionFailure?.code, 'ALREADY_RATED');
      expect(loaded.view.offers!.single.rating!.score, isNull); // unchanged
    });

    test('ignored when the offer is not ratable — never calls the repository', () async {
      const alreadyRatedView = ReportViewEntity(
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
      );
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(alreadyRatedView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();

      bloc.add(const DetailRatePressed(offerId: 1, score: 5));
      await settle();

      verifyNever(() => ratingRepository.rateOffer(
          reportId: any(named: 'reportId'),
          offerId: any(named: 'offerId'),
          score: any(named: 'score')));
    });

    test('ignored while a rating is already in flight — no second race', () async {
      when(() => repository.getReport(5))
          .thenAnswer((_) async => const Right(_resolvedOwnerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      final completer = Completer<Either<Failure, RateOutcome>>();
      when(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 3))
          .thenAnswer((_) => completer.future);

      bloc.add(const DetailRatePressed(offerId: 1, score: 3));
      await settle();
      bloc.add(const DetailRatePressed(offerId: 1, score: 4)); // second tap while in flight
      await settle();

      verify(() => ratingRepository.rateOffer(reportId: 5, offerId: 1, score: 3)).called(1);
      completer.complete(const Right(RateOutcome.queued()));
    });
  });

  group('DetailSightPressed (DS2 — decisions 200-207)', () {
    test('DetailStarted carries null when this device never sighted this report',
        () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));

      final bloc = build()..add(const DetailStarted(5));
      await settle();

      expect((bloc.state as DetailLoaded).sightedDirection, isNull);
    });

    test('DetailStarted carries the locally-remembered direction (a previous session '
        'already sighted this report)', () async {
      await directionSightingLocalStore.saveSighting(reportId: 5, direction: Direction.ne);
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));

      final bloc = build()..add(const DetailStarted(5));
      await settle();

      expect((bloc.state as DetailLoaded).sightedDirection, Direction.ne);
    });

    test('a successful ONLINE sighting sets sightedDirection and surfaces the private '
        'write-response feedback (estimate/count)', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.n))
          .thenAnswer((_) async => const Right(SightOutcome.online(DirectionSightingResult(
                sightingId: 501, reportId: 5, estimate: Direction.n, count: 6,
              ))));

      bloc.add(const DetailSightPressed(Direction.n));
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.sightedDirection, Direction.n);
      expect(loaded.sighting, isFalse);
      expect(loaded.sightFeedback?.estimate, Direction.n);
      expect(loaded.sightFeedback?.count, 6);
    });

    test('a QUEUED (offline) sighting sets sightedDirection optimistically, with no '
        'private feedback yet (decision 28)', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.sw))
          .thenAnswer((_) async => const Right(SightOutcome.queued()));

      bloc.add(const DetailSightPressed(Direction.sw));
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.sightedDirection, Direction.sw);
      expect(loaded.sightFeedback, isNull);
    });

    test('sets sighting true while in flight so the picker can disable itself', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      final completer = Completer<Either<Failure, SightOutcome>>();
      when(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.e))
          .thenAnswer((_) => completer.future);

      bloc.add(const DetailSightPressed(Direction.e));
      await settle();

      expect((bloc.state as DetailLoaded).sighting, isTrue);
      completer.complete(const Right(SightOutcome.queued()));
    });

    test('a Failure the API judged surfaces via actionFailure — nothing recorded, '
        'the picker stays offered', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      when(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.n))
          .thenAnswer((_) async => const Left(Failure(
              message: 'not eligible', statusCode: 422,
              code: 'DIRECTION_SIGHTING_NOT_ELIGIBLE')));

      bloc.add(const DetailSightPressed(Direction.n));
      await settle();

      final loaded = bloc.state as DetailLoaded;
      expect(loaded.sighting, isFalse);
      expect(loaded.sightedDirection, isNull);
      expect(loaded.actionFailure?.code, 'DIRECTION_SIGHTING_NOT_ELIGIBLE');
    });

    test('the owner never dispatches a sighting — ignored, repository never called',
        () async {
      const ownerView = ReportViewEntity(
        access: ReportAccess.owner,
        reportId: 5,
        category: 'robbery',
        subject: 'property',
        tier: 'medium',
        status: 'open',
      );
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(ownerView));
      final bloc = build()..add(const DetailStarted(5));
      await settle();

      bloc.add(const DetailSightPressed(Direction.n));
      await settle();

      verifyNever(() => directionSightingRepository.logSighting(
          reportId: any(named: 'reportId'), direction: any(named: 'direction')));
    });

    test('already sighted (locally remembered) — ignored, never re-calls the repository',
        () async {
      await directionSightingLocalStore.saveSighting(reportId: 5, direction: Direction.w);
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));
      final bloc = build()..add(const DetailStarted(5));
      await settle();

      bloc.add(const DetailSightPressed(Direction.n));
      await settle();

      verifyNever(() => directionSightingRepository.logSighting(
          reportId: any(named: 'reportId'), direction: any(named: 'direction')));
    });

    test('ignored while a sighting is already in flight — no second race', () async {
      when(() => repository.getReport(5)).thenAnswer((_) async => const Right(_view));
      final bloc = build()..add(const DetailStarted(5));
      await settle();
      final completer = Completer<Either<Failure, SightOutcome>>();
      when(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.n))
          .thenAnswer((_) => completer.future);

      bloc.add(const DetailSightPressed(Direction.n));
      await settle();
      bloc.add(const DetailSightPressed(Direction.s)); // second tap while in flight
      await settle();

      verify(() => directionSightingRepository.logSighting(reportId: 5, direction: Direction.n))
          .called(1);
      completer.complete(const Right(SightOutcome.queued()));
    });
  });
}
