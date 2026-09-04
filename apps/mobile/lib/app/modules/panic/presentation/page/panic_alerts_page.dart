import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/panic_entities.dart';
import '../bloc/panic_alerts_bloc.dart';

/// The responder's own alerts inbox (192 — polling only, no push).
/// `WidgetsBindingObserver` toggles polling with the app lifecycle, the
/// exact shape `chat_conversation_page.dart` already established.
class PanicAlertsPage extends StatefulWidget {
  const PanicAlertsPage({super.key});

  @override
  State<PanicAlertsPage> createState() => _PanicAlertsPageState();
}

class _PanicAlertsPageState extends State<PanicAlertsPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PanicAlertsBloc>().add(const PanicAlertsStarted());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = context.read<PanicAlertsBloc>();
    if (state == AppLifecycleState.resumed) {
      bloc.add(const PanicAlertsResumed());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      bloc.add(const PanicAlertsPaused());
    }
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'panic.alerts.title'.tr(),
      padded: false,
      body: BlocBuilder<PanicAlertsBloc, PanicAlertsState>(
        builder: (context, state) => switch (state) {
          PanicAlertsLoading() => const VgrLoading(),
          PanicAlertsError(failure: final failure) => VgrCenter(
              child: VgrColumn(children: [
                VgrText.error(failureText(failure), key: const Key('panic-alerts-error')),
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('panic-alerts-retry-button'),
                  label: 'panic.alerts.retry'.tr(),
                  onPressed: () =>
                      context.read<PanicAlertsBloc>().add(const PanicAlertsStarted()),
                ),
              ]),
            ),
          PanicAlertsLoaded(alerts: final alerts) => alerts.isEmpty
              ? VgrCenter(
                  child: VgrText.caption(
                    'panic.alerts.empty'.tr(),
                    key: const Key('panic-alerts-empty'),
                  ),
                )
              : VgrListView(children: [
                  for (final alert in alerts) _AlertTile(alert: alert),
                ]),
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final ResponderAlertEntity alert;

  @override
  Widget build(BuildContext context) {
    // Fixed client-side template (decision 196) — the API never stores or
    // serves any free text for a panic alert; this rendering, built from
    // {alertId, distanceKm} only, is the ONLY message a responder ever
    // sees. Read only: a responder can never resolve someone else's
    // alert (197), so no action button on this row.
    final distance = alert.distanceKm.toStringAsFixed(1);
    return VgrListTile(
      key: Key('panic-alert-${alert.alertId}'),
      leadingIcon: VgrIconName.panic,
      title: 'panic.alerts.template'.tr(namedArgs: {'distance': distance}),
      subtitle: alert.resolved
          ? '${'panic.alerts.resolved'.tr()} · ${_when(alert.createdAt)}'
          : _when(alert.createdAt),
    );
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
