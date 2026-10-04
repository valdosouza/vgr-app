import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../bloc/risk_config_bloc.dart';
import '../bloc/risk_config_event.dart';
import '../bloc/risk_config_state.dart';

class RiskConfigListPage extends StatelessWidget {
  const RiskConfigListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return VgrPage(
      title: 'riskConfig.title'.tr(),
      padded: false,
      body: BlocConsumer<RiskConfigBloc, RiskConfigState>(
        // Edits answer through the feedback bridge (decision 221); the
        // list never gives way to an error screen because of one.
        listenWhen: (_, state) => state is RiskConfigActionFailed || state is RiskConfigActionSucceeded,
        listener: (context, state) => switch (state) {
          RiskConfigActionFailed(:final failure) => showFailureFeedback(context, failure),
          _ => showSuccessFeedback(context, 'register.saved'.tr()),
        },
        buildWhen: (_, state) => state is! RiskConfigActionFailed && state is! RiskConfigActionSucceeded,
        builder: (context, state) {
          return switch (state) {
            RiskConfigLoading() => const VgrLoading(),
            RiskConfigError(:final failure) => VgrCenter(
                child: VgrColumn(children: [
                  VgrText.error(failureText(failure), key: const Key('catalog-load-error')),
                  const VgrGap.md(),
                  VgrSecondaryButton(
                    key: const Key('catalog-retry-button'),
                    label: 'register.retry'.tr(),
                    onPressed: () => context.read<RiskConfigBloc>().add(const FetchRequested()),
                  ),
                ]),
              ),
            // One-shots never reach the builder (buildWhen).
            RiskConfigActionFailed() || RiskConfigActionSucceeded() => const VgrLoading(),
            RiskConfigLoaded(:final items) => VgrListView(
                children: [
                  for (final item in items)
                    VgrListTile(
                      title: item.category,
                      trailing: VgrDropdown<RiskTier>(
                        key: Key('risk-tier-dropdown-${item.category}'),
                        value: item.tier,
                        options: [
                          for (final tier in RiskTier.values)
                            VgrOption(value: tier, label: tier.name),
                        ],
                        // can() wired per privilege (decisions 71/72 — UX
                        // only; the API enforces regardless).
                        onChanged: !SessionAccess.instance.can('risk_config', Privileges.update)
                            ? null
                            : (tier) => context
                                .read<RiskConfigBloc>()
                                .add(TierEdited(category: item.category, tier: tier)),
                      ),
                    ),
                ],
              ),
          };
        },
      ),
    );
  }
}
