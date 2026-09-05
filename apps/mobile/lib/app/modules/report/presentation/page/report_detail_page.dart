import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../direction_sighting/domain/entity/direction_sighting_entities.dart';
import '../../domain/entity/report_view_entity.dart';
import '../bloc/report_detail_bloc.dart';

/// Client-side, NON-AUTHORITATIVE mirror of decision 201's SERVER-side
/// fixed eligibility list ("things that move" — `dynamic-radius.ts`'s own
/// subset). A UX hint ONLY: hides the picker for a category that would
/// always be refused with 422 DIRECTION_SIGHTING_NOT_ELIGIBLE server-side
/// anyway. NEVER trusted for anything beyond hiding a button — the server
/// enforces this independently and never consults the app's copy.
const _directionSightingEligibleCategories = {'robbery', 'kidnapping', 'fugitive', 'missing'};

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
          DetailLoaded(
            view: final view,
            clientKey: final clientKey,
            resolving: final resolving,
            ratingOfferId: final ratingOfferId,
            actionFailure: final actionFailure,
            sightedDirection: final sightedDirection,
            sighting: final sighting,
            sightFeedback: final sightFeedback,
          ) =>
            _loaded(view, clientKey, resolving, ratingOfferId, actionFailure, sightedDirection,
                sighting, sightFeedback),
        },
      ),
    );
  }

  Widget _loaded(
    ReportViewEntity view,
    String? clientKey,
    bool resolving,
    int? ratingOfferId,
    Failure? actionFailure,
    Direction? sightedDirection,
    bool sighting,
    DirectionSightingResult? sightFeedback,
  ) {
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
          ..._directionSightingSection(view, sightedDirection, sighting, sightFeedback),
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
                  trailing: _ratingControl(view, offer, ratingOfferId),
                ),
          ],
          // Owner-only close (RT2, decisions 18/131/179): no "outcome"
          // field, just this confirmation before the resolve call.
          if (view.access == ReportAccess.owner && view.status == 'open') ...[
            const VgrGap.lg(),
            VgrPrimaryButton(
              key: const Key('detail-resolve-button'),
              label: 'detail.resolve'.tr(),
              busy: resolving,
              onPressed: resolving ? null : () => _resolve(view.reportId),
            ),
          ],
          if (actionFailure != null) ...[
            const VgrGap.sm(),
            VgrText.error(failureText(actionFailure), key: const Key('detail-action-error')),
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

  /// Confirms before closing (179) — `showVgrConfirm` already exists for
  /// exactly this, never a hand-rolled dialog.
  Future<void> _resolve(int reportId) async {
    final confirmed = await showVgrConfirm(
      context,
      title: 'detail.resolveConfirmTitle'.tr(),
      message: 'detail.resolveConfirmMessage'.tr(),
      confirmLabel: 'detail.resolveConfirm'.tr(),
      cancelLabel: 'detail.resolveCancel'.tr(),
      confirmKey: const Key('detail-resolve-confirm'),
      cancelKey: const Key('detail-resolve-cancel'),
    );
    if (confirmed && mounted) {
      context.read<ReportDetailBloc>().add(const DetailResolvePressed());
    }
  }

  /// Direction sighting (DS2 — decisions 200-207). Two independent parts:
  /// the shared, floor-gated READ facet (202-204, `view.directionEstimate`
  /// — resolved entirely server-side, rendered whenever non-null
  /// regardless of category/access/status) and, ONLY for an eligible
  /// non-owner viewer of a still-open, eligible-category report, the
  /// picker to log a sighting of this device's own (200/201) — replaced
  /// by a read-only confirmation once logged (either just now, or in a
  /// previous session per `DirectionSightingLocalStore`'s soft, local-only
  /// record).
  List<Widget> _directionSightingSection(
    ReportViewEntity view,
    Direction? sightedDirection,
    bool sighting,
    DirectionSightingResult? sightFeedback,
  ) {
    final eligible = view.access != ReportAccess.owner &&
        view.status == 'open' &&
        _directionSightingEligibleCategories.contains(view.category);

    return [
      if (view.directionEstimate != null) ...[
        const VgrGap.sm(),
        VgrText.caption(
          'detail.directionEstimate'
              .tr(namedArgs: {'direction': _compassLabel(view.directionEstimate!)}),
          key: const Key('detail-direction-estimate'),
        ),
      ],
      if (eligible) ...[
        const VgrGap.md(),
        if (sightedDirection != null)
          VgrText.caption(
            'detail.directionSighted'
                .tr(namedArgs: {'direction': _compassLabel(sightedDirection)}),
            key: const Key('detail-direction-sighted'),
          )
        else ...[
          VgrText.title('detail.directionPrompt'.tr()),
          const VgrGap.sm(),
          VgrCompass(
            key: const Key('detail-direction-picker'),
            value: null,
            onChanged: sighting
                ? null
                : (code) => context.read<ReportDetailBloc>().add(
                      DetailSightPressed(DirectionJson.fromJson(code)),
                    ),
          ),
        ],
        if (sightFeedback?.estimate != null) ...[
          const VgrGap.sm(),
          VgrText.caption(
            'detail.directionFeedback'.tr(namedArgs: {
              'direction': _compassLabel(sightFeedback!.estimate!),
              'count': '${sightFeedback.count}',
            }),
            key: const Key('detail-direction-feedback'),
          ),
        ],
      ],
    ];
  }

  String _compassLabel(Direction direction) => 'compass.${direction.name}'.tr();

  /// The rating control per offer row (RT2, decisions 48/180-184) — shown
  /// ONLY on a resolved, owner-visible view, and only when the SERVER sent
  /// a `rating` facet for this offer; the app trusts `ratable` as-is and
  /// never recomputes the rule. Works both right after closing and on any
  /// later revisit (181), since the whole page reloads on `DetailStarted`.
  Widget? _ratingControl(ReportViewEntity view, OfferViewEntity offer, int? ratingOfferId) {
    if (view.access != ReportAccess.owner || view.status != 'resolved') return null;
    final rating = offer.rating;
    if (rating == null) return null;

    if (rating.ratable) {
      return VgrRating(
        key: Key('detail-offer-rating-${offer.helpOfferId}'),
        value: null,
        onChanged: ratingOfferId != null
            ? null
            : (score) => context.read<ReportDetailBloc>().add(
                  DetailRatePressed(offerId: offer.helpOfferId, score: score),
                ),
      );
    }
    if (rating.score != null) {
      return VgrRating(
        key: Key('detail-offer-rating-${offer.helpOfferId}'),
        value: rating.score,
        onChanged: null,
      );
    }
    // ratable == false and no score: the helper had no account (180) —
    // nothing to show.
    return null;
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
