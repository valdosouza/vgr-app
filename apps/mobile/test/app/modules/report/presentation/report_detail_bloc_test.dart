import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vgr_mobile/app/modules/report/data/my_reports_store.dart';
import 'package:vgr_mobile/app/modules/report/domain/entity/report_view_entity.dart';
import 'package:vgr_mobile/app/modules/report/domain/repository/report_repository.dart';
import 'package:vgr_mobile/app/modules/report/domain/usecase/get_report_view_usecase.dart';
import 'package:vgr_mobile/app/modules/report/presentation/bloc/report_detail_bloc.dart';

class MockReportRepository extends Mock implements ReportRepository {}

const _view = ReportViewEntity(
  access: ReportAccess.public,
  reportId: 5,
  category: 'robbery',
  subject: 'property',
  tier: 'medium',
  status: 'open',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReportRepository repository;
  late MyReportsStore myReports;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = MockReportRepository();
    myReports = MyReportsStore(prefs: await SharedPreferences.getInstance());
  });

  ReportDetailBloc build() =>
      ReportDetailBloc(GetReportViewUsecase(repository), myReports);

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
}
