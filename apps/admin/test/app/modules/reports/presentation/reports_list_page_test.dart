import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/reports/domain/entity/report_entities.dart';
import 'package:vgr_admin/app/modules/reports/domain/repository/reports_repository.dart';
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_list_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/page/reports_list_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

ReportListItemEntity item(int id, {bool frozen = false, bool purged = false}) =>
    ReportListItemEntity(
      reportId: id,
      category: purged ? null : 'assault',
      freeTag: purged ? 'noise' : null,
      subject: 'child',
      tier: 'high',
      status: 'open',
      anonymous: true,
      frozen: frozen,
      purged: purged,
      mediaCount: 2,
      position: purged ? null : const ReportPositionEntity(lat: -23.55, lng: -46.63),
      createdAt: '2026-09-01T10:00:00.000Z',
      resolvedAt: null,
    );

const _empty = ReportPageEntity(items: [], page: 1, pageSize: 20, total: 0);

void main() {
  late MockReportsRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockReportsRepository();
    registerFallbackValue(const ReportFiltersEntity());
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ReportsListBloc(repository),
        child: const ReportsListPage(),
      ),
    );
  }

  Future<void> search(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('reports-search-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is fetched before the operator searches', (tester) async {
    await pumpPage(tester);

    expect(find.byKey(const Key('reports-search-button')), findsOneWidget);
    expect(find.byKey(const Key('reports-empty')), findsNothing);
    verifyNever(() => repository.search(any(), any(), any()));
  });

  testWidgets('filters travel to the search call and rows render (id + status)', (tester) async {
    when(() => repository.search(any(), 1, 20)).thenAnswer((_) async => Right(
        ReportPageEntity(items: [item(7, frozen: true), item(3, purged: true)], page: 1, pageSize: 20, total: 2)));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('reports-filter-id')), '7');
    await tester.tap(find.byKey(const Key('reports-filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();
    await search(tester);

    final filters = verify(() => repository.search(captureAny(), 1, 20)).captured.single
        as ReportFiltersEntity;
    expect(filters, const ReportFiltersEntity(id: 7, status: 'open'));
    expect(find.byKey(const Key('report-row-7')), findsOneWidget);
    expect(find.byKey(const Key('report-row-3')), findsOneWidget);
    expect(find.textContaining('FROZEN'), findsOneWidget);
    expect(find.textContaining('PURGED'), findsOneWidget);
    expect(find.textContaining('#7 · Assault · Child'), findsOneWidget);
    expect(find.textContaining('#3 · noise · Child'), findsOneWidget);
  });

  testWidgets('empty result renders the empty state', (tester) async {
    when(() => repository.search(any(), 1, 20)).thenAnswer((_) async => const Right(_empty));
    await pumpPage(tester);

    await search(tester);

    expect(find.byKey(const Key('reports-empty')), findsOneWidget);
    expect(find.text('No reports match the filters.'), findsOneWidget);
  });

  testWidgets('pagination: page X of Y, prev disabled on the first page, next asks page 2',
      (tester) async {
    when(() => repository.search(any(), 1, 20)).thenAnswer((_) async =>
        Right(ReportPageEntity(items: [item(7)], page: 1, pageSize: 20, total: 45)));
    when(() => repository.search(any(), 2, 20)).thenAnswer((_) async =>
        Right(ReportPageEntity(items: [item(8)], page: 2, pageSize: 20, total: 45)));
    await pumpPage(tester);
    await search(tester);

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(tester.widget<VgrSecondaryButton>(find.byKey(const Key('reports-prev'))).onPressed,
        isNull);

    await tester.tap(find.byKey(const Key('reports-next')));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('report-row-8')), findsOneWidget);
    verify(() => repository.search(any(), 2, 20)).called(1);
  });

  testWidgets('a malformed date never leaves the screen (vgr_validators, decision 157)',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('reports-filter-from')), '02/09/2026');
    await search(tester);

    expect(find.text('Invalid format.'), findsOneWidget);
    verifyNever(() => repository.search(any(), any(), any()));
  });

  testWidgets('a server refusal renders translated by code (decisions 80/83)', (tester) async {
    when(() => repository.search(any(), 1, 20)).thenAnswer((_) async => const Left(
        Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN')));
    await pumpPage(tester);

    await search(tester);

    expect(find.byKey(const Key('reports-list-error')), findsOneWidget);
    expect(find.text('You do not have permission for this action.'), findsOneWidget);
  });

  group('navigation', () {
    tearDown(Modular.destroy);

    testWidgets('tapping a row pushes /reports/:id', (tester) async {
      when(() => repository.search(any(), 1, 20)).thenAnswer((_) async =>
          Right(ReportPageEntity(items: [item(7)], page: 1, pageSize: 20, total: 1)));

      await pumpLocalizedApp(
        tester,
        ModularApp(module: _TestModule(repository), child: const _TestApp()),
      );
      Modular.to.navigate('/reports/');
      await tester.pumpAndSettle();
      await search(tester);

      await tester.tap(find.byKey(const Key('report-row-7')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail-stub-7')), findsOneWidget);
    });
  });
}

/// Mirrors production: `ModuleRoute('/reports', ...)` with `/` and `/:id`.
class _TestModule extends Module {
  _TestModule(this.repository);

  final ReportsRepository repository;

  @override
  List<ModularRoute> get routes => [
        // The router boots at '/'; a blank home keeps the test honest.
        ChildRoute('/', child: (_, __) => const Scaffold()),
        ModuleRoute('/reports', module: _ReportsRoutes(repository)),
      ];
}

class _ReportsRoutes extends Module {
  _ReportsRoutes(this.repository);

  final ReportsRepository repository;

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => ReportsListBloc(repository),
            child: const ReportsListPage(),
          ),
        ),
        ChildRoute(
          '/:id',
          child: (_, args) =>
              Scaffold(body: Text('stub', key: Key('detail-stub-${args.params['id']}'))),
        ),
      ];
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        routeInformationParser: Modular.routeInformationParser,
        routerDelegate: Modular.routerDelegate,
      );
}
