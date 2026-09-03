import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/report_stats_entities.dart';
import '../bloc/report_stats_bloc.dart';
import '../bloc/report_stats_event.dart';
import '../bloc/report_stats_state.dart';

/// `granularity` values the API accepts (B4 contract); default `day`.
const _granularities = ['day', 'week', 'month'];

/// Key of the free-tag bucket (`category == null`) in row keys and labels.
const _freeTagKey = 'free_tag';

/// Aggregated report statistics on the panel plane (B4, decisions 164/165).
/// Counters and tables only — no chart library, no map, no per-report
/// row: every figure arrives already summed and floored at k = 5 by the
/// API, and `"<5"` is rendered exactly as served. The read is not
/// audited (165 — aggregates are not evidence). Loads with the API
/// defaults on entry; Apply re-reads with the form values.
class ReportStatsPage extends StatefulWidget {
  const ReportStatsPage({super.key, this.autoload = true});

  /// False lets a host dispatch the first read itself (module wiring).
  final bool autoload;

  @override
  State<ReportStatsPage> createState() => _ReportStatsPageState();
}

class _ReportStatsPageState extends State<ReportStatsPage> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  String _granularity = _granularities.first;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    if (widget.autoload) {
      context.read<ReportStatsBloc>().add(const ReportStatsRequested(ReportStatsQueryEntity()));
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// Format feedback before the round trip (decision 157); the API stays
  /// the authority on the range itself (from ≤ to, ≤ 366 days) and
  /// answers 422 by field code (83).
  void _apply() {
    final errors = VgrValidators.validate({
      if (_fromController.text.trim().isNotEmpty)
        'from': (_fromController.text, [VgrValidators.isoDate]),
      if (_toController.text.trim().isNotEmpty)
        'to': (_toController.text, [VgrValidators.isoDate]),
    });
    setState(() => _fieldErrors = {
          for (final e in errors.entries)
            e.key: fieldFailureText(FieldFailure(
              field: e.key,
              message: e.value.code,
              code: e.value.code,
              params: e.value.params,
            )),
        });
    if (errors.isNotEmpty) return;

    String? opt(String value) => value.trim().isEmpty ? null : value.trim();
    context.read<ReportStatsBloc>().add(ReportStatsRequested(ReportStatsQueryEntity(
      from: opt(_fromController.text),
      to: opt(_toController.text),
      granularity: _granularity,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'reportStats.title'.tr(),
      body: BlocBuilder<ReportStatsBloc, ReportStatsState>(
        builder: (context, state) {
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterBar(busy: state is ReportStatsLoading),
                const VgrGap.md(),
                ...switch (state) {
                  ReportStatsInitial() || ReportStatsLoading() => const [VgrLoading()],
                  ReportStatsError(:final failure) => [
                      VgrText.error(failureText(failure), key: const Key('report-stats-error')),
                    ],
                  ReportStatsLoaded(:final stats) => _results(stats),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar({required bool busy}) {
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrWrap(
          children: [
            VgrFixedWidth(
              width: 180,
              child: VgrTextField(
                key: const Key('report-stats-from'),
                controller: _fromController,
                label: 'reportStats.from'.tr(),
                errorText: _fieldErrors['from'],
                onSubmitted: (_) => _apply(),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrTextField(
                key: const Key('report-stats-to'),
                controller: _toController,
                label: 'reportStats.to'.tr(),
                errorText: _fieldErrors['to'],
                onSubmitted: (_) => _apply(),
              ),
            ),
            VgrFixedWidth(
              width: 160,
              child: VgrDropdownField<String>(
                key: const Key('report-stats-granularity'),
                label: 'reportStats.granularity'.tr(),
                value: _granularity,
                options: [
                  for (final g in _granularities)
                    VgrOption(value: g, label: 'reportStats.granularityOptions.$g'.tr()),
                ],
                onChanged: (v) => setState(() => _granularity = v ?? _granularities.first),
              ),
            ),
          ],
        ),
        const VgrGap.sm(),
        VgrPrimaryButton(
          key: const Key('report-stats-apply'),
          label: 'reportStats.apply'.tr(),
          icon: VgrIconName.search,
          busy: busy,
          onPressed: _apply,
        ),
      ],
    );
  }

  List<Widget> _results(ReportStatsEntity stats) {
    final range = VgrText.caption('reportStats.rangeLine'.tr(namedArgs: {
      'from': _when(stats.range.from),
      'to': _when(stats.range.to),
      'granularity': 'reportStats.granularityOptions.${stats.range.granularity}'.tr(),
    }));
    if (stats.totals.allZero) {
      return [
        range,
        const VgrGap.sm(),
        VgrText('reportStats.empty'.tr(), key: const Key('report-stats-empty')),
      ];
    }
    return [
      range,
      const VgrGap.sm(),
      VgrWrap(children: [for (final e in stats.totals.entries) _tile(e.$1, e.$2)]),
      const VgrGap.sm(),
      // The floor is the one thing an operator must know to read a table
      // here (decision 164): "<5" is not an error and not a zero.
      VgrText.caption('reportStats.floorNote'.tr(), key: const Key('report-stats-floor-note')),
      const VgrGap.md(),
      _section('byPeriod', [
        for (final row in stats.byPeriod)
          _row('report-stats-period-${row.period}', row.period, row.reports),
      ]),
      _section('byCategory', [
        for (final row in stats.byCategory)
          _row(
            'report-stats-category-${row.category ?? _freeTagKey}',
            '${_categoryLabel(row.category)} · ${'reports.tier.${row.tier}'.tr()}',
            row.reports,
          ),
      ]),
      _section('bySubject', [
        for (final row in stats.bySubject)
          _row('report-stats-subject-${row.key}', 'reports.subject.${row.key}'.tr(), row.reports),
      ]),
      _section('byStatus', [
        for (final row in stats.byStatus)
          _row('report-stats-status-${row.key}', 'reports.status.${row.key}'.tr(), row.reports),
      ]),
      _section('byTier', [
        for (final row in stats.byTier)
          _row('report-stats-tier-${row.key}', 'reports.tier.${row.key}'.tr(), row.reports),
      ]),
      // Moderation reasons are the B2 catalog (163) — same i18n keys.
      _section('hiddenByReason', [
        for (final row in stats.moderation.hiddenByReason)
          _row('report-stats-hidden-reason-${row.key}',
              'reports.moderation.reason.${row.key}'.tr(), row.reports),
      ]),
      _section('blockedMediaByReason', [
        for (final row in stats.moderation.blockedMediaByReason)
          _row('report-stats-blocked-reason-${row.key}',
              'reports.moderation.reason.${row.key}'.tr(), row.reports),
      ]),
    ];
  }

  Widget _tile(String key, StatCount count) => VgrCard(
        key: Key('report-stats-total-$key'),
        child: VgrPadding(
          child: VgrFixedWidth(
            width: 140,
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VgrText.caption('reportStats.totals.$key'.tr()),
                VgrText.headline(count.label()),
              ],
            ),
          ),
        ),
      );

  Widget _section(String key, List<Widget> rows) => VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VgrText.title('reportStats.sections.$key'.tr()),
          const VgrGap.xs(),
          if (rows.isEmpty)
            VgrText.caption('reportStats.sectionEmpty'.tr())
          else
            VgrCard(
              child: VgrColumn(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
            ),
          const VgrGap.md(),
        ],
      );

  /// label · count — the count column is the served figure, floored.
  Widget _row(String key, String label, StatCount count) => VgrListTile(
        key: Key(key),
        title: label,
        trailing: VgrText.title(count.label()),
        dense: true,
      );

  String _categoryLabel(String? category) =>
      category == null ? 'reportStats.freeTag'.tr() : 'reports.category.$category'.tr();

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
