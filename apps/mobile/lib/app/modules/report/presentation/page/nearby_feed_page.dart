import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/feed_item_entity.dart';
import '../bloc/nearby_feed_bloc.dart';
import '../bloc/nearby_feed_event.dart';
import '../bloc/nearby_feed_state.dart';

/// Nearby feed — the app's home (spec task 08, decisions 2/21/135).
/// Everything shown is tier-degraded by the API; the screen renders what
/// it gets and adds nothing.
class NearbyFeedPage extends StatefulWidget {
  const NearbyFeedPage({super.key, this.onOpenReport, this.onNewReport, this.onOpenPanic});

  /// Test seams — default navigation goes through Modular.
  final void Function(int reportId)? onOpenReport;
  final VoidCallback? onNewReport;

  /// The panic button is independent of the report flow, reachable from
  /// this menu at ANY time (decision 62) — the feed is the one screen
  /// every user, including a fully anonymous one, always reaches.
  final VoidCallback? onOpenPanic;

  @override
  State<NearbyFeedPage> createState() => _NearbyFeedPageState();
}

class _NearbyFeedPageState extends State<NearbyFeedPage> {
  @override
  void initState() {
    super.initState();
    context.read<NearbyFeedBloc>().add(const FeedStarted());
  }

  void _openReport(int reportId) => widget.onOpenReport != null
      ? widget.onOpenReport!(reportId)
      : Modular.to.pushNamed('/detail/$reportId');

  void _newReport() =>
      widget.onNewReport != null ? widget.onNewReport!() : Modular.to.pushNamed('/new');

  void _openPanic() =>
      widget.onOpenPanic != null ? widget.onOpenPanic!() : Modular.to.pushNamed('/panic/');

  @override
  Widget build(BuildContext context) {
    // Auth is optional and never blocks reporting (decision 123) — this is
    // just the entry point into it, identified vs anonymous.
    final identified = context.watch<IdentityBloc>().state.token != null;

    return VgrScaffold(
      title: 'feed.title'.tr(),
      padded: false,
      actions: [
        // The ONE required entry point (decision 62 — "reachable at any
        // time"): the feed is the one screen every user, including a
        // fully anonymous one, always reaches.
        VgrIconButton(
          key: const Key('feed-panic-button'),
          icon: VgrIconName.panic,
          tooltip: 'panic.hub.title'.tr(),
          onPressed: _openPanic,
        ),
        VgrIconButton(
          key: Key(identified ? 'feed-account-button' : 'feed-login-button'),
          icon: VgrIconName.person,
          tooltip: identified ? 'auth.account.title'.tr() : 'auth.login.title'.tr(),
          onPressed: () =>
              Modular.to.pushNamed(identified ? '/auth/account/' : '/auth/login/'),
        ),
      ],
      // "A denúncia nunca espera" (decision 123): submitting is always one
      // tap away from the home screen.
      floatingAction: VgrFloatingAddButton(
        key: const Key('feed-new-report-button'),
        tooltip: 'feed.newReport'.tr(),
        onPressed: _newReport,
      ),
      body: BlocBuilder<NearbyFeedBloc, NearbyFeedState>(
        builder: (context, state) => switch (state) {
          FeedLoading() => const VgrLoading(),
          FeedEmpty() => VgrCenter(
              child: VgrPadding(
                child: VgrColumn(children: [
                  VgrText('feed.empty'.tr(), key: const Key('feed-empty')),
                  const VgrGap.md(),
                  _retryButton(context),
                ]),
              ),
            ),
          FeedError(failure: final failure) => VgrCenter(
              child: VgrPadding(
                child: VgrColumn(children: [
                  VgrText.error(failureText(failure), key: const Key('feed-error')),
                  const VgrGap.md(),
                  _retryButton(context),
                ]),
              ),
            ),
          FeedLoaded() => _loaded(context, state),
        },
      ),
    );
  }

  Widget _retryButton(BuildContext context) => VgrSecondaryButton(
        key: const Key('feed-retry-button'),
        label: 'feed.retry'.tr(),
        onPressed: () => context.read<NearbyFeedBloc>().add(const FeedStarted()),
      );

  Widget _loaded(BuildContext context, FeedLoaded state) {
    return VgrListView(children: [
      VgrPadding(
        child: VgrRow(children: [
          VgrText.caption('feed.orderLabel'.tr()),
          const VgrGap.hSm(),
          VgrDropdown<FeedOrder>(
            key: const Key('feed-order-dropdown'),
            value: state.order,
            options: [
              VgrOption(value: FeedOrder.recency, label: 'feed.order.recency'.tr()),
              VgrOption(value: FeedOrder.relevance, label: 'feed.order.relevance'.tr()),
            ],
            onChanged: (order) =>
                context.read<NearbyFeedBloc>().add(FeedOrderChanged(order)),
          ),
        ]),
      ),
      for (final item in state.items) _FeedTile(item: item, onTap: _openReport),
      if (state.hasMore)
        VgrPadding(
          child: VgrSecondaryButton(
            key: const Key('feed-load-more-button'),
            label: state.loadingMore ? 'feed.loading'.tr() : 'feed.loadMore'.tr(),
            onPressed: state.loadingMore
                ? null
                : () =>
                    context.read<NearbyFeedBloc>().add(const FeedNextPageRequested()),
          ),
        ),
    ]);
  }
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.item, required this.onTap});

  final FeedItemEntity item;
  final void Function(int reportId) onTap;

  @override
  Widget build(BuildContext context) {
    final what = item.category != null
        ? 'report.category.${item.category}'.tr()
        : (item.freeTag ?? '');
    final when = item.createdAt.replaceFirst('T', ' ').substring(0, 16);
    return VgrListTile(
      key: Key('feed-item-${item.reportId}'),
      leadingIcon: VgrIconName.alert,
      title: '$what · ${'report.subject.${item.subject}'.tr()}',
      // Distance and time arrive DEGRADED by tier (decision 135) — shown
      // as approximations on purpose.
      subtitle: 'feed.itemSubtitle'
          .tr(namedArgs: {'distance': item.distanceKm.toString(), 'when': when}),
      onTap: () => onTap(item.reportId),
    );
  }
}
