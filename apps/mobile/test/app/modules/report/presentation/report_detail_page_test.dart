import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/report/data/my_reports_store.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_view_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/gateway/location_gateway.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/get_report_view_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_detail_bloc.dart';
import 'package:vgr_mobile/app/modules/report/presentation/page/report_detail_page.dart';

import '../../../../helpers/pump_localized.dart';

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late MockReportRepository repository;
  late MyReportsStore myReports;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MockReportRepository();
    myReports = MyReportsStore(prefs: await SharedPreferences.getInstance());
  });

  Future<void> pumpPage(WidgetTester tester, {int reportId = 5}) async {
    await pumpLocalized(
      tester,
      BlocProvider<ReportDetailBloc>(
        create: (_) =>
            ReportDetailBloc(GetReportViewUsecase(repository), myReports),
        child: ReportDetailPage(reportId: reportId, mediaBaseUrl: 'http://api.test'),
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

  testWidgets('a failed load renders a retryable error', (tester) async {
    when(() => repository.getReport(5)).thenAnswer(
        (_) async => const Left(Failure(message: 'gone', statusCode: 404,
            code: 'NOT_FOUND')));

    await pumpPage(tester);

    expect(find.byKey(const Key('detail-error')), findsOneWidget);
    expect(find.text('Record not found.'), findsOneWidget);
  });
}
