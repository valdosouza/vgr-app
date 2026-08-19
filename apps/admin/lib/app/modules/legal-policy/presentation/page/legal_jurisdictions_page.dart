import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/legal_policy_entities.dart';
import '../bloc/jurisdictions_bloc.dart';

const _states = ['live', 'restricted', 'suspended'];

/// Kill-switch screen (decision 107): "shut down fast, turn back on
/// slowly" — tightening applies immediately, loosening renders as a
/// pending state a DIFFERENT user confirms (dual control).
class LegalJurisdictionsPage extends StatefulWidget {
  const LegalJurisdictionsPage({super.key});

  @override
  State<LegalJurisdictionsPage> createState() => _LegalJurisdictionsPageState();
}

class _LegalJurisdictionsPageState extends State<LegalJurisdictionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<JurisdictionsBloc>().add(const JurisdictionsRequested());
  }

  @override
  Widget build(BuildContext context) {
    final canUpdate =
        SessionAccess.instance.can('legal_jurisdictions', Privileges.update);
    final canConfirm = canUpdate &&
        SessionAccess.instance.can('dual_control_approval', Privileges.update);

    return VgrScaffold(
      title: 'legal.jurisdictions.title'.tr(),
      body: BlocBuilder<JurisdictionsBloc, JurisdictionsState>(
        builder: (context, state) => switch (state) {
          JurisdictionsLoading() => const VgrLoading(),
          JurisdictionsError(:final failure) => VgrCenter(
              child: VgrColumn(children: [
                VgrText.error(failureText(failure),
                    key: const Key('jurisdictions-error')),
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('jurisdictions-retry-button'),
                  label: 'legal.retry'.tr(),
                  onPressed: () => context
                      .read<JurisdictionsBloc>()
                      .add(const JurisdictionsRequested()),
                ),
              ]),
            ),
          JurisdictionsLoaded(:final rows, :final failure) =>
            _loaded(rows, failure, canUpdate: canUpdate, canConfirm: canConfirm),
        },
      ),
    );
  }

  Widget _loaded(
    List<JurisdictionEntity> rows,
    Failure? failure, {
    required bool canUpdate,
    required bool canConfirm,
  }) {
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (failure != null) ...[
          VgrText.error(failureText(failure),
              key: const Key('jurisdictions-action-error')),
          const VgrGap.sm(),
        ],
        VgrExpanded(
          child: VgrListView(
            children: [
              for (final row in rows)
                VgrCard(
                  child: VgrPadding(
                    child: VgrColumn(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VgrText.title(row.isSandbox
                            ? '${row.code} · ${row.name} — '
                                '${'legal.jurisdictions.sandbox'.tr()}'
                            : '${row.code} · ${row.name}'),
                        VgrRow(children: [
                          VgrText('legal.state.${row.operationalState}'.tr()),
                          const VgrGap.hSm(),
                          VgrDropdown<String>(
                            key: Key('jurisdiction-state-${row.code}'),
                            value: row.operationalState,
                            options: [
                              for (final state in _states)
                                VgrOption(
                                    value: state,
                                    label: 'legal.state.$state'.tr()),
                            ],
                            onChanged: !canUpdate
                                ? null
                                : (state) {
                                    if (state == row.operationalState) return;
                                    context.read<JurisdictionsBloc>().add(
                                        JurisdictionStateRequested(
                                            row.code, state));
                                  },
                          ),
                        ]),
                        if (row.pendingState != null) ...[
                          const VgrGap.sm(),
                          // Loosening waits here (107): the proposer's own
                          // confirm is refused server-side.
                          VgrText.caption(
                            'legal.jurisdictions.pending'.tr(namedArgs: {
                              'state': 'legal.state.${row.pendingState}'.tr(),
                              'user': '${row.pendingBy}',
                            }),
                            key: Key('jurisdiction-pending-${row.code}'),
                          ),
                          const VgrGap.sm(),
                          VgrPrimaryButton(
                            key: Key('jurisdiction-confirm-${row.code}'),
                            label: 'legal.jurisdictions.confirm'.tr(),
                            onPressed: !canConfirm
                                ? null
                                : () => context
                                    .read<JurisdictionsBloc>()
                                    .add(JurisdictionStateConfirmed(row.code)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
