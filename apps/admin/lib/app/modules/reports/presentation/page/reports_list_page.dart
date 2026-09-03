import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/report_entities.dart';
import '../../domain/entity/report_taxonomy.dart';
import '../bloc/reports_list_bloc.dart';
import '../bloc/reports_list_event.dart';
import '../bloc/reports_list_state.dart';

/// Sentinel for "no filter" in the closed-set dropdowns — the query
/// simply omits the parameter.
const _any = '';

/// Paginated report search on the panel plane (B1, decision 158).
/// Nothing is fetched until the operator presses Search: the list is not
/// audited (166), but it is the door to detail reads that are. Every row
/// shows the DEGRADED position only through its absence/presence — the
/// coordinates themselves belong to the detail (159).
class ReportsListPage extends StatefulWidget {
  const ReportsListPage({super.key});

  @override
  State<ReportsListPage> createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  final _idController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  String _status = _any;
  String _category = _any;
  String _subject = _any;
  String _tier = _any;
  String _frozen = _any;
  String _hasMedia = _any;
  String _hidden = _any;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _idController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// Format feedback before the round trip (decision 157); the API stays
  /// the authority and answers 422 by field code on anything else (83).
  void _search() {
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

    bool? tri(String value) => value == _any ? null : value == 'true';
    String? opt(String value) => value == _any ? null : value;
    final filters = ReportFiltersEntity(
      id: int.tryParse(_idController.text.trim()),
      status: opt(_status),
      category: opt(_category),
      subject: opt(_subject),
      tier: opt(_tier),
      frozen: tri(_frozen),
      hasMedia: tri(_hasMedia),
      hidden: tri(_hidden),
      from: opt(_fromController.text.trim()),
      to: opt(_toController.text.trim()),
    );
    context.read<ReportsListBloc>().add(ReportsSearchRequested(filters));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'reports.list.title'.tr(),
      body: BlocBuilder<ReportsListBloc, ReportsListState>(
        builder: (context, state) {
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filterBar(busy: state is ReportsListLoading),
                const VgrGap.md(),
                ...switch (state) {
                  ReportsListInitial() => [VgrText.caption('reports.list.hint'.tr())],
                  ReportsListLoading() => const [VgrLoading()],
                  ReportsListError(:final failure) => [
                      VgrText.error(failureText(failure),
                          key: const Key('reports-list-error')),
                    ],
                  ReportsListLoaded(:final page) => _results(page),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  List<VgrOption<String>> _options(String prefix, List<String> keys) => [
        VgrOption(value: _any, label: 'reports.list.any'.tr()),
        for (final key in keys) VgrOption(value: key, label: '$prefix.$key'.tr()),
      ];

  List<VgrOption<String>> _triOptions() => [
        VgrOption(value: _any, label: 'reports.list.any'.tr()),
        VgrOption(value: 'true', label: 'reports.list.yes'.tr()),
        VgrOption(value: 'false', label: 'reports.list.no'.tr()),
      ];

  Widget _filterBar({required bool busy}) {
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrWrap(
          children: [
            VgrFixedWidth(
              width: 140,
              child: VgrTextField(
                key: const Key('reports-filter-id'),
                controller: _idController,
                label: 'reports.list.id'.tr(),
                keyboard: VgrKeyboard.number,
                onSubmitted: (_) => _search(),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-status'),
                label: 'reports.list.status'.tr(),
                value: _status,
                options: _options('reports.status', reportStatuses),
                onChanged: (v) => setState(() => _status = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 200,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-category'),
                label: 'reports.list.category'.tr(),
                value: _category,
                options: _options('reports.category', reportCategories),
                onChanged: (v) => setState(() => _category = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-subject'),
                label: 'reports.list.subject'.tr(),
                value: _subject,
                options: _options('reports.subject', reportSubjects),
                onChanged: (v) => setState(() => _subject = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 160,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-tier'),
                label: 'reports.list.tier'.tr(),
                value: _tier,
                options: _options('reports.tier', reportTiers),
                onChanged: (v) => setState(() => _tier = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 160,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-frozen'),
                label: 'reports.list.frozen'.tr(),
                value: _frozen,
                options: _triOptions(),
                onChanged: (v) => setState(() => _frozen = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 160,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-has-media'),
                label: 'reports.list.hasMedia'.tr(),
                value: _hasMedia,
                options: _triOptions(),
                onChanged: (v) => setState(() => _hasMedia = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 160,
              child: VgrDropdownField<String>(
                key: const Key('reports-filter-hidden'),
                label: 'reports.list.hidden'.tr(),
                value: _hidden,
                options: _triOptions(),
                onChanged: (v) => setState(() => _hidden = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrTextField(
                key: const Key('reports-filter-from'),
                controller: _fromController,
                label: 'reports.list.from'.tr(),
                errorText: _fieldErrors['from'],
                onSubmitted: (_) => _search(),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrTextField(
                key: const Key('reports-filter-to'),
                controller: _toController,
                label: 'reports.list.to'.tr(),
                errorText: _fieldErrors['to'],
                onSubmitted: (_) => _search(),
              ),
            ),
          ],
        ),
        const VgrGap.sm(),
        VgrPrimaryButton(
          key: const Key('reports-search-button'),
          label: 'reports.list.search'.tr(),
          icon: VgrIconName.search,
          busy: busy,
          onPressed: _search,
        ),
      ],
    );
  }

  List<Widget> _results(ReportPageEntity page) {
    if (page.items.isEmpty) {
      return [
        VgrText('reports.list.empty'.tr(), key: const Key('reports-empty')),
      ];
    }
    return [
      VgrCard(
        child: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in page.items) _row(item),
          ],
        ),
      ),
      const VgrGap.sm(),
      _pagination(page),
    ];
  }

  Widget _row(ReportListItemEntity item) {
    final taxonomy = item.category != null
        ? 'reports.category.${item.category}'.tr()
        : (item.freeTag ?? '—');
    final marks = [
      if (item.frozen) 'reports.list.frozenMark'.tr(),
      if (item.purged) 'reports.list.purgedMark'.tr(),
      // Moderation mark (B2, 162): hidden cases stay searchable here.
      if (item.hidden) 'reports.list.hiddenMark'.tr(),
      if (item.anonymous) 'reports.list.anonymousMark'.tr(),
    ];
    final meta = 'reports.list.rowMeta'.tr(namedArgs: {
      'tier': 'reports.tier.${item.tier}'.tr(),
      'status': 'reports.status.${item.status}'.tr(),
      'media': '${item.mediaCount}',
      'when': _when(item.createdAt),
    });
    return VgrListTile(
      key: Key('report-row-${item.reportId}'),
      leadingIcon: item.frozen ? VgrIconName.security : VgrIconName.forward,
      title: 'reports.list.row'.tr(namedArgs: {
        'id': '${item.reportId}',
        'taxonomy': taxonomy,
        'subject': 'reports.subject.${item.subject}'.tr(),
      }),
      subtitle: marks.isEmpty ? meta : '$meta · ${marks.join(' · ')}',
      onTap: () => Modular.to.pushNamed('/reports/${item.reportId}'),
    );
  }

  Widget _pagination(ReportPageEntity page) {
    final bloc = context.read<ReportsListBloc>();
    return VgrRow(
      children: [
        VgrSecondaryButton(
          key: const Key('reports-prev'),
          label: 'reports.list.prev'.tr(),
          onPressed: page.page <= 1 ? null : () => bloc.add(ReportsPageRequested(page.page - 1)),
        ),
        const VgrGap.hMd(),
        VgrText('reports.list.pageOf'
            .tr(namedArgs: {'page': '${page.page}', 'pages': '${page.pageCount}'})),
        const VgrGap.hMd(),
        VgrSecondaryButton(
          key: const Key('reports-next'),
          label: 'reports.list.next'.tr(),
          onPressed: page.page >= page.pageCount
              ? null
              : () => bloc.add(ReportsPageRequested(page.page + 1)),
        ),
      ],
    );
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
