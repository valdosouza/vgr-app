import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/report-stats/domain/entity/report_stats_entities.dart';
import 'package:vgr_admin/app/modules/report-stats/domain/repository/report_stats_repository.dart';
import 'package:vgr_admin/app/modules/report-stats/presentation/bloc/report_stats_bloc.dart';
import 'package:vgr_admin/app/modules/report-stats/presentation/page/report_stats_page.dart';

import '../../../../helpers/pump_localized.dart';
import '../../../../helpers/session_access.dart';

class MockReportStatsRepository extends Mock implements ReportStatsRepository {}

ReportStatsEntity stats({bool empty = false}) => ReportStatsEntity.fromJson({
      'range': {
        'from': '2026-08-03T00:00:00.000Z',
        'to': '2026-09-02T12:00:00.000Z',
        'granularity': 'day',
      },
      'totals': empty
          ? {
              'reports': 0, 'open': 0, 'resolved': 0, 'anonymous': 0, 'identified': 0,
              'frozen': 0, 'hidden': 0, 'expired': 0, 'purged': 0, 'withMedia': 0,
            }
          : {
              'reports': 12, 'open': 7, 'resolved': 5, 'anonymous': 8, 'identified': '<5',
              'frozen': 0, 'hidden': '<5', 'expired': 0, 'purged': 0, 'withMedia': 6,
            },
      'byPeriod': empty ? [] : [
        {'period': '2026-08-30', 'reports': 5},
        {'period': '2026-09-01', 'reports': '<5'},
      ],
      'byCategory': empty ? [] : [
        {'category': 'assault', 'tier': 'high', 'reports': 9},
        {'category': null, 'tier': 'low', 'reports': '<5'},
      ],
      'bySubject': empty ? [] : [
        {'subject': 'child', 'reports': 6},
      ],
      'byStatus': empty ? [] : [
        {'status': 'open', 'reports': 7},
        {'status': 'resolved', 'reports': 5},
      ],
      'byTier': empty ? [] : [
        {'tier': 'high', 'reports': 9},
        {'tier': 'low', 'reports': '<5'},
      ],
      'moderation': {
        'hiddenByReason': empty ? [] : [
          {'reasonCode': 'spam', 'reports': '<5'},
        ],
        'blockedMediaByReason': empty ? [] : [
          {'reasonCode': 'illegal_content', 'media': 5},
        ],
      },
    });

/// B4 (decisions 164/165): counters and tables only — no ids, no
/// positions, no chart library, "<5" rendered as served.
void main() {
  late MockReportStatsRepository repository;

  setUp(() {
    grantAllPrivileges();
    repository = MockReportStatsRepository();
    registerFallbackValue(const ReportStatsQueryEntity());
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await pumpLocalized(
      tester,
      BlocProvider(
        create: (_) => ReportStatsBloc(repository),
        child: const ReportStatsPage(),
      ),
    );
  }

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('report-stats-apply')));
    await tester.pumpAndSettle();
  }

  testWidgets('loads with the API defaults on entry — no filter sent', (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => Right(stats()));

    await pumpPage(tester);

    verify(() => repository.getStats(const ReportStatsQueryEntity())).called(1);
  });

  testWidgets('renders the totals as tiles, "<5" as served, and the floor note (164)',
      (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => Right(stats()));

    await pumpPage(tester);

    expect(find.byKey(const Key('report-stats-total-reports')), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('report-stats-total-reports')),
      matching: find.text('12'),
    ), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('report-stats-total-identified')),
      matching: find.text('<5'),
    ), findsOneWidget);
    expect(find.byKey(const Key('report-stats-floor-note')), findsOneWidget);
    expect(find.textContaining('fewer than 5'), findsOneWidget);
    expect(find.byKey(const Key('report-stats-empty')), findsNothing);
  });

  testWidgets('one section per grouping: taxonomy and reasons translated, free tag named',
      (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => Right(stats()));

    await pumpPage(tester);

    // Period rows keep the raw key (already human: YYYY-MM-DD / YYYY-Www / YYYY-MM).
    expect(find.byKey(const Key('report-stats-period-2026-08-30')), findsOneWidget);
    // Category null = free-tag reports (contract) — labelled, never blank.
    expect(find.byKey(const Key('report-stats-category-free_tag')), findsOneWidget);
    expect(find.text('Free tag · Low'), findsOneWidget);
    expect(find.text('Assault · High'), findsOneWidget);
    expect(find.byKey(const Key('report-stats-subject-child')), findsOneWidget);
    expect(find.byKey(const Key('report-stats-status-resolved')), findsOneWidget);
    expect(find.byKey(const Key('report-stats-tier-high')), findsOneWidget);
    // Moderation reasons via the existing reports.moderation.reason.<code> keys.
    expect(find.byKey(const Key('report-stats-hidden-reason-spam')), findsOneWidget);
    expect(find.text('Spam'), findsOneWidget);
    expect(find.byKey(const Key('report-stats-blocked-reason-illegal_content')), findsOneWidget);
    expect(find.text('Illegal content'), findsOneWidget);
  });

  testWidgets('a malformed date never leaves the screen (vgr_validators, decision 157)',
      (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => Right(stats()));
    await pumpPage(tester);
    clearInteractions(repository);

    await tester.enterText(find.byKey(const Key('report-stats-from')), '02/09/2026');
    await apply(tester);

    expect(find.text('Invalid format.'), findsOneWidget);
    verifyNever(() => repository.getStats(any()));
  });

  testWidgets('Apply re-reads with the form values (from/to/granularity)', (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => Right(stats()));
    await pumpPage(tester);
    clearInteractions(repository);

    await tester.enterText(find.byKey(const Key('report-stats-from')), '2026-08-01');
    await tester.enterText(find.byKey(const Key('report-stats-to')), '2026-09-01');
    await tester.tap(find.byKey(const Key('report-stats-granularity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week').last);
    await tester.pumpAndSettle();
    await apply(tester);

    final query = verify(() => repository.getStats(captureAny())).captured.single
        as ReportStatsQueryEntity;
    expect(query, const ReportStatsQueryEntity(
      from: '2026-08-01',
      to: '2026-09-01',
      granularity: 'week',
    ));
  });

  testWidgets('every total 0 → empty state, no tables', (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => Right(stats(empty: true)));

    await pumpPage(tester);

    expect(find.byKey(const Key('report-stats-empty')), findsOneWidget);
    expect(find.text('No reports in this range.'), findsOneWidget);
    expect(find.byKey(const Key('report-stats-total-reports')), findsNothing);
  });

  testWidgets('a server refusal renders translated by code (decisions 80/83)', (tester) async {
    when(() => repository.getStats(any())).thenAnswer((_) async => const Left(
        Failure(message: 'no', statusCode: 403, code: 'FORBIDDEN')));

    await pumpPage(tester);

    expect(find.byKey(const Key('report-stats-error')), findsOneWidget);
    expect(find.text('You do not have permission for this action.'), findsOneWidget);
  });
}
