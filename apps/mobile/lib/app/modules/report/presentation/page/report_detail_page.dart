import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/report_view_entity.dart';
import '../bloc/report_detail_bloc.dart';

/// Report detail (spec task 22, decision 50). The SERVER resolves what
/// this viewer may see — the page renders strictly by `access` and never
/// tries to show more than it received.
class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    super.key,
    required this.reportId,
    required this.mediaBaseUrl,
    this.onOfferHelp,
    this.onOpenChat,
  });

  final int reportId;

  /// Base URL for media streams (`GET /app-reports/:id/media/...`).
  final String mediaBaseUrl;

  /// Test seam — default navigation goes through Modular.
  final void Function(int reportId)? onOfferHelp;

  /// Test seam for the chat entry — receives the route it would push.
  final void Function(String route)? onOpenChat;

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<ReportDetailBloc>().add(DetailStarted(widget.reportId));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'detail.title'.tr(),
      body: BlocBuilder<ReportDetailBloc, ReportDetailState>(
        builder: (context, state) => switch (state) {
          DetailLoading() => const VgrLoading(),
          DetailError(failure: final failure) => VgrCenter(
              child: VgrColumn(children: [
                VgrText.error(failureText(failure), key: const Key('detail-error')),
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('detail-retry-button'),
                  label: 'feed.retry'.tr(),
                  onPressed: () => context
                      .read<ReportDetailBloc>()
                      .add(DetailStarted(widget.reportId)),
                ),
              ]),
            ),
          DetailLoaded(view: final view, clientKey: final clientKey) =>
            _loaded(view, clientKey),
        },
      ),
    );
  }

  Widget _loaded(ReportViewEntity view, String? clientKey) {
    // Resolved case, non-participant: ONLY the closure status renders —
    // no timeline, no details (decision 50, spec scenario).
    if (view.access == ReportAccess.summary) {
      return VgrCenter(
        child: VgrColumn(
          key: const Key('detail-summary-view'),
          children: [
            const VgrIcon(VgrIconName.check, size: 48),
            const VgrGap.md(),
            VgrText.headline('detail.summary.resolved'.tr()),
            if (view.resolvedAt != null) ...[
              const VgrGap.sm(),
              VgrText.caption(_when(view.resolvedAt!)),
            ],
          ],
        ),
      );
    }

    final what = view.category != null
        ? 'report.category.${view.category}'.tr()
        : (view.freeTag ?? '');
    return VgrScrollView(
      child: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VgrText.headline('$what · ${'report.subject.${view.subject}'.tr()}'),
          const VgrGap.sm(),
          if (view.access == ReportAccess.owner)
            VgrText.caption('detail.yours'.tr(), key: const Key('detail-owner-badge')),
          // Moderation mark (B2, decision 167): owner/participant only —
          // third parties never get a hidden case at all. No reason, no
          // action: the reason belongs to the audit trail, not to the
          // reporter.
          if (view.hidden &&
              (view.access == ReportAccess.owner ||
                  view.access == ReportAccess.participant)) ...[
            const VgrGap.sm(),
            VgrText.error('detail.hiddenNotice'.tr(), key: const Key('detail-hidden-notice')),
          ],
          VgrText.caption(view.status == 'resolved'
              ? 'detail.status.resolved'.tr()
              : 'detail.status.open'.tr()),
          if (view.createdAt != null) VgrText.caption(_when(view.createdAt!)),
          if (view.position != null) ...[
            const VgrGap.sm(),
            VgrRow(children: [
              const VgrIcon(VgrIconName.location, size: 16),
              const VgrGap.hSm(),
              // Public views carry the tier-DEGRADED grid point (135).
              VgrText.caption(
                view.access == ReportAccess.public
                    ? 'detail.positionApprox'.tr(namedArgs: {
                        'lat': view.position!.lat.toStringAsFixed(3),
                        'lng': view.position!.lng.toStringAsFixed(3),
                      })
                    : '${view.position!.lat.toStringAsFixed(6)}, '
                        '${view.position!.lng.toStringAsFixed(6)}',
              ),
            ]),
          ],
          if (view.detailFields != null && view.detailFields!.isNotEmpty) ...[
            const VgrGap.md(),
            VgrText.title('detail.fields'.tr()),
            for (final entry in view.detailFields!.entries)
              VgrText('${entry.key}: ${entry.value}'),
          ],
          if (view.media.isNotEmpty) ...[
            const VgrGap.md(),
            VgrText.title('report.photos.title'.tr()),
            const VgrGap.sm(),
            VgrWrap(children: [
              for (final media in view.media)
                VgrNetworkImage(
                  key: Key('detail-media-${media.publicId}'),
                  url: '${widget.mediaBaseUrl}/app-reports/${view.reportId}'
                      '/media/${media.publicId}/${view.thumbVariant}',
                  headers: clientKey == null ? null : {'x-client-key': clientKey},
                ),
            ]),
          ],
          if (view.timeline != null && view.timeline!.isNotEmpty) ...[
            const VgrGap.md(),
            VgrText.title('detail.timeline'.tr()),
            for (final event in view.timeline!)
              VgrListTile(
                dense: true,
                leadingIcon: VgrIconName.forward,
                title: 'detail.event.${event.eventType}'.tr(),
                subtitle: _when(event.createdAt),
              ),
          ],
          if (view.offers != null) ...[
            const VgrGap.md(),
            VgrText.title('detail.offers'.tr()),
            if (view.offers!.isEmpty)
              VgrText.caption('detail.noOffers'.tr())
            else
              for (final offer in view.offers!)
                VgrListTile(
                  key: Key('detail-offer-${offer.helpOfferId}'),
                  dense: true,
                  leadingIcon: VgrIconName.person,
                  // Identity only when the helper chose it AND the tier
                  // allows (6/40/60) — otherwise the anonymous label.
                  title: offer.helperDisplayName ?? 'detail.anonymousHelper'.tr(),
                  subtitle: offer.createdAt == null
                      ? 'detail.helpType.${offer.helpType}'.tr()
                      : '${'detail.helpType.${offer.helpType}'.tr()} · '
                          '${_when(offer.createdAt!)}',
                ),
          ],
          // Masked chat (C2, decision 169): the entry exists ONLY when the
          // server put `chat` on this view — owner → thread list, helper
          // participant → their conversation (created on the first
          // message when threadId is still null, 173).
          if (view.chat != null) ...[
            const VgrGap.lg(),
            VgrPrimaryButton(
              key: const Key('detail-chat-button'),
              icon: VgrIconName.chat,
              label: view.chat!.unread > 0
                  ? 'detail.chatUnread'.tr(namedArgs: {'count': '${view.chat!.unread}'})
                  : 'detail.chat'.tr(),
              onPressed: () => _openChat(view),
            ),
          ],
          // Offering help (A3, decisions 10/34/35): open cases only (18),
          // third parties only — the owner sees offers, never the button
          // (20), and a participant already offered (one per report).
          if (view.access == ReportAccess.public && view.status == 'open') ...[
            const VgrGap.lg(),
            VgrPrimaryButton(
              key: const Key('detail-offer-help-button'),
              label: 'detail.offerHelp'.tr(),
              onPressed: () => _offerHelp(view.reportId),
            ),
          ],
          const VgrGap.lg(),
        ],
      ),
    );
  }

  Future<void> _offerHelp(int reportId) async {
    if (widget.onOfferHelp != null) {
      widget.onOfferHelp!(reportId);
      return;
    }
    await Modular.to.pushNamed('/offer/$reportId');
    // A successful offer changed the case (timeline event) — reload so
    // the view reflects it.
    if (mounted) context.read<ReportDetailBloc>().add(DetailStarted(reportId));
  }

  Future<void> _openChat(ReportViewEntity view) async {
    final chat = view.chat!;
    final route = chat.isOwner
        ? '/chat/threads/${view.reportId}'
        : '/chat/${view.reportId}/thread/${chat.threadId ?? 'new'}';
    if (widget.onOpenChat != null) {
      widget.onOpenChat!(route);
      return;
    }
    await Modular.to.pushNamed(route);
    // Unread count changed while reading — reload the facet.
    if (mounted) context.read<ReportDetailBloc>().add(DetailStarted(view.reportId));
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
