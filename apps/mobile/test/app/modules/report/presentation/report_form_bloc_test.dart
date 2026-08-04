import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/category_form_schema_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_input.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_taxonomy.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/photo_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/submit_report_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_form_bloc.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_form_event.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_form_state.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockLocationGateway extends Mock implements LocationGateway {}

class MockPhotoGateway extends Mock implements PhotoGateway {}

class FakeReportInput extends Fake implements ReportInput {}

void main() {
  late MockReportRepository repository;
  late MockLocationGateway location;
  late MockPhotoGateway photos;
  var keyCounter = 0;

  setUpAll(() => registerFallbackValue(FakeReportInput()));

  setUp(() {
    repository = MockReportRepository();
    location = MockLocationGateway();
    photos = MockPhotoGateway();
    keyCounter = 0;
    when(() => repository.getCategoryForms()).thenAnswer((_) async => const Right([
          CategoryFormSchemaEntity(category: 'missing', fields: [
            CategoryFormField(name: 'age', type: 'number', required_: true),
          ]),
        ]));
    when(() => location.currentPosition()).thenAnswer(
        (_) async => const Right(GeoPoint(lat: -23.5, lng: -46.6)));
  });

  ReportFormBloc build() => ReportFormBloc(
        SubmitReportUsecase(repository),
        repository,
        location,
        photos,
        clientKeyFactory: () => 'key-${keyCounter++}',
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ReportSubmitPressed submitEvent() => const ReportSubmitPressed(
        category: 'assault',
        subject: 'adult',
        anonymous: true,
      );

  group('start-up', () {
    test('loads the form catalog and the position', () async {
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      expect(bloc.state.formsStatus, FormsStatus.ready);
      expect(bloc.state.forms['missing']!.single.name, 'age');
      expect(bloc.state.positionStatus, PositionStatus.ready);
      expect(bloc.state.position, const GeoPoint(lat: -23.5, lng: -46.6));
    });

    test('position denial is a retryable state, never a crash', () async {
      when(() => location.currentPosition()).thenAnswer((_) async =>
          const Left(Failure(message: 'denied', code: 'LOCATION_DENIED')));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      expect(bloc.state.positionStatus, PositionStatus.failed);
      expect(bloc.state.canSubmit, isFalse);

      when(() => location.currentPosition()).thenAnswer(
          (_) async => const Right(GeoPoint(lat: 1, lng: 2)));
      bloc.add(const ReportPositionRetryRequested());
      await settle();

      expect(bloc.state.positionStatus, PositionStatus.ready);
    });
  });

  group('photos (decisions 129/130)', () {
    test('adds, removes, and refuses the 11th photo', () async {
      var picks = 0;
      when(() => photos.pickFromGallery()).thenAnswer((_) async => '/tmp/p${picks++}.jpg');
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      for (var i = 0; i < maxPhotosPerReport + 1; i++) {
        bloc.add(const ReportPhotoPickRequested(fromCamera: false));
        await settle();
      }
      expect(bloc.state.photos.length, maxPhotosPerReport);

      bloc.add(const ReportPhotoRemoved(0));
      await settle();
      expect(bloc.state.photos.length, maxPhotosPerReport - 1);
    });

    test('keeping the original records the warning version the reporter saw '
        '(decisions 86/130)', () async {
      when(() => photos.pickFromCamera()).thenAnswer((_) async => '/tmp/a.jpg');
      final bloc = build()
        ..add(const ReportFormStarted())
        ..add(const ReportPhotoPickRequested(fromCamera: true));
      await settle();

      bloc.add(const ReportPhotoKeepOriginalChanged(0, keep: true));
      await settle();
      expect(bloc.state.photos.single.keepOriginal, isTrue);
      expect(bloc.state.photos.single.exifWarningVersion, exifWarningVersion);

      bloc.add(const ReportPhotoKeepOriginalChanged(0, keep: false));
      await settle();
      expect(bloc.state.photos.single.keepOriginal, isFalse);
      expect(bloc.state.photos.single.exifWarningVersion, isNull);
    });

    test('a cancelled pick changes nothing', () async {
      when(() => photos.pickFromGallery()).thenAnswer((_) async => null);
      final bloc = build()
        ..add(const ReportFormStarted())
        ..add(const ReportPhotoPickRequested(fromCamera: false));
      await settle();

      expect(bloc.state.photos, isEmpty);
    });
  });

  group('submit', () {
    test('online success goes submitting → submittedOnline with the id', () async {
      when(() => repository.submit(any()))
          .thenAnswer((_) async => const Right(SubmitOutcome.online(7)));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      final states = <SubmitStatus>[];
      final sub = bloc.stream.listen((s) => states.add(s.submitStatus));
      bloc.add(submitEvent());
      await settle();

      expect(states, [SubmitStatus.submitting, SubmitStatus.submittedOnline]);
      expect(bloc.state.reportId, 7);
      await sub.cancel();
    });

    test('queued outcome is its own state — a promise, not an error', () async {
      when(() => repository.submit(any()))
          .thenAnswer((_) async => const Right(SubmitOutcome.queued()));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      bloc.add(submitEvent());
      await settle();

      expect(bloc.state.submitStatus, SubmitStatus.queuedOffline);
    });

    test('failure carries the Failure for code-translated rendering', () async {
      when(() => repository.submit(any())).thenAnswer((_) async => const Left(
          Failure(message: 'blocked', statusCode: 451, code: 'LEGAL_BLOCKED')));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      bloc.add(submitEvent());
      await settle();

      expect(bloc.state.submitStatus, SubmitStatus.failed);
      expect(bloc.state.failure!.code, 'LEGAL_BLOCKED');
    });

    test('without a position nothing is sent (API requires it)', () async {
      when(() => location.currentPosition()).thenAnswer(
          (_) async => const Left(Failure(message: 'denied')));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      bloc.add(submitEvent());
      await settle();

      verifyNever(() => repository.submit(any()));
    });

    test('retries reuse the SAME clientKey; a new draft gets a new one '
        '(decision 137)', () async {
      when(() => repository.submit(any())).thenAnswer((_) async => const Left(
          Failure(message: 'oops', statusCode: 500, code: 'INTERNAL')));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      bloc.add(submitEvent());
      await settle();
      when(() => repository.submit(any()))
          .thenAnswer((_) async => const Right(SubmitOutcome.online(1)));
      bloc.add(submitEvent());
      await settle();

      final captured = verify(() => repository.submit(captureAny())).captured;
      expect((captured[0] as ReportInput).clientKey, (captured[1] as ReportInput).clientKey);

      bloc.add(const ReportFormReset());
      await settle();
      bloc.add(submitEvent());
      await settle();

      final third = verify(() => repository.submit(captureAny())).captured.single;
      expect((third as ReportInput).clientKey,
          isNot((captured[0] as ReportInput).clientKey));
    });

    test('reset clears the draft but keeps catalog and position', () async {
      when(() => repository.submit(any()))
          .thenAnswer((_) async => const Right(SubmitOutcome.online(7)));
      final bloc = build()..add(const ReportFormStarted());
      await settle();

      bloc.add(submitEvent());
      await settle();
      bloc.add(const ReportFormReset());
      await settle();

      expect(bloc.state.submitStatus, SubmitStatus.idle);
      expect(bloc.state.formsStatus, FormsStatus.ready);
      expect(bloc.state.positionStatus, PositionStatus.ready);
    });
  });
}
