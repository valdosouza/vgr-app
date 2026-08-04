import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/report_view_entity.dart';
import '../bloc/report_detail_bloc.dart';

/// Report detail (spec task 22, decision 50). The SERVER resolves what
/// this viewer may see — the page renders strictly by `access` and never
/// tries to show more than it received.
class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({super.key, required this.reportId, required this.mediaBaseUrl});

  final int reportId;

  /// Base URL for media streams (`GET /app-reports/:id/media/...`).
  final String mediaBaseUrl;

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
          const VgrGap.lg(),
        ],
      ),
    );
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
