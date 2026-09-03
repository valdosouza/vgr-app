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
import 'package:vgr_admin/app/modules/reports/presentation/bloc/reports_queue_bloc.dart';
import 'package:vgr_admin/app/modules/reports/presentation/page/reports_queue_page.dart';
import 'package:vgr_admin/app/modules/reports/reports_module.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockReportsRepository extends Mock implements ReportsRepository {}

class MockApiClient extends Mock implements ApiClient {}

QueueItemEntity item(
  int id, {
  String priority = 'high',
  bool hasMedia = true,
  int ageHours = 12,
  bool frozen = false,
  String? category = 'assault',
}) =>
    QueueItemEntity(
      item: ReportListItemEntity(
        reportId: id,
        category: category,
        freeTag: category == null ? 'noise' : null,
        subject: 'child',
        tier: priority,
        status: 'open',
        anonymous: true,
        frozen: frozen,
        purged: false,
        mediaCount: hasMedia ? 2 : 0,
        position: null,
        createdAt: '2026-09-01T10:00:00.000Z',
        resolvedAt: null,
      ),
      priority: priority,
      hasMedia: hasMedia,
      ageHours: ageHours,
    );

const _empty = QueuePageEntity(items: [], page: 1, pageSize: 20, total: 0);

/// B3 (decision 161): the proactive moderation queue screen.
void main() {
  late MockReportsRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockReportsRepository();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ReportsQueueBloc(repository),
        child: const ReportsQueuePage(),
      ),
    );
  }

  testWidgets('loads on entry: header with the total, one row per case with the translated '
      'priority, taxonomy, subject, media marker, age in hours/days and the frozen marker',
      (tester) async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => Right(QueuePageEntity(
          items: [
            item(7, priority: 'high', hasMedia: true, ageHours: 12, frozen: true),
            item(3, priority: 'low', hasMedia: false, ageHours: 80, category: null),
          ],
          page: 1,
          pageSize: 20,
          total: 2,
        )));
    await pumpPage(tester);

    expect(find.text('2 cases awaiting review'), findsOneWidget);
    expect(find.byKey(const Key('queue-row-7')), findsOneWidget);
    expect(find.byKey(const Key('queue-row-3')), findsOneWidget);
    expect(find.textContaining('HIGH · #7 · Assault · Child'), findsOneWidget);
    expect(find.textContaining('LOW · #3 · noise · Child'), findsOneWidget);
    expect(find.textContaining('12 h'), findsOneWidget);
    expect(find.textContaining('3 d'), findsOneWidget);
    expect(find.textContaining('With media'), findsOneWidget);
    expect(find.textContaining('FROZEN'), findsOneWidget);
    verify(() => repository.queue(1, 20)).called(1);
  });

  testWidgets('empty queue renders the empty state', (tester) async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => const Right(_empty));
    await pumpPage(tester);

    expect(find.byKey(const Key('queue-empty')), findsOneWidget);
    expect(find.text('Queue is empty.'), findsOneWidget);
  });

  testWidgets('"Mark reviewed" calls the repository and the queue is re-fetched', (tester) async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async =>
        Right(QueuePageEntity(items: [item(7), item(8)], page: 1, pageSize: 20, total: 2)));
    await pumpPage(tester);

    when(() => repository.markReviewed(7)).thenAnswer((_) async => const Right(null));
    when(() => repository.queue(1, 20)).thenAnswer((_) async =>
        Right(QueuePageEntity(items: [item(8)], page: 1, pageSize: 20, total: 1)));

    await tester.tap(find.byKey(const Key('queue-review-7')));
    await tester.pumpAndSettle();

    verify(() => repository.markReviewed(7)).called(1);
    verify(() => repository.queue(1, 20)).called(2);
    expect(find.byKey(const Key('queue-row-7')), findsNothing);
    expect(find.byKey(const Key('queue-row-8')), findsOneWidget);
    expect(find.text('1 case awaiting review'), findsOneWidget);
  });

  testWidgets('without reports UPDATE the "Mark reviewed" button renders disabled (72/165)',
      (tester) async {
    SessionAccess.instance.applyPermissions(const {
      'reports': [Privileges.view],
    });
    when(() => repository.queue(1, 20)).thenAnswer((_) async =>
        Right(QueuePageEntity(items: [item(7)], page: 1, pageSize: 20, total: 1)));
    await pumpPage(tester);

    expect(
        tester.widget<VgrSecondaryButton>(find.byKey(const Key('queue-review-7'))).onPressed,
        isNull);
  });

  testWidgets('a refused mark (409 already reviewed) renders by code, queue kept', (tester) async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async =>
        Right(QueuePageEntity(items: [item(7)], page: 1, pageSize: 20, total: 1)));
    when(() => repository.markReviewed(7)).thenAnswer((_) async => const Left(
        Failure(message: 'already', statusCode: 409, code: 'DUPLICATE')));
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('queue-review-7')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('queue-action-error')), findsOneWidget);
    expect(find.text('This value already exists.'), findsOneWidget);
    expect(find.byKey(const Key('queue-row-7')), findsOneWidget);
  });

  testWidgets('pagination: page X of Y, prev disabled on the first page, next asks page 2',
      (tester) async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async =>
        Right(QueuePageEntity(items: [item(7)], page: 1, pageSize: 20, total: 45)));
    when(() => repository.queue(2, 20)).thenAnswer((_) async =>
        Right(QueuePageEntity(items: [item(8)], page: 2, pageSize: 20, total: 45)));
    await pumpPage(tester);

    expect(find.text('Page 1 of 3'), findsOneWidget);
    expect(tester.widget<VgrSecondaryButton>(find.byKey(const Key('queue-prev'))).onPressed,
        isNull);

    await tester.tap(find.byKey(const Key('queue-next')));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.byKey(const Key('queue-row-8')), findsOneWidget);
    verify(() => repository.queue(2, 20)).called(1);
  });

  testWidgets('a server refusal on load renders translated by code (80/83)', (tester) async {
    when(() => repository.queue(1, 20)).thenAnswer((_) async => const Left(
        Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN')));
    await pumpPage(tester);

    expect(find.byKey(const Key('queue-error')), findsOneWidget);
    expect(find.text('You do not have permission for this action.'), findsOneWidget);
  });

  group('routing through the REAL ReportsModule', () {
    late MockApiClient apiClient;

    setUp(() {
      apiClient = MockApiClient();
      registerFallbackValue(<String, dynamic>{});
    });

    tearDown(Modular.destroy);

    Map<String, dynamic> queueJson(List<int> ids) => {
          'items': [
            for (final id in ids)
              {
                'reportId': id,
                'category': 'assault',
                'freeTag': null,
                'subject': 'child',
                'tier': 'high',
                'status': 'open',
                'anonymous': true,
                'frozen': false,
                'purged': false,
                'hidden': false,
                'reviewed': false,
                'mediaCount': 1,
                'position': null,
                'createdAt': '2026-09-01T10:00:00.000Z',
                'resolvedAt': null,
                'priority': 'high',
                'hasMedia': true,
                'ageHours': 5,
              },
          ],
          'page': 1,
          'pageSize': 20,
          'total': ids.length,
        };

    Future<void> pumpApp(WidgetTester tester) async {
      await pumpLocalizedApp(
        tester,
        ModularApp(module: _RootModule(apiClient), child: const _TestApp()),
      );
      // The guard passes on an admin session (core's AdminSessionGuard).
      Modular.get<IdentityBloc>().add(const ProviderLoginCompleted(
        role: Role.admin,
        anonymityMode: AnonymityMode.anonymous,
        token: 'jwt',
      ));
      await tester.pump();
    }

    /// flutter_modular 5 debounces `navigate` by 500 ms of WALL-CLOCK time
    /// through a `Future.delayed` on the test's FAKE clock: a second
    /// ModularApp in the same file is created fast enough to hit it, and
    /// `pumpAndSettle` alone never elapses that delay.
    Future<void> navigateTo(WidgetTester tester, String path) async {
      Modular.to.navigate(path);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    }

    testWidgets('/reports/queue opens the queue page — the literal segment is registered '
        'BEFORE /:id so it never parses as a case id', (tester) async {
      when(() => apiClient.get(any())).thenAnswer((_) async => queueJson([7]));
      await pumpApp(tester);

      final names = ReportsModule().routes.map((r) => r.name).toList();
      expect(names.indexOf('/queue'), lessThan(names.indexOf('/:id')));

      await navigateTo(tester, '/reports/queue');

      expect(find.text('Moderation queue'), findsOneWidget);
      expect(find.byKey(const Key('queue-row-7')), findsOneWidget);
      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(Uri.parse(path).path, '/api/reports/queue');
    });

    testWidgets('tapping a queue row pushes /reports/:id (the audited detail, 166)',
        (tester) async {
      when(() => apiClient.get(any())).thenAnswer((invocation) async {
        final path = invocation.positionalArguments.first as String;
        if (path.startsWith('/api/reports/queue')) return queueJson([7]);
        if (path == '/api/case-freeze/7') {
          throw const Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN');
        }
        return {
          'reportId': 7, 'category': 'assault', 'freeTag': null, 'subject': 'child',
          'tier': 'high', 'status': 'open', 'anonymous': true, 'frozen': false,
          'frozenReason': null, 'frozenAt': null, 'purged': false,
          'createdAt': '2026-09-01T10:00:00.000Z', 'resolvedAt': null, 'expiresAt': null,
          'reporter': null, 'position': null, 'detailFields': null, 'timeline': [],
          'media': [], 'offers': [],
        };
      });
      await pumpApp(tester);

      await navigateTo(tester, '/reports/queue');
      await tester.tap(find.byKey(const Key('queue-row-7')));
      await tester.pumpAndSettle();

      expect(find.text('Case #7'), findsOneWidget);
      verify(() => apiClient.get('/api/reports/7')).called(1);
    });
  });
}

/// Mirrors `AppModule`: binds what the guards and the repository need, and
/// mounts the PRODUCTION `ReportsModule` at `/reports`.
class _RootModule extends Module {
  _RootModule(this.apiClient);

  final ApiClient apiClient;

  @override
  List<Bind> get binds => [
        Bind.singleton((i) => IdentityBloc()),
        Bind.factory<ApiClient>((i) => apiClient),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (_, __) => const Scaffold()),
        ModuleRoute('/reports', module: ReportsModule()),
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
