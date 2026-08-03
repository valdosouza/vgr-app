import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/risk_config_bloc.dart';
import '../bloc/risk_config_event.dart';
import '../bloc/risk_config_state.dart';

class RiskConfigListPage extends StatelessWidget {
  const RiskConfigListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('riskConfig.title'.tr())),
      body: BlocBuilder<RiskConfigBloc, RiskConfigState>(
        builder: (context, state) {
          return switch (state) {
            RiskConfigLoading() => const Center(child: CircularProgressIndicator()),
            RiskConfigError(:final message) => Center(child: Text(message)),
            RiskConfigLoaded(:final items) => ListView(
                children: [
                  for (final item in items)
                    ListTile(
                      title: Text(item.category),
                      trailing: DropdownButton<RiskTier>(
                        key: Key('risk-tier-dropdown-${item.category}'),
                        value: item.tier,
                        items: [
                          for (final tier in RiskTier.values)
                            DropdownMenuItem(value: tier, child: Text(tier.name)),
                        ],
                        // can() wired per privilege (decisions 71/72 — UX
                        // only; the API enforces regardless).
                        onChanged: !SessionAccess.instance
                                .can('risk_config', Privileges.update)
                            ? null
                            : (tier) {
                                if (tier != null) {
                                  context.read<RiskConfigBloc>().add(
                                        TierEdited(category: item.category, tier: tier),
                                      );
                                }
                              },
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
