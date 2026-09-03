import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vgr_admin/app/modules/report-stats/data/report_stats_repository_impl.dart';
import 'package:vgr_admin/app/modules/report-stats/domain/entity/report_stats_entities.dart';

class MockApiClient extends Mock implements ApiClient {}

/// B4 (decisions 164/165): aggregates only, every count `number | "<5"`.
Map<String, dynamic> payload({Object reports = 12, Object hidden = '<5'}) => {
      'range': {
        'from': '2026-08-03T00:00:00.000Z',
        'to': '2026-09-02T12:00:00.000Z',
        'granularity': 'day',
      },
      'totals': {
        'reports': reports,
        'open': 7,
        'resolved': 5,
        'anonymous': 8,
        'identified': '<5',
        'frozen': 0,
        'hidden': hidden,
        'expired': 0,
        'purged': '<5',
        'withMedia': 6,
      },
      'byPeriod': [
        {'period': '2026-08-30', 'reports': 5},
        {'period': '2026-09-01', 'reports': '<5'},
      ],
      'byCategory': [
        {'category': 'assault', 'tier': 'high', 'reports': 9},
        {'category': null, 'tier': 'low', 'reports': '<5'},
      ],
      'bySubject': [
        {'subject': 'child', 'reports': 6},
      ],
      'byStatus': [
        {'status': 'open', 'reports': 7},
        {'status': 'resolved', 'reports': 5},
      ],
      'byTier': [
        {'tier': 'high', 'reports': 9},
        {'tier': 'low', 'reports': '<5'},
      ],
      'moderation': {
        'hiddenByReason': [
          {'reasonCode': 'spam', 'reports': '<5'},
        ],
        'blockedMediaByReason': [
          {'reasonCode': 'illegal_content', 'media': 5},
        ],
      },
    };

void main() {
  late MockApiClient apiClient;
  late ReportStatsRepositoryImpl repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ReportStatsRepositoryImpl(apiClient);
  });

  group('getStats — query string', () {
    test('defaults send no parameter — the API applies its own (to = now, from = to − 30 d)',
        () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => payload());

      await repository.getStats(const ReportStatsQueryEntity());

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      final uri = Uri.parse(path);
      expect(uri.path, '/api/reports/stats');
      expect(uri.queryParameters, isEmpty);
    });

    test('from / to / granularity travel under the contract names', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => payload());

      await repository.getStats(const ReportStatsQueryEntity(
        from: '2026-01-01',
        to: '2026-09-02',
        granularity: 'week',
      ));

      final path = verify(() => apiClient.get(captureAny())).captured.single as String;
      expect(Uri.parse(path).queryParameters, {
        'from': '2026-01-01',
        'to': '2026-09-02',
        'granularity': 'week',
      });
    });
  });

  group('getStats — mapping (164)', () {
    test('numbers and "<5" land in StatCount across every group', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => payload());

      final result = await repository.getStats(const ReportStatsQueryEntity());

      final stats = result.getOrElse(() => throw StateError('left'));
      expect(stats.range.granularity, 'day');
      expect(stats.range.from, '2026-08-03T00:00:00.000Z');
      expect(stats.totals.reports, const StatCount(value: 12));
      expect(stats.totals.identified, const StatCount.belowFloor());
      expect(stats.totals.frozen, const StatCount(value: 0));
      expect(stats.byPeriod.map((e) => e.period), ['2026-08-30', '2026-09-01']);
      expect(stats.byPeriod.last.reports.belowFloor, isTrue);
      expect(stats.bySubject.single.key, 'child');
      expect(stats.byStatus.map((e) => e.key), ['open', 'resolved']);
      expect(stats.byTier.last.reports, const StatCount.belowFloor());
      expect(stats.moderation.hiddenByReason.single.key, 'spam');
      expect(stats.moderation.hiddenByReason.single.reports.belowFloor, isTrue);
      expect(stats.moderation.blockedMediaByReason.single.key, 'illegal_content');
      expect(stats.moderation.blockedMediaByReason.single.reports, const StatCount(value: 5));
    });

    test('a null category is the free-tag bucket, tier kept', () async {
      when(() => apiClient.get(any())).thenAnswer((_) async => payload());

      final result = await repository.getStats(const ReportStatsQueryEntity());

      final stats = result.getOrElse(() => throw StateError('left'));
      expect(stats.byCategory.first.category, 'assault');
      expect(stats.byCategory.first.tier, 'high');
      expect(stats.byCategory.last.category, isNull);
      expect(stats.byCategory.last.tier, 'low');
      expect(stats.byCategory.last.reports.belowFloor, isTrue);
    });

    test('missing groups are empty lists, never a crash', () async {
      final json = payload()
        ..remove('byPeriod')
        ..['moderation'] = <String, dynamic>{};
      when(() => apiClient.get(any())).thenAnswer((_) async => json);

      final result = await repository.getStats(const ReportStatsQueryEntity());

      final stats = result.getOrElse(() => throw StateError('left'));
      expect(stats.byPeriod, isEmpty);
      expect(stats.moderation.hiddenByReason, isEmpty);
      expect(stats.moderation.blockedMediaByReason, isEmpty);
    });

    test('a 422 (bad range, decision 83) surfaces as Left with the code intact', () async {
      when(() => apiClient.get(any())).thenThrow(
          const Failure(message: 'bad', statusCode: 422, code: 'VALIDATION_FAILED'));

      final result = await repository.getStats(const ReportStatsQueryEntity(from: '2027-01-01'));

      expect(result.fold((f) => f.code, (_) => null), 'VALIDATION_FAILED');
    });
  });
}
