import 'dart:convert';

import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/admin_audit_entities.dart';
import '../bloc/admin_audit_detail_bloc.dart';
import '../bloc/admin_audit_detail_event.dart';
import '../bloc/admin_audit_detail_state.dart';

/// Indentation of nested summary values (a JSON tree rendered as text).
const _indent = JsonEncoder.withIndent('  ');

/// One audit entry (B5, decisions 110/116/166).
///
/// - `summary` is served as stored — secret-redacted at write time (110).
///   It is rendered as a read-only key/value list when it is a JSON
///   object (nested values → indented text), else as plain text. Nothing
///   here parses it into anything the panel executes.
/// - `ip` is personal data: this detail is the ONLY place it is served,
///   and the caption says so. It never appears in the list.
/// - Reading the entry is not audited (166).
class AdminAuditDetailPage extends StatefulWidget {
  const AdminAuditDetailPage({super.key, required this.entryId, this.autoload = true});

  final int entryId;

  /// The module route dispatches the load itself when creating the bloc;
  /// a bare page (tests) asks for it here.
  final bool autoload;

  @override
  State<AdminAuditDetailPage> createState() => _AdminAuditDetailPageState();
}

class _AdminAuditDetailPageState extends State<AdminAuditDetailPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoload) {
      context.read<AdminAuditDetailBloc>().add(AdminAuditDetailRequested(widget.entryId));
    }
  }

  /// Back to the list: pop when the detail was pushed from it, otherwise
  /// (deep link) navigate to the list route.
  void _back() {
    if (Modular.to.canPop()) {
      Modular.to.pop();
    } else {
      Modular.to.navigate('/admin-audit/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'adminAudit.detail.title'.tr(namedArgs: {'id': '${widget.entryId}'}),
      actions: [
        VgrTextButton(
          key: const Key('audit-back'),
          label: 'adminAudit.detail.back'.tr(),
          icon: VgrIconName.back,
          onPressed: _back,
        ),
      ],
      body: BlocBuilder<AdminAuditDetailBloc, AdminAuditDetailState>(
        builder: (context, state) => switch (state) {
          AdminAuditDetailInitial() || AdminAuditDetailLoading() => const VgrLoading(),
          AdminAuditDetailError(:final failure) =>
            VgrText.error(failureText(failure), key: const Key('audit-detail-error')),
          AdminAuditDetailLoaded(:final entry) => VgrScrollView(
              key: Key('audit-detail-${entry.id}'),
              child: VgrColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._who(entry),
                  const VgrGap.md(),
                  ..._summary(entry),
                  const VgrGap.md(),
                  ..._ip(entry),
                ],
              ),
            ),
        },
      ),
    );
  }

  List<Widget> _who(AuditEntryEntity entry) => [
        VgrText.title('adminAudit.detail.who'.tr()),
        VgrCard(
          child: VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field('when', _when(entry.createdAt)),
              _field(
                'actor',
                'adminAudit.actor'.tr(namedArgs: {
                  'name': entry.actorName ?? 'adminAudit.unknownActor'.tr(),
                  'id': '${entry.actorId}',
                }),
              ),
              _field('action', _actionLabel(entry.action)),
              _field('entity',
                  entry.entityId == null ? entry.entity : '${entry.entity}#${entry.entityId}'),
            ],
          ),
        ),
      ];

  Widget _field(String column, String value) => VgrListTile(
        key: Key('audit-field-$column'),
        dense: true,
        title: 'adminAudit.columns.$column'.tr(),
        subtitleWidget: VgrSelectableText(value),
      );

  /// Object → one row per top-level key, nested values pretty-printed;
  /// anything else → text; null → "no summary".
  List<Widget> _summary(AuditEntryEntity entry) => [
        VgrText.title('adminAudit.detail.summary'.tr()),
        switch (entry.summary) {
          null => VgrText.caption('adminAudit.noSummary'.tr()),
          final Map<dynamic, dynamic> object => VgrCard(
              child: VgrColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in object.entries)
                    VgrListTile(
                      key: Key('audit-summary-${e.key}'),
                      dense: true,
                      title: '${e.key}',
                      subtitleWidget: VgrSelectableText(_valueText(e.value), monospace: true),
                    ),
                ],
              ),
            ),
          final Object other => VgrSelectableText(
              other is String ? other : _indent.convert(other),
              key: const Key('audit-summary-text'),
              monospace: true,
            ),
        },
      ];

  String _valueText(Object? value) => switch (value) {
        null => 'null',
        final String s => s,
        final Map<dynamic, dynamic> m => _indent.convert(m),
        final List<dynamic> l => _indent.convert(l),
        final Object o => '$o',
      };

  List<Widget> _ip(AuditEntryEntity entry) => [
        VgrText.title('adminAudit.detail.ip'.tr()),
        VgrSelectableText(entry.ip ?? 'adminAudit.detail.noIp'.tr(),
            key: const Key('audit-ip'), monospace: true),
        VgrText.caption('adminAudit.detail.ipCaption'.tr(), key: const Key('audit-ip-caption')),
      ];

  String _actionLabel(String action) {
    final key = 'adminAudit.action.$action';
    final translated = key.tr();
    return translated == key ? action : translated;
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
