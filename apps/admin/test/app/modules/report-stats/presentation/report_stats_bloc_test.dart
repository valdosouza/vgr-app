import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/report-stats/domain/entity/report_stats_entities.dart';
import 'package:vgr_admin/app/modules/report-stats/domain/repository/report_stats_repository.dart';
import 'package:vgr_admin/app/modules/report-stats/presentation/bloc/report_stats_bloc.dart';
import 'package:vgr_admin/app/modules/report-stats/presentation/bloc/report_stats_event.dart';
import 'package:vgr_admin/app/modules/report-stats/presentation/bloc/report_stats_state.dart';

class MockReportStatsRepository extends Mock implements ReportStatsRepository {}

const _defaults = ReportStatsQueryEntity();
const _week = ReportStatsQueryEntity(from: '2026-08-01', to: '2026-09-01', granularity: 'week');

ReportStatsEntity stats(String granularity) => ReportStatsEntity(
      range: StatsRangeEntity(from: 'a', to: 'b', granularity: granularity),
      totals: StatsTotalsEntity.fromJson(const {
        'reports': 12, 'open': 7, 'resolved': 5, 'anonymous': 8, 'identified': '<5',
        'frozen': 0, 'hidden': 0, 'expired': 0, 'purged': 0, 'withMedia': 6,
      }),
      byPeriod: const [],
      byCategory: const [],
      bySubject: const [],
      byStatus: const [],
      byTier: const [],
      moderation: const ModerationStatsEntity(hiddenByReason: [], blockedMediaByReason: []),
    );

/// B4 (decision 164): one read, filters → re-read. Nothing is audited (165)
/// and nothing is cached — the screen shows what the server just summed.
void main() {
  late MockReportStatsRepository repository;

  setUp(() {
    repository = MockReportStatsRepository();
    registerFallbackValue(_defaults);
  });

  ReportStatsBloc build() => ReportStatsBloc(repository);

  test('starts idle; the page dispatches the default load on entry', () {
    expect(build().state, const ReportStatsInitial());
    verifyNever(() => repository.getStats(any()));
  });

  test('a request emits loading then loaded with the same query', () async {
    final loaded = stats('day');
    when(() => repository.getStats(_defaults)).thenAnswer((_) async => Right(loaded));

    final bloc = build();
    expect(
      bloc.stream,
      emitsInOrder([
        const ReportStatsLoading(_defaults),
        ReportStatsLoaded(loaded, _defaults),
      ]),
    );

    bloc.add(const ReportStatsRequested(_defaults));
  });

  test('Apply with new values re-reads under those values', () async {
    when(() => repository.getStats(_defaults)).thenAnswer((_) async => Right(stats('day')));
    when(() => repository.getStats(_week)).thenAnswer((_) async => Right(stats('week')));
    final bloc = build()..add(const ReportStatsRequested(_defaults));
    await Future<void>.delayed(Duration.zero);

    bloc.add(const ReportStatsRequested(_week));
    await Future<void>.delayed(Duration.zero);

    final state = bloc.state as ReportStatsLoaded;
    expect(state.query, _week);
    expect(state.stats.range.granularity, 'week');
    verify(() => repository.getStats(_week)).called(1);
  });

  test('a refusal (422 range too long, 403 no grant) is an error state keeping the query',
      () async {
    const failure = Failure(message: 'too long', statusCode: 422, code: 'VALIDATION_FAILED');
    when(() => repository.getStats(_week)).thenAnswer((_) async => const Left(failure));

    final bloc = build()..add(const ReportStatsRequested(_week));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state, const ReportStatsError(failure, _week));
  });
}
