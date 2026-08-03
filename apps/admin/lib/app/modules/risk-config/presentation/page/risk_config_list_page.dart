import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/risk_config_bloc.dart';
import '../bloc/risk_config_event.dart';
import '../bloc/risk_config_state.dart';

class RiskConfigListPage extends StatelessWidget {
  const RiskConfigListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'riskConfig.title'.tr(),
      padded: false,
      body: BlocBuilder<RiskConfigBloc, RiskConfigState>(
        builder: (context, state) {
          return switch (state) {
            RiskConfigLoading() => const VgrLoading(),
            RiskConfigError(:final message) => VgrCenter(child: VgrText.error(message)),
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
