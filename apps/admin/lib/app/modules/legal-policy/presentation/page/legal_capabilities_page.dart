import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/capabilities_bloc.dart';

/// Capability catalog for ONE jurisdiction (decision 103): the verdict
/// the gate would give today — `unreviewed` rendered as the block it is
/// in a real jurisdiction (fail-closed, principle L1).
class LegalCapabilitiesPage extends StatefulWidget {
  const LegalCapabilitiesPage({super.key});

  @override
  State<LegalCapabilitiesPage> createState() => _LegalCapabilitiesPageState();
}

class _LegalCapabilitiesPageState extends State<LegalCapabilitiesPage> {
  final _jurisdictionController = TextEditingController();

  @override
  void dispose() {
    _jurisdictionController.dispose();
    super.dispose();
  }

  void _load() {
    final code = _jurisdictionController.text.trim().toUpperCase();
    if (code.length < 2) return;
    context.read<CapabilitiesBloc>().add(CapabilitiesRequested(code));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'legal.capabilities.title'.tr(),
      body: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VgrRow(children: [
            VgrExpanded(
              child: VgrTextField(
                key: const Key('capabilities-jurisdiction-field'),
                controller: _jurisdictionController,
                label: 'legal.capabilities.jurisdiction'.tr(),
                onSubmitted: (_) => _load(),
              ),
            ),
            const VgrGap.hSm(),
            VgrPrimaryButton(
              key: const Key('capabilities-load-button'),
              label: 'legal.capabilities.load'.tr(),
              onPressed: _load,
            ),
          ]),
          const VgrGap.md(),
          VgrExpanded(
            child: BlocBuilder<CapabilitiesBloc, CapabilitiesState>(
              builder: (context, state) => switch (state) {
                CapabilitiesInitial() =>
                  VgrText.caption('legal.capabilities.hint'.tr()),
                CapabilitiesLoading() => const VgrLoading(),
                CapabilitiesError(:final failure) => VgrText.error(
                    failureText(failure),
                    key: const Key('capabilities-error')),
                CapabilitiesLoaded(:final rows) => VgrListView(
                    children: [
                      for (final row in rows)
                        VgrListTile(
                          key: Key('capability-${row.capability}'),
                          title: '${row.capability} · '
                              '${'legal.status.${row.effectiveStatus}'.tr()}',
                          subtitle: row.activeRuleVersion == null
                              ? row.description
                              : '${row.description} · '
                                  '${'legal.capabilities.ruleSummary'.tr(namedArgs: {
                                    'version': '${row.activeRuleVersion}',
                                    'review':
                                        'legal.review.${row.activeRuleReviewState}'.tr(),
                                  })}',
                        ),
                    ],
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
