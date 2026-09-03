import 'package:core/core.dart';
import 'package:dartz/dartz.dart' hide Bind;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/entity/admin_audit_entities.dart';
import 'package:vgr_admin/app/modules/admin-audit/domain/repository/admin_audit_repository.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_detail_bloc.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_detail_event.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/bloc/admin_audit_list_bloc.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/page/admin_audit_detail_page.dart';
import 'package:vgr_admin/app/modules/admin-audit/presentation/page/admin_audit_list_page.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockAdminAuditRepository extends Mock implements AdminAuditRepository {}

AuditListItemEntity item(int id, {Object? summary = const {'name': 'Ana'}, String? actorName = 'Ana'}) =>
    AuditListItemEntity(
      id: id,
      actorId: 4,
      actorName: actorName,
      action: 'update',
      entity: 'user',
      entityId: '12',
      summary: summary,
      createdAt: '2026-09-02T10:00:00.000Z',
    );

const _facets = AuditFacetsEntity(
  actions: ['grant', 'update'],
  entities: ['user', 'user_privileges'],
);
const _none = AuditFiltersEntity();
const _empty = AuditPageEntity(items: [], page: 1, pageSize: 50, total: 0);

AuditPageEntity pageOf(List<AuditListItemEntity> items, {int page = 1, int total = -1}) =>
    AuditPageEntity(items: items, page: page, pageSize: 50, total: total < 0 ? items.length : total);

void main() {
  late MockAdminAuditRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockAdminAuditRepository();
    registerFallbackValue(_none);
    when(() => repository.facets()).thenAnswer((_) async => const Right(_facets));
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => AdminAuditListBloc(repository),
        child: const AdminAuditListPage(),
      ),
    );
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('audit-apply')));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String fieldKey, String label) async {
    await tester.tap(find.byKey(Key(fieldKey)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('facets and the first page load on entry; rows show who · what · when, target '
      'and a summary preview — never an ip', (tester) async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => Right(pageOf([
          item(1),
          item(2, summary: 'raw text', actorName: null),
        ])));
    await pumpPage(tester);

    verify(() => repository.list(_none, 1, 50)).called(1);
    verify(() => repository.facets()).called(1);
    expect(find.byKey(const Key('audit-row-1')), findsOneWidget);
    expect(find.text('2026-09-02 10:00 · Ana (#4) · Update'), findsOneWidget);
    expect(find.text('user#12 · {"name":"Ana"}'), findsOneWidget);
    expect(find.text('2026-09-02 10:00 · Unknown user (#4) · Update'), findsOneWidget);
    expect(find.text('user#12 · raw text'), findsOneWidget);
    expect(find.textContaining('IP'), findsNothing);
  });

  testWidgets('facets fill the action and entity dropdowns; Apply sends every filter',
      (tester) async {
    when(() => repository.list(any(), 1, 50)).thenAnswer((_) async => const Right(_empty));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('audit-filter-actor-id')), '4');
    await pick(tester, 'audit-filter-action', 'Grant');
    await pick(tester, 'audit-filter-entity', 'user_privileges');
    await tester.enterText(find.byKey(const Key('audit-filter-entity-id')), '12');
    await tester.enterText(find.byKey(const Key('audit-filter-from')), '2026-09-01');
    await tester.enterText(find.byKey(const Key('audit-filter-to')), '2026-09-02');
    await apply(tester);

    final filters = verify(() => repository.list(captureAny(), 1, 50)).captured.last
        as AuditFiltersEntity;
    expect(
      filters,
      const AuditFiltersEntity(
        actorId: 4,
        action: 'grant',
        entity: 'user_privileges',
        entityId: '12',
        from: '2026-09-01',
        to: '2026-09-02',
      ),
    );
  });

  testWidgets('a malformed date never leaves the screen (vgr_validators, decision 157)',
      (tester) async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Right(_empty));
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('audit-filter-from')), '02/09/2026');
    await apply(tester);

    expect(find.text('Invalid format.'), findsOneWidget);
    // Only the entry load happened.
    verify(() => repository.list(any(), any(), any())).called(1);
  });

  testWidgets('pagination: page X of Y, prev disabled on the first page, next asks page 2',
      (tester) async {
    when(() => repository.list(_none, 1, 50))
        .thenAnswer((_) async => Right(pageOf([item(1)], total: 120)));
    when(() => repository.list(_none, 2, 50))
        .thenAnswer((_) async => Right(pageOf([item(51)], page: 2, total: 120)));
    await pumpPage(tester);

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(tester.widget<VgrSecondaryButton>(find.byKey(const Key('audit-prev'))).onPressed,
        isNull);

    await tester.tap(find.byKey(const Key('audit-next')));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('audit-row-51')), findsOneWidget);
  });

  testWidgets('empty result renders the empty state', (tester) async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => const Right(_empty));
    await pumpPage(tester);

    expect(find.byKey(const Key('audit-empty')), findsOneWidget);
    expect(find.text('No audit entries match the filters.'), findsOneWidget);
  });

  testWidgets('a server refusal renders translated by code (decisions 80/83)', (tester) async {
    when(() => repository.list(_none, 1, 50)).thenAnswer((_) async =>
        const Left(Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN')));
    await pumpPage(tester);

    expect(find.byKey(const Key('audit-list-error')), findsOneWidget);
    expect(find.text('You do not have permission for this action.'), findsOneWidget);
  });

  group('navigation', () {
    tearDown(Modular.destroy);

    /// flutter_modular 5 debounces `navigate` by 500 ms of WALL-CLOCK time
    /// on the test's FAKE clock — `pump(600 ms)` elapses it.
    Future<void> navigateTo(WidgetTester tester, String path) async {
      Modular.to.navigate(path);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a row pushes /admin-audit/:id; the detail\'s Back returns to the list',
        (tester) async {
      when(() => repository.list(_none, 1, 50)).thenAnswer((_) async => Right(pageOf([item(7)])));
      when(() => repository.get(7)).thenAnswer((_) async => const Right(AuditEntryEntity(
            id: 7,
            actorId: 4,
            actorName: 'Ana',
            action: 'update',
            entity: 'user',
            entityId: '12',
            summary: null,
            createdAt: '2026-09-02T10:00:00.000Z',
            ip: '10.0.0.1',
          )));

      await pumpLocalizedApp(
        tester,
        ModularApp(module: _TestModule(repository), child: const _TestApp()),
      );
      await navigateTo(tester, '/admin-audit/');

      await tester.tap(find.byKey(const Key('audit-row-7')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audit-detail-7')), findsOneWidget);
      expect(find.text('10.0.0.1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('audit-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audit-row-7')), findsOneWidget);
      expect(find.byKey(const Key('audit-detail-7')), findsNothing);
    });
  });
}

/// Mirrors production: `ModuleRoute('/admin-audit', ...)` with `/` and `/:id`.
class _TestModule extends Module {
  _TestModule(this.repository);

  final AdminAuditRepository repository;

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, __) => const Scaffold()),
        ModuleRoute('/admin-audit', module: _AuditRoutes(repository)),
      ];
}

class _AuditRoutes extends Module {
  _AuditRoutes(this.repository);

  final AdminAuditRepository repository;

  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => BlocProvider(
            create: (_) => AdminAuditListBloc(repository),
            child: const AdminAuditListPage(),
          ),
        ),
        ChildRoute(
          '/:id',
          child: (_, args) {
            final id = int.parse(args.params['id'] as String);
            return BlocProvider(
              create: (_) => AdminAuditDetailBloc(repository)..add(AdminAuditDetailRequested(id)),
              child: AdminAuditDetailPage(entryId: id, autoload: false),
            );
          },
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
