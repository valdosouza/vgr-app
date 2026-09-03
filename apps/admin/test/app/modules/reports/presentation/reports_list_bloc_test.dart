import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/repository/reports_repository.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_list_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_list_event.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_list_state.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

const _empty = ReportPageEntity(items: [], page: 1, pageSize: 20, total: 0);
const _pageOne = ReportPageEntity(items: [], page: 1, pageSize: 20, total: 45);
const _pageTwo = ReportPageEntity(items: [], page: 2, pageSize: 20, total: 45);
const _filters = ReportFiltersEntity(status: 'open', tier: 'high');

void main() {
  late MockReportsRepository repository;

  setUp(() {
    repository = MockReportsRepository();
    registerFallbackValue(const ReportFiltersEntity());
  });

  ReportsListBloc build() => ReportsListBloc(repository);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts idle — the list is never fetched before a search (166: no audit, but no noise)', () {
    expect(build().state, const ReportsListInitial());
    verifyNever(() => repository.search(any(), any(), any()));
  });

  test('a search goes to page 1 with the filters and emits the page', () async {
    when(() => repository.search(_filters, 1, 20)).thenAnswer((_) async => const Right(_pageOne));

    final bloc = build()..add(const ReportsSearchRequested(_filters));
    await settle();

    expect(bloc.state, const ReportsListLoaded(_pageOne, _filters));
  });

  test('page navigation keeps the filters and asks the requested page', () async {
    when(() => repository.search(_filters, 1, 20)).thenAnswer((_) async => const Right(_pageOne));
    when(() => repository.search(_filters, 2, 20)).thenAnswer((_) async => const Right(_pageTwo));
    final bloc = build()..add(const ReportsSearchRequested(_filters));
    await settle();

    bloc.add(const ReportsPageRequested(2));
    await settle();

    expect(bloc.state, const ReportsListLoaded(_pageTwo, _filters));
  });

  test('a page request before any search is a no-op', () async {
    final bloc = build()..add(const ReportsPageRequested(2));
    await settle();

    expect(bloc.state, const ReportsListInitial());
    verifyNever(() => repository.search(any(), any(), any()));
  });

  test('a failed search (e.g. 422 on a bad filter, decision 83) is an error state '
      'that keeps the filters for retry', () async {
    const failure = Failure(message: 'bad', statusCode: 422, code: 'VALIDATION_FAILED');
    when(() => repository.search(_filters, 1, 20)).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const ReportsSearchRequested(_filters));
    await settle();

    expect(bloc.state, const ReportsListError(failure, _filters));
  });

  test('an empty result is a loaded page with no items (the screen shows the empty state)',
      () async {
    when(() => repository.search(const ReportFiltersEntity(), 1, 20))
        .thenAnswer((_) async => const Right(_empty));

    final bloc = build()..add(const ReportsSearchRequested(ReportFiltersEntity()));
    await settle();

    expect((bloc.state as ReportsListLoaded).page.items, isEmpty);
  });
}
