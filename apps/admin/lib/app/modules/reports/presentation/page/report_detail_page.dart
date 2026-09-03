import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/report_entities.dart';
import '../bloc/report_detail_bloc.dart';
import '../bloc/report_detail_event.dart';
import '../bloc/report_detail_state.dart';

/// Case detail on the panel plane (B1, decisions 159/160/165/166).
///
/// - Opening it is AUDITED server-side (166); the screen says nothing
///   special about it — the list already warns.
/// - Position is the DEGRADED grid with its precision (159); "Reveal
///   exact position" exists only with the `report_exact_position` grant
///   and is a separate, audited read.
/// - Reporter/helpers: "Anonymous", or displayName + opaque account id
///   (160). Never an e-mail — the API never sends one.
/// - The Retention/freeze section EMBEDS P1 (141/141d/165) against
///   `/api/case-freeze`; buttons follow the `case_freeze` UPDATE grant.
class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({super.key, required this.reportId, this.autoload = true});

  final int reportId;

  /// The module route dispatches the load itself when creating the bloc;
  /// a bare page (tests) asks for it here.
  final bool autoload;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  final _reasonController = TextEditingController();
  String? _reasonError;

  @override
  void initState() {
    super.initState();
    if (widget.autoload) {
      context.read<ReportDetailBloc>().add(ReportDetailRequested(widget.reportId));
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Mirrors `freezeReasonDto` `z.string().min(3)` through
  /// `VgrValidators.minLength` (decisions 141/157) — feedback only, the
  /// server stays the authority.
  String? _validReason() {
    final error = VgrValidators.minLength(3)(_reasonController.text);
    setState(() => _reasonError = error == null
        ? null
        : fieldFailureText(FieldFailure(
            field: 'reason',
            message: error.code,
            code: error.code,
            params: error.params,
          )));
    return error == null ? _reasonController.text.trim() : null;
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'reports.detail.title'.tr(namedArgs: {'id': '${widget.reportId}'}),
      body: BlocBuilder<ReportDetailBloc, ReportDetailState>(
        builder: (context, state) => switch (state) {
          ReportDetailInitial() || ReportDetailLoading() => const VgrLoading(),
          ReportDetailError(:final failure) => VgrText.error(failureText(failure),
              key: const Key('report-detail-error')),
          ReportDetailLoaded() => VgrScrollView(
              child: VgrColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(state.detail),
                  const VgrGap.md(),
                  ..._reporter(state.detail),
                  const VgrGap.md(),
                  ..._position(state),
                  if (state.detail.detailFields?.isNotEmpty ?? false) ...[
                    const VgrGap.md(),
                    ..._fields(state.detail.detailFields!),
                  ],
                  if (state.detail.timeline.isNotEmpty) ...[
                    const VgrGap.md(),
                    ..._timeline(state.detail.timeline),
                  ],
                  if (state.detail.media.isNotEmpty) ...[
                    const VgrGap.md(),
                    ..._media(state.detail.media),
                  ],
                  const VgrGap.md(),
                  ..._offers(state.detail.offers),
                  const VgrGap.lg(),
                  ..._freezeSection(state),
                ],
              ),
            ),
        },
      ),
    );
  }

  Widget _header(ReportPanelDetailEntity d) {
    final taxonomy =
        d.category != null ? 'reports.category.${d.category}'.tr() : (d.freeTag ?? '—');
    return VgrCard(
      child: VgrPadding(
        child: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VgrText.title('$taxonomy · ${'reports.subject.${d.subject}'.tr()}'),
            VgrText.caption('${'reports.tier.${d.tier}'.tr()} · '
                '${'reports.status.${d.status}'.tr()}'),
            VgrText.caption('reports.detail.created'.tr(namedArgs: {'when': _when(d.createdAt)})),
            if (d.resolvedAt != null)
              VgrText.caption(
                  'reports.detail.resolved'.tr(namedArgs: {'when': _when(d.resolvedAt!)})),
            if (d.expiresAt != null)
              VgrText.caption(
                  'reports.detail.expires'.tr(namedArgs: {'when': _when(d.expiresAt!)})),
            if (d.purged) ...[
              const VgrGap.sm(),
              VgrText.error('reports.detail.purged'.tr(), key: const Key('report-purged-badge')),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _reporter(ReportPanelDetailEntity d) => [
        VgrText.title('reports.detail.reporter'.tr()),
        if (d.reporter == null)
          VgrText('reports.detail.anonymous'.tr(), key: const Key('report-reporter-anonymous'))
        else
          VgrListTile(
            key: const Key('report-reporter-identified'),
            dense: true,
            leadingIcon: VgrIconName.person,
            title: d.reporter!.displayName,
            subtitle: 'reports.detail.account'.tr(namedArgs: {'id': '${d.reporter!.accountId}'}),
          ),
      ];

  List<Widget> _position(ReportDetailLoaded state) {
    final position = state.detail.position;
    final canReveal =
        SessionAccess.instance.can('report_exact_position', Privileges.view);
    return [
      VgrText.title('reports.detail.position'.tr()),
      if (position == null)
        VgrText.caption('reports.detail.noPosition'.tr())
      else ...[
        VgrRow(children: [
          const VgrIcon(VgrIconName.location, size: 16),
          const VgrGap.hSm(),
          VgrText('reports.detail.approx'.tr(namedArgs: {
            'lat': position.lat.toStringAsFixed(3),
            'lng': position.lng.toStringAsFixed(3),
          })),
        ]),
        VgrText.caption('reports.detail.precision'
            .tr(namedArgs: {'meters': '${position.precisionMeters ?? '?'}'})),
        if (state.exactPosition != null) ...[
          const VgrGap.sm(),
          VgrText(
            'reports.detail.exact'.tr(namedArgs: {
              'lat': state.exactPosition!.lat.toStringAsFixed(6),
              'lng': state.exactPosition!.lng.toStringAsFixed(6),
            }),
            key: const Key('exact-position'),
            monospace: true,
          ),
          VgrText.caption('reports.detail.exactAudited'.tr()),
        ] else if (canReveal) ...[
          const VgrGap.sm(),
          VgrSecondaryButton(
            key: const Key('reveal-position-button'),
            label: 'reports.detail.reveal'.tr(),
            onPressed: state.busy
                ? null
                : () => context
                    .read<ReportDetailBloc>()
                    .add(const ReportExactPositionRequested()),
          ),
        ],
      ],
    ];
  }

  List<Widget> _fields(Map<String, dynamic> fields) => [
        VgrText.title('reports.detail.fields'.tr()),
        for (final entry in fields.entries) VgrText('${entry.key}: ${entry.value}'),
      ];

  List<Widget> _timeline(List<ReportTimelineEventEntity> events) => [
        VgrText.title('reports.detail.timeline'.tr()),
        for (final event in events)
          VgrListTile(
            dense: true,
            leadingIcon: VgrIconName.forward,
            title: _trOr('reports.detail.event.${event.eventType}', event.eventType),
            subtitle: _when(event.createdAt),
          ),
      ];

  /// Attachments are LISTED, not shown: the image is served by
  /// `/api/media` under `media_evidence` with the panel JWT in a header,
  /// which a web `<img>` cannot carry — see `report-moderation.md`.
  List<Widget> _media(List<ReportMediaEntity> media) => [
        VgrText.title('reports.detail.media'.tr()),
        VgrText.caption('reports.detail.mediaNote'.tr()),
        for (final m in media)
          VgrListTile(
            key: Key('report-media-${m.publicId}'),
            dense: true,
            leadingIcon: VgrIconName.image,
            title: m.publicId,
            subtitle: 'reports.detail.mediaRow'.tr(namedArgs: {
              'mime': m.mime,
              'size': m.width != null && m.height != null ? '${m.width}×${m.height}' : '—',
              'status': _trOr('reports.detail.mediaStatus.${m.status}', m.status),
            }),
          ),
      ];

  List<Widget> _offers(List<ReportOfferEntity> offers) => [
        VgrText.title('reports.detail.offers'.tr()),
        if (offers.isEmpty)
          VgrText.caption('reports.detail.noOffers'.tr())
        else
          for (final offer in offers)
            VgrListTile(
              key: Key('report-offer-${offer.helpOfferId}'),
              dense: true,
              leadingIcon: VgrIconName.person,
              // Identified helper → name + opaque id; anonymous → label (160).
              title: offer.helper?.displayName ?? 'reports.detail.anonymousHelper'.tr(),
              subtitle: [
                if (offer.helper != null)
                  'reports.detail.account'.tr(namedArgs: {'id': '${offer.helper!.accountId}'}),
                _trOr('reports.detail.helpType.${offer.helpType}', offer.helpType),
                _when(offer.createdAt),
              ].join(' · '),
            ),
      ];

  /// P1's three states, verbatim (141/141d): the server state decides
  /// which ONE renders; the bloc re-fetches after every action.
  List<Widget> _freezeSection(ReportDetailLoaded state) {
    final freeze = state.freeze;
    final canUpdate = SessionAccess.instance.can('case_freeze', Privileges.update);
    return [
      VgrText.title('reports.detail.freezeTitle'.tr()),
      if (state.failure != null) ...[
        VgrText.error(failureText(state.failure!), key: const Key('report-action-error')),
        const VgrGap.sm(),
      ],
      if (freeze == null)
        VgrText.caption('reports.detail.freezeUnavailable'.tr(),
            key: const Key('freeze-unavailable'))
      else ...[
        if (freeze.frozen) ...[
          VgrText.error('reports.detail.frozen'.tr(), key: const Key('report-frozen-badge')),
          if (freeze.frozenReason != null)
            VgrText('reports.detail.frozenReason'
                .tr(namedArgs: {'reason': freeze.frozenReason!})),
          if (freeze.frozenAt != null) VgrText.caption(_when(freeze.frozenAt!)),
        ] else
          VgrText('reports.detail.notFrozen'.tr(), key: const Key('report-not-frozen-badge')),
        const VgrGap.sm(),
        if (!freeze.frozen)
          ..._freezeAction(state, canUpdate: canUpdate)
        else if (freeze.pendingUnfreeze == null)
          ..._requestUnfreezeAction(state, canUpdate: canUpdate)
        else
          ..._approveUnfreezeAction(state, freeze.pendingUnfreeze!, canUpdate: canUpdate),
      ],
    ];
  }

  List<Widget> _freezeAction(ReportDetailLoaded state, {required bool canUpdate}) => [
        VgrTextField(
          key: const Key('freeze-reason-field'),
          controller: _reasonController,
          label: 'reports.detail.reason'.tr(),
          errorText: _reasonError,
        ),
        const VgrGap.sm(),
        VgrPrimaryButton(
          key: const Key('freeze-button'),
          label: 'reports.detail.freeze'.tr(),
          busy: state.busy,
          onPressed: !canUpdate
              ? null
              : () {
                  final reason = _validReason();
                  if (reason == null) return;
                  _reasonController.clear();
                  context.read<ReportDetailBloc>().add(ReportFreezeSubmitted(reason));
                },
        ),
      ];

  List<Widget> _requestUnfreezeAction(ReportDetailLoaded state, {required bool canUpdate}) => [
        VgrText.caption('reports.detail.dualControlHint'.tr()),
        VgrTextField(
          key: const Key('unfreeze-reason-field'),
          controller: _reasonController,
          label: 'reports.detail.reason'.tr(),
          errorText: _reasonError,
        ),
        const VgrGap.sm(),
        VgrPrimaryButton(
          key: const Key('request-unfreeze-button'),
          label: 'reports.detail.requestUnfreeze'.tr(),
          busy: state.busy,
          onPressed: !canUpdate
              ? null
              : () {
                  final reason = _validReason();
                  if (reason == null) return;
                  _reasonController.clear();
                  context.read<ReportDetailBloc>().add(ReportUnfreezeRequestSubmitted(reason));
                },
        ),
      ];

  List<Widget> _approveUnfreezeAction(
    ReportDetailLoaded state,
    ReportPendingUnfreezeEntity pending, {
    required bool canUpdate,
  }) =>
      [
        VgrListTile(
          key: const Key('pending-unfreeze-tile'),
          dense: true,
          leadingIcon: VgrIconName.person,
          title: 'reports.detail.pendingBy'.tr(namedArgs: {'user': '${pending.requestedBy}'}),
          subtitle: '${pending.reason} · ${_when(pending.requestedAt)}',
        ),
        VgrText.caption('reports.detail.approveHint'.tr()),
        const VgrGap.sm(),
        VgrPrimaryButton(
          key: const Key('approve-unfreeze-button'),
          label: 'reports.detail.approveUnfreeze'.tr(),
          busy: state.busy,
          onPressed: !canUpdate
              ? null
              : () => context
                  .read<ReportDetailBloc>()
                  .add(const ReportUnfreezeApproveSubmitted()),
        ),
      ];

  /// A catalog key that is missing falls back to the raw server value —
  /// a new event type must never blank a row.
  String _trOr(String key, String fallback) {
    final translated = key.tr();
    return translated == key ? fallback : translated;
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
