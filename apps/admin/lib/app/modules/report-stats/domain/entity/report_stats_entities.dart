import 'package:equatable/equatable.dart';

/// One aggregated count as `GET /api/reports/stats` serves it (B4,
/// decision 164): `number | "<5"`. The k = 5 floor is applied by the API
/// AFTER summing; the panel only carries the union and renders it. A
/// floored cell has no [value] — the screen must never guess one.
class StatCount extends Equatable {
  const StatCount({required int this.value}) : belowFloor = false;

  /// 1..4 reports exist, but the exact figure is withheld (164).
  const StatCount.belowFloor()
      : value = null,
        belowFloor = true;

  final int? value;
  final bool belowFloor;

  /// `0` is a real zero and stays `0`; `"<5"` is the floor marker.
  bool get isZero => value == 0;

  /// The marker the API sends and the label the panel shows for it.
  static const floorMarker = '<5';

  factory StatCount.fromJson(Object? json) {
    if (json == floorMarker) return const StatCount.belowFloor();
    if (json is num) return StatCount(value: json.toInt());
    if (json is String) {
      final parsed = int.tryParse(json);
      if (parsed != null) return StatCount(value: parsed);
    }
    throw FormatException('StatCount: expected number or "<5", got $json');
  }

  /// What the tile/row prints: the number, or the floor marker as served.
  String label() => belowFloor ? floorMarker : '$value';

  @override
  List<Object?> get props => [value, belowFloor];
}

/// `{ from, to, granularity }` echoed by the API after its defaults.
class StatsRangeEntity extends Equatable {
  const StatsRangeEntity({required this.from, required this.to, required this.granularity});

  final String from;
  final String to;

  /// `day | week | month`.
  final String granularity;

  factory StatsRangeEntity.fromJson(Map<String, dynamic> json) => StatsRangeEntity(
        from: json['from'] as String,
        to: json['to'] as String,
        granularity: json['granularity'] as String,
      );

  @override
  List<Object?> get props => [from, to, granularity];
}

/// The ten totals of the contract, each floored independently (164).
class StatsTotalsEntity extends Equatable {
  const StatsTotalsEntity({
    required this.reports,
    required this.open,
    required this.resolved,
    required this.anonymous,
    required this.identified,
    required this.frozen,
    required this.hidden,
    required this.expired,
    required this.purged,
    required this.withMedia,
  });

  final StatCount reports;
  final StatCount open;
  final StatCount resolved;
  final StatCount anonymous;
  final StatCount identified;
  final StatCount frozen;
  final StatCount hidden;
  final StatCount expired;
  final StatCount purged;
  final StatCount withMedia;

  /// Ordered `(key, count)` pairs — the page renders tiles from this and
  /// translates `reportStats.totals.<key>`.
  List<(String, StatCount)> get entries => [
        ('reports', reports),
        ('open', open),
        ('resolved', resolved),
        ('anonymous', anonymous),
        ('identified', identified),
        ('frozen', frozen),
        ('hidden', hidden),
        ('expired', expired),
        ('purged', purged),
        ('withMedia', withMedia),
      ];

  /// Empty state: every total is a real `0`. A `"<5"` anywhere means
  /// reports exist, so it is NOT empty.
  bool get allZero => entries.every((e) => e.$2.isZero);

  factory StatsTotalsEntity.fromJson(Map<String, dynamic> json) => StatsTotalsEntity(
        reports: StatCount.fromJson(json['reports']),
        open: StatCount.fromJson(json['open']),
        resolved: StatCount.fromJson(json['resolved']),
        anonymous: StatCount.fromJson(json['anonymous']),
        identified: StatCount.fromJson(json['identified']),
        frozen: StatCount.fromJson(json['frozen']),
        hidden: StatCount.fromJson(json['hidden']),
        expired: StatCount.fromJson(json['expired']),
        purged: StatCount.fromJson(json['purged']),
        withMedia: StatCount.fromJson(json['withMedia']),
      );

  @override
  List<Object?> get props =>
      [reports, open, resolved, anonymous, identified, frozen, hidden, expired, purged, withMedia];
}

/// `byPeriod` row. The key is `YYYY-MM-DD` | `YYYY-Www` (ISO week) |
/// `YYYY-MM` by granularity; ascending; empty periods omitted by the API.
class PeriodStatEntity extends Equatable {
  const PeriodStatEntity({required this.period, required this.reports});

  final String period;
  final StatCount reports;

  factory PeriodStatEntity.fromJson(Map<String, dynamic> json) => PeriodStatEntity(
        period: json['period'] as String,
        reports: StatCount.fromJson(json['reports']),
      );

  @override
  List<Object?> get props => [period, reports];
}

/// `byCategory` row. `category == null` is the free-tag bucket (its tier
/// is `getRiskTier(null)` on the API side).
class CategoryStatEntity extends Equatable {
  const CategoryStatEntity({required this.category, required this.tier, required this.reports});

  final String? category;
  final String tier;
  final StatCount reports;

  factory CategoryStatEntity.fromJson(Map<String, dynamic> json) => CategoryStatEntity(
        category: json['category'] as String?,
        tier: json['tier'] as String,
        reports: StatCount.fromJson(json['reports']),
      );

  @override
  List<Object?> get props => [category, tier, reports];
}

/// One `key → count` row of the single-axis groups (`bySubject`,
/// `byStatus`, `byTier`, `hiddenByReason`, `blockedMediaByReason`). The
/// JSON field names differ per group, so the factory is told which to read.
class StatBucketEntity extends Equatable {
  const StatBucketEntity({required this.key, required this.reports});

  final String key;

  /// "reports" for report groups, "media" for the blocked-media group —
  /// still a floored count (164).
  final StatCount reports;

  factory StatBucketEntity.fromJson(
    Map<String, dynamic> json, {
    required String keyField,
    String countField = 'reports',
  }) =>
      StatBucketEntity(
        key: json[keyField] as String,
        reports: StatCount.fromJson(json[countField]),
      );

  @override
  List<Object?> get props => [key, reports];
}

/// `moderation` block: reports created in range currently hidden, by
/// catalog reason (163); media of those reports currently blocked, by
/// reason.
class ModerationStatsEntity extends Equatable {
  const ModerationStatsEntity({required this.hiddenByReason, required this.blockedMediaByReason});

  final List<StatBucketEntity> hiddenByReason;
  final List<StatBucketEntity> blockedMediaByReason;

  factory ModerationStatsEntity.fromJson(Map<String, dynamic> json) => ModerationStatsEntity(
        hiddenByReason: _list(json['hiddenByReason'])
            .map((e) => StatBucketEntity.fromJson(e, keyField: 'reasonCode'))
            .toList(),
        blockedMediaByReason: _list(json['blockedMediaByReason'])
            .map((e) => StatBucketEntity.fromJson(e, keyField: 'reasonCode', countField: 'media'))
            .toList(),
      );

  @override
  List<Object?> get props => [hiddenByReason, blockedMediaByReason];
}

/// The whole `GET /api/reports/stats` response — aggregates only: no
/// per-report rows, no ids, no positions, no identities (164/135/23).
class ReportStatsEntity extends Equatable {
  const ReportStatsEntity({
    required this.range,
    required this.totals,
    required this.byPeriod,
    required this.byCategory,
    required this.bySubject,
    required this.byStatus,
    required this.byTier,
    required this.moderation,
  });

  final StatsRangeEntity range;
  final StatsTotalsEntity totals;
  final List<PeriodStatEntity> byPeriod;
  final List<CategoryStatEntity> byCategory;
  final List<StatBucketEntity> bySubject;
  final List<StatBucketEntity> byStatus;

  /// Summed from categories BEFORE flooring, on the API (164).
  final List<StatBucketEntity> byTier;
  final ModerationStatsEntity moderation;

  factory ReportStatsEntity.fromJson(Map<String, dynamic> json) => ReportStatsEntity(
        range: StatsRangeEntity.fromJson((json['range'] as Map).cast<String, dynamic>()),
        totals: StatsTotalsEntity.fromJson((json['totals'] as Map).cast<String, dynamic>()),
        byPeriod: _list(json['byPeriod']).map(PeriodStatEntity.fromJson).toList(),
        byCategory: _list(json['byCategory']).map(CategoryStatEntity.fromJson).toList(),
        bySubject: _list(json['bySubject'])
            .map((e) => StatBucketEntity.fromJson(e, keyField: 'subject'))
            .toList(),
        byStatus: _list(json['byStatus'])
            .map((e) => StatBucketEntity.fromJson(e, keyField: 'status'))
            .toList(),
        byTier: _list(json['byTier'])
            .map((e) => StatBucketEntity.fromJson(e, keyField: 'tier'))
            .toList(),
        moderation: ModerationStatsEntity.fromJson(
            ((json['moderation'] as Map?) ?? const {}).cast<String, dynamic>()),
      );

  @override
  List<Object?> get props =>
      [range, totals, byPeriod, byCategory, bySubject, byStatus, byTier, moderation];
}

/// Filters of `GET /api/reports/stats`. Everything optional: the API
/// defaults `to` = now, `from` = `to` − 30 days, `granularity` = day.
/// [toQueryParameters] emits only what is set, under the contract names;
/// a bad value is a 422 with field codes (83), rendered by the screen.
class ReportStatsQueryEntity extends Equatable {
  const ReportStatsQueryEntity({this.from, this.to, this.granularity});

  /// `YYYY-MM-DD` (or ISO date-time) on `created_at`.
  final String? from;
  final String? to;

  /// `day | week | month`.
  final String? granularity;

  Map<String, String> toQueryParameters() => {
        if (from != null) 'from': from!,
        if (to != null) 'to': to!,
        if (granularity != null) 'granularity': granularity!,
      };

  @override
  List<Object?> get props => [from, to, granularity];
}

List<Map<String, dynamic>> _list(Object? json) =>
    ((json as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()).toList();
