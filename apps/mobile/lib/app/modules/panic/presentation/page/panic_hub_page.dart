import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/panic_hub_bloc.dart';

/// The panic button (decisions 62/65/191/196-198): a cold trigger, no
/// prior configuration, reachable from the feed's action at any time.
/// Confirmation lives HERE (`showVgrConfirm`, `destructive: true` — the
/// same widget RT2 used for closing a report) — the bloc only ever sees
/// `PanicTriggerPressed` after the user already confirmed.
class PanicHubPage extends StatefulWidget {
  const PanicHubPage({super.key});

  @override
  State<PanicHubPage> createState() => _PanicHubPageState();
}

class _PanicHubPageState extends State<PanicHubPage> {
  @override
  void initState() {
    super.initState();
    context.read<PanicHubBloc>().add(const PanicHubStarted());
  }

  Future<void> _trigger() async {
    final confirmed = await showVgrConfirm(
      context,
      title: 'panic.hub.confirmTitle'.tr(),
      message: 'panic.hub.confirmMessage'.tr(),
      confirmLabel: 'panic.hub.confirmConfirm'.tr(),
      cancelLabel: 'panic.hub.confirmCancel'.tr(),
      destructive: true,
      confirmKey: const Key('panic-hub-confirm-confirm'),
      cancelKey: const Key('panic-hub-confirm-cancel'),
    );
    if (confirmed && mounted) {
      context.read<PanicHubBloc>().add(const PanicTriggerPressed());
    }
  }

  // No confirmation gate on resolve (unlike the trigger): calming a false
  // alarm down should never carry extra friction (decision 197).
  void _resolve() => context.read<PanicHubBloc>().add(const PanicResolvePressed());

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'panic.hub.title'.tr(),
      body: BlocBuilder<PanicHubBloc, PanicHubState>(
        builder: (context, state) => switch (state.phase) {
          PanicPhase.loading => const VgrLoading(),
          _ => _content(state),
        },
      ),
    );
  }

  Widget _content(PanicHubState state) {
    final active = state.phase == PanicPhase.active || state.phase == PanicPhase.resolving;
    return VgrCenter(
      child: VgrColumn(
        children: [
          const VgrIcon(VgrIconName.panic, size: 64),
          const VgrGap.md(),
          if (state.failure != null) ...[
            VgrText.error(failureText(state.failure!), key: const Key('panic-hub-error')),
            const VgrGap.md(),
          ],
          if (active)
            ..._activeSection(state)
          else
            _idleSection(state.phase == PanicPhase.triggering),
        ],
      ),
    );
  }

  List<Widget> _activeSection(PanicHubState state) {
    final hasAlertId = state.alertId != null;
    final busyResolve = state.phase == PanicPhase.resolving;
    return [
      VgrText.headline('panic.hub.activeTitle'.tr(), key: const Key('panic-hub-active-title')),
      const VgrGap.sm(),
      if (!hasAlertId)
        // Decision 28: a queued trigger is a success, not an error — but
        // there is nothing to resolve server-side yet.
        VgrText.caption('panic.hub.activeQueued'.tr(), key: const Key('panic-hub-queued-caption'))
      else if (state.recipientCount != null)
        VgrText.caption(
          'panic.hub.activeNotified'.tr(namedArgs: {'count': '${state.recipientCount}'}),
          key: const Key('panic-hub-active-notified'),
        )
      else
        // A remembered alert from a previous app session never carries a
        // count — no PP1 endpoint reconstructs it (see the repository's
        // doc comment).
        VgrText.caption('panic.hub.activeNoCount'.tr(), key: const Key('panic-hub-active-notified')),
      const VgrGap.lg(),
      if (hasAlertId)
        VgrPrimaryButton(
          key: const Key('panic-hub-resolve-button'),
          label: 'panic.hub.resolve'.tr(),
          busy: busyResolve,
          onPressed: busyResolve ? null : _resolve,
        ),
    ];
  }

  Widget _idleSection(bool busy) => VgrPrimaryButton(
        key: const Key('panic-hub-trigger-button'),
        label: 'panic.hub.trigger'.tr(),
        icon: VgrIconName.panic,
        busy: busy,
        onPressed: busy ? null : _trigger,
      );
}
