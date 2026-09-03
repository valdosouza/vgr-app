import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/repository/reports_repository.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_event.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/report_detail_state.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

ReportPanelDetailEntity detail({bool frozen = false}) => ReportPanelDetailEntity(
      reportId: 7,
      category: 'assault',
      freeTag: null,
      subject: 'child',
      tier: 'high',
      status: 'open',
      anonymous: true,
      frozen: frozen,
      frozenReason: frozen ? 'Writ 1/2026' : null,
      frozenAt: frozen ? '2026-09-01T11:00:00.000Z' : null,
      purged: false,
      createdAt: '2026-09-01T10:00:00.000Z',
      resolvedAt: null,
      expiresAt: null,
      reporter: null,
      position: const ReportPositionEntity(lat: -23.55, lng: -46.63, precisionMeters: 1100),
      detailFields: null,
      timeline: const [],
      media: const [],
      offers: const [],
    );

const _open = ReportFreezeStateEntity(reportId: 7, status: 'open', frozen: false);
const _frozen = ReportFreezeStateEntity(
  reportId: 7,
  status: 'open',
  frozen: true,
  frozenReason: 'Writ 1/2026',
);
const _exact = ReportExactPositionEntity(reportId: 7, lat: -23.5505, lng: -46.6333);

void main() {
  late MockReportsRepository repository;

  setUp(() => repository = MockReportsRepository());

  ReportDetailBloc build() => ReportDetailBloc(repository);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('load fetches the detail AND the freeze state', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));

    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open));
  });

  test('a failed detail (404 / no grant) is an error state', () async {
    const failure = Failure(message: 'gone', statusCode: 404, code: 'NOT_FOUND');
    when(() => repository.getDetail(7)).thenAnswer((_) async => const Left(failure));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));

    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    expect(bloc.state, const ReportDetailError(failure));
  });

  test('a failed freeze state (no case_freeze grant) keeps the detail with freeze = null',
      () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async =>
        const Left(Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN')));

    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: null));
  });

  test('freeze re-fetches BOTH detail and freeze state (server is the authority)', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    when(() => repository.freeze(7, 'Writ 1/2026')).thenAnswer((_) async => const Right(null));
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(frozen: true)));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_frozen));

    bloc.add(const ReportFreezeSubmitted('Writ 1/2026'));
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(frozen: true), freeze: _frozen));
    verify(() => repository.freeze(7, 'Writ 1/2026')).called(1);
    verify(() => repository.getDetail(7)).called(2);
  });

  test('a rejected action keeps the case on screen with the failure (141d same-user)',
      () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(frozen: true)));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_frozen));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    const failure = Failure(message: 'same user', statusCode: 422, code: 'BUSINESS_RULE');
    when(() => repository.approveUnfreeze(7)).thenAnswer((_) async => const Left(failure));

    bloc.add(const ReportUnfreezeApproveSubmitted());
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(frozen: true), freeze: _frozen, failure: failure));
    verify(() => repository.getDetail(7)).called(1);
  });

  test('request unfreeze posts the reason', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail(frozen: true)));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_frozen));
    when(() => repository.requestUnfreeze(7, 'Closed')).thenAnswer((_) async => const Right(null));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    bloc.add(const ReportUnfreezeRequestSubmitted('Closed'));
    await settle();

    verify(() => repository.requestUnfreeze(7, 'Closed')).called(1);
  });

  test('revealing the exact position stores it on the loaded state (decision 159)', () async {
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    when(() => repository.getExactPosition(7)).thenAnswer((_) async => const Right(_exact));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    bloc.add(const ReportExactPositionRequested());
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open, exactPosition: _exact));
  });

  test('a refused exact position (no grant, 403) surfaces as the failure, detail kept',
      () async {
    const failure = Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN');
    when(() => repository.getDetail(7)).thenAnswer((_) async => Right(detail()));
    when(() => repository.getFreezeState(7)).thenAnswer((_) async => const Right(_open));
    when(() => repository.getExactPosition(7)).thenAnswer((_) async => const Left(failure));
    final bloc = build()..add(const ReportDetailRequested(7));
    await settle();

    bloc.add(const ReportExactPositionRequested());
    await settle();

    expect(bloc.state, ReportDetailLoaded(detail(), freeze: _open, failure: failure));
  });

  test('actions before a loaded detail are a no-op', () async {
    final bloc = build()
      ..add(const ReportFreezeSubmitted('x'))
      ..add(const ReportExactPositionRequested());
    await settle();

    expect(bloc.state, const ReportDetailInitial());
    verifyNever(() => repository.freeze(any(), any()));
    verifyNever(() => repository.getExactPosition(any()));
  });
}
