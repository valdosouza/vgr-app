import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/admin_audit_entities.dart';
import '../bloc/admin_audit_list_bloc.dart';
import '../bloc/admin_audit_list_event.dart';
import '../bloc/admin_audit_list_state.dart';

/// Sentinel for "no filter" in the facet dropdowns — the query simply
/// omits the parameter.
const _any = '';

/// The admin audit trail (B5, decisions 116/158/165/166): who did what,
/// when, on the panel. READ only — the table is append-only by the API
/// (116) and reading it is not audited (166). Rows show who/what/when and
/// a one-line summary preview; the operator `ip` is personal data and
/// belongs to the detail alone. Loads facets + the first page on entry.
class AdminAuditListPage extends StatefulWidget {
  const AdminAuditListPage({super.key, this.autoload = true});

  /// False lets a host dispatch the entry load itself (module wiring).
  final bool autoload;

  @override
  State<AdminAuditListPage> createState() => _AdminAuditListPageState();
}

class _AdminAuditListPageState extends State<AdminAuditListPage> {
  final _actorIdController = TextEditingController();
  final _entityIdController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  String _action = _any;
  String _entity = _any;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    if (widget.autoload) {
      context.read<AdminAuditListBloc>().add(const AdminAuditListStarted());
    }
  }

  @override
  void dispose() {
    _actorIdController.dispose();
    _entityIdController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// Format feedback before the round trip (decision 157); the API stays
  /// the authority and answers 422 by field code on anything else (83).
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
    context.read<AdminAuditListBloc>().add(AdminAuditSearchRequested(AuditFiltersEntity(
      actorId: int.tryParse(_actorIdController.text.trim()),
      action: opt(_action),
      entity: opt(_entity),
      entityId: opt(_entityIdController.text),
      from: opt(_fromController.text),
      to: opt(_toController.text),
    )));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'adminAudit.title'.tr(),
      body: BlocBuilder<AdminAuditListBloc, AdminAuditListState>(
        builder: (context, state) {
          final facets = switch (state) {
            AdminAuditListInitial() => AuditFacetsEntity.empty,
            AdminAuditListLoading(:final facets) => facets ?? AuditFacetsEntity.empty,
            AdminAuditListLoaded(:final facets) => facets,
            AdminAuditListError(:final facets) => facets,
          };
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VgrText.caption('adminAudit.hint'.tr()),
                const VgrGap.sm(),
                _filterBar(facets, busy: state is AdminAuditListLoading),
                const VgrGap.md(),
                ...switch (state) {
                  AdminAuditListInitial() || AdminAuditListLoading() => const [VgrLoading()],
                  AdminAuditListError(:final failure) => [
                      VgrText.error(failureText(failure), key: const Key('audit-list-error')),
                    ],
                  AdminAuditListLoaded(:final page) => _results(page),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  /// Facet options: "Any" + the DISTINCT values the API found. Actions
  /// have catalog labels; entities are shown raw (they are code names).
  List<VgrOption<String>> _facetOptions(List<String> values, {bool labelled = false}) => [
        VgrOption(value: _any, label: 'adminAudit.filters.any'.tr()),
        for (final v in values) VgrOption(value: v, label: labelled ? _actionLabel(v) : v),
      ];

  Widget _filterBar(AuditFacetsEntity facets, {required bool busy}) {
    // A value that the current facets no longer offer falls back to Any
    // rather than crashing the dropdown.
    final action = facets.actions.contains(_action) ? _action : _any;
    final entity = facets.entities.contains(_entity) ? _entity : _any;
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrWrap(
          children: [
            VgrFixedWidth(
              width: 140,
              child: VgrTextField(
                key: const Key('audit-filter-actor-id'),
                controller: _actorIdController,
                label: 'adminAudit.filters.actorId'.tr(),
                keyboard: VgrKeyboard.number,
                onSubmitted: (_) => _apply(),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrDropdownField<String>(
                key: const Key('audit-filter-action'),
                label: 'adminAudit.filters.action'.tr(),
                value: action,
                options: _facetOptions(facets.actions, labelled: true),
                onChanged: (v) => setState(() => _action = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 220,
              child: VgrDropdownField<String>(
                key: const Key('audit-filter-entity'),
                label: 'adminAudit.filters.entity'.tr(),
                value: entity,
                options: _facetOptions(facets.entities),
                onChanged: (v) => setState(() => _entity = v ?? _any),
              ),
            ),
            VgrFixedWidth(
              width: 160,
              child: VgrTextField(
                key: const Key('audit-filter-entity-id'),
                controller: _entityIdController,
                label: 'adminAudit.filters.entityId'.tr(),
                onSubmitted: (_) => _apply(),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrTextField(
                key: const Key('audit-filter-from'),
                controller: _fromController,
                label: 'adminAudit.filters.from'.tr(),
                errorText: _fieldErrors['from'],
                onSubmitted: (_) => _apply(),
              ),
            ),
            VgrFixedWidth(
              width: 180,
              child: VgrTextField(
                key: const Key('audit-filter-to'),
                controller: _toController,
                label: 'adminAudit.filters.to'.tr(),
                errorText: _fieldErrors['to'],
                onSubmitted: (_) => _apply(),
              ),
            ),
          ],
        ),
        const VgrGap.sm(),
        VgrPrimaryButton(
          key: const Key('audit-apply'),
          label: 'adminAudit.filters.apply'.tr(),
          icon: VgrIconName.search,
          busy: busy,
          onPressed: _apply,
        ),
      ],
    );
  }

  List<Widget> _results(AuditPageEntity page) {
    if (page.items.isEmpty) {
      return [VgrText('adminAudit.empty'.tr(), key: const Key('audit-empty'))];
    }
    return [
      VgrCard(
        child: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final item in page.items) _row(item)],
        ),
      ),
      const VgrGap.sm(),
      _pagination(page),
    ];
  }

  /// when · actor (#id) · action / entity#entityId · summary preview.
  Widget _row(AuditListItemEntity item) {
    final preview = item.summaryPreview();
    final target = _target(item);
    return VgrListTile(
      key: Key('audit-row-${item.id}'),
      leadingIcon: item.action == 'read' ? VgrIconName.visibility : VgrIconName.edit,
      title: 'adminAudit.row'.tr(namedArgs: {
        'when': _when(item.createdAt),
        'actor': _actor(item),
        'action': _actionLabel(item.action),
      }),
      subtitle: preview.isEmpty ? target : '$target · $preview',
      onTap: () => Modular.to.pushNamed('/admin-audit/${item.id}'),
    );
  }

  Widget _pagination(AuditPageEntity page) {
    final bloc = context.read<AdminAuditListBloc>();
    return VgrRow(
      children: [
        VgrSecondaryButton(
          key: const Key('audit-prev'),
          label: 'adminAudit.prev'.tr(),
          onPressed:
              page.page <= 1 ? null : () => bloc.add(AdminAuditPageRequested(page.page - 1)),
        ),
        const VgrGap.hMd(),
        VgrText('adminAudit.pageOf'
            .tr(namedArgs: {'page': '${page.page}', 'pages': '${page.pageCount}'})),
        const VgrGap.hMd(),
        VgrSecondaryButton(
          key: const Key('audit-next'),
          label: 'adminAudit.next'.tr(),
          onPressed: page.page >= page.pageCount
              ? null
              : () => bloc.add(AdminAuditPageRequested(page.page + 1)),
        ),
      ],
    );
  }

  String _actor(AuditListItemEntity item) => 'adminAudit.actor'.tr(namedArgs: {
        'name': item.actorName ?? 'adminAudit.unknownActor'.tr(),
        'id': '${item.actorId}',
      });

  String _target(AuditListItemEntity item) =>
      item.entityId == null ? item.entity : '${item.entity}#${item.entityId}';

  /// A catalog key that is missing falls back to the raw server value —
  /// a new action must never blank a row.
  String _actionLabel(String action) {
    final key = 'adminAudit.action.$action';
    final translated = key.tr();
    return translated == key ? action : translated;
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
