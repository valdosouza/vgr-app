import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/category_form_schema_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_input.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/photo_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/submit_report_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_form_bloc.dart';
import 'package:vgr_mobile/app/modules/report/presentation/page/report_form_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockReportRepository extends Mock implements ReportRepository {}

class MockLocationGateway extends Mock implements LocationGateway {}

class MockPhotoGateway extends Mock implements PhotoGateway {}

class FakeReportInput extends Fake implements ReportInput {}

void main() {
  late MockReportRepository repository;
  late MockLocationGateway location;
  late MockPhotoGateway photos;

  setUpAll(() => registerFallbackValue(FakeReportInput()));

  setUp(() {
    repository = MockReportRepository();
    location = MockLocationGateway();
    photos = MockPhotoGateway();
    when(() => repository.getCategoryForms()).thenAnswer((_) async => const Right([
          CategoryFormSchemaEntity(category: 'missing', fields: [
            CategoryFormField(name: 'age', type: 'number', required_: true),
            CategoryFormField(name: 'clothing', type: 'string', required_: false),
            CategoryFormField(name: 'last seen', type: 'date', required_: false),
          ]),
        ]));
    when(() => location.currentPosition()).thenAnswer(
        (_) async => const Right(GeoPoint(lat: -23.5, lng: -46.6)));
    when(() => repository.submit(any()))
        .thenAnswer((_) async => const Right(SubmitOutcome.online(7)));
  });

  Future<void> pumpPage(WidgetTester tester) => pumpLocalized(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider<IdentityBloc>(create: (_) => IdentityBloc()),
            BlocProvider<ReportFormBloc>(
              create: (_) => ReportFormBloc(
                SubmitReportUsecase(repository),
                repository,
                location,
                photos,
              ),
            ),
          ],
          child: const ReportFormPage(),
        ),
      );

  // The form is longer than the test viewport — bring the target into
  // view before tapping, both in the page scroll and in dropdown menus.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> selectCategoryAndSubject(WidgetTester tester,
      {String category = 'Missing'}) async {
    await tapVisible(tester, find.byKey(const Key('report-category-dropdown')));
    await tapVisible(tester, find.text(category).last);
    await tapVisible(tester, find.byKey(const Key('report-subject-dropdown')));
    await tapVisible(tester, find.text('Adult').last);
  }

  testWidgets('renders both mandatory axes and the anonymous notice', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('report-category-dropdown')), findsOneWidget);
    expect(find.byKey(const Key('report-subject-dropdown')), findsOneWidget);
    expect(find.text('This report is anonymous.'), findsOneWidget);
    expect(find.text('Location captured'), findsOneWidget);
  });

  testWidgets('detail fields render dynamically from the schema — 3 fields, '
      'no hardcoded per-category widget (decision 47)', (tester) async {
    await pumpPage(tester);
    await selectCategoryAndSubject(tester);

    expect(find.byKey(const Key('report-field-age')), findsOneWidget);
    expect(find.byKey(const Key('report-field-clothing')), findsOneWidget);
    expect(find.byKey(const Key('report-field-last seen')), findsOneWidget);
  });

  testWidgets('a missing required field blocks submission client-side', (tester) async {
    await pumpPage(tester);
    await selectCategoryAndSubject(tester);

    await tapVisible(tester, find.byKey(const Key('report-submit-button')));

    expect(find.text('Required field.'), findsOneWidget);
    verifyNever(() => repository.submit(any()));
  });

  testWidgets('valid submission reaches the bloc and shows the confirmation',
      (tester) async {
    await pumpPage(tester);
    await selectCategoryAndSubject(tester);
    await tester.enterText(find.byKey(const Key('report-field-age')), '8');

    await tapVisible(tester, find.byKey(const Key('report-submit-button')));

    expect(find.byKey(const Key('report-success-view')), findsOneWidget);
    final input =
        verify(() => repository.submit(captureAny())).captured.single as ReportInput;
    expect(input.category, 'missing');
    expect(input.subject, 'adult');
    expect(input.detailFields['age'], 8);
    expect(input.anonymous, isTrue);
  });

  testWidgets('queued submission shows the offline banner (spec scenario)',
      (tester) async {
    when(() => repository.submit(any()))
        .thenAnswer((_) async => const Right(SubmitOutcome.queued()));
    await pumpPage(tester);
    await selectCategoryAndSubject(tester);
    await tester.enterText(find.byKey(const Key('report-field-age')), '8');

    await tapVisible(tester, find.byKey(const Key('report-submit-button')));

    expect(find.byKey(const Key('report-queued-banner')), findsOneWidget);
  });

  testWidgets('free tag is the XOR alternative: picking "Other" swaps the field in',
      (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('report-freetag-field')), findsNothing);
    await tester.tap(find.byKey(const Key('report-category-dropdown')));
    await tester.pumpAndSettle();
    // Last of 13 options — the lazy menu list only builds it once scrolled to.
    await tester.scrollUntilVisible(find.text('Other (describe)'), 100,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other (describe)').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('report-freetag-field')), findsOneWidget);
  });

  testWidgets('keeping EXIF demands the informed-choice dialog first '
      '(decisions 130/139)', (tester) async {
    when(() => photos.pickFromCamera()).thenAnswer((_) async => '/tmp/a.jpg');
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('report-add-camera-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-photo-0')), findsOneWidget);
    expect(find.text('EXIF kept'), findsNothing);

    await tester.tap(find.byKey(const Key('report-photo-0')));
    await tester.pumpAndSettle();
    // Anonymous flow gets the reinforced paragraph (decision 130).
    expect(find.textContaining('anonymously'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-exif-keep-button')));
    await tester.pumpAndSettle();
    expect(find.text('EXIF kept'), findsOneWidget);
  });

  testWidgets('failed submission renders the code-translated error', (tester) async {
    when(() => repository.submit(any())).thenAnswer((_) async => const Left(
        Failure(message: 'blocked', statusCode: 451, code: 'LEGAL_BLOCKED')));
    await pumpPage(tester);
    await selectCategoryAndSubject(tester);
    await tester.enterText(find.byKey(const Key('report-field-age')), '8');

    await tapVisible(tester, find.byKey(const Key('report-submit-button')));

    expect(find.byKey(const Key('report-submit-error')), findsOneWidget);
    expect(find.text('Action blocked in this jurisdiction by a legal decision.'),
        findsOneWidget);
  });
}

