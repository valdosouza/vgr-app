import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/paged_list_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/legal_policy_entities.dart';
import '../bloc/jurisdictions_bloc.dart';

const _states = ['live', 'restricted', 'suspended'];

/// Kill-switch screen (decision 107): "shut down fast, turn back on
/// slowly" — tightening applies immediately, loosening renders as a
/// pending state a DIFFERENT user confirms (dual control). Paged and
/// filtered by code / name (decision 220); refusals reach the user through
/// the feedback bridge (221).
class LegalJurisdictionsPage extends StatelessWidget {
  const LegalJurisdictionsPage({super.key});

  static const screen = CurrentInterface('legal_jurisdictions');

  /// Confirming a loosening is the dual-control half (decision 93's 'R'
  /// resource) on top of the screen's UPDATE.
  static const dualControl = CurrentInterface('dual_control_approval');

  @override
  Widget build(BuildContext context) {
    final canUpdate = screen.canUpdate;
    final canConfirm = canUpdate && dualControl.canUpdate;

    return PagedListScreen<JurisdictionEntity, JurisdictionsBloc>(
      title: 'legal.jurisdictions.title'.tr(),
      rowId: (row) => row.code,
      rowBuilder: (context, row) => RegisterRow(
        title: row.isSandbox
            ? '${row.code} · ${row.name} — ${'legal.jurisdictions.sandbox'.tr()}'
            : '${row.code} · ${row.name}',
        leadingIcon: VgrIconName.legal,
        subtitleWidget: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VgrRow(children: [
              VgrText('legal.state.${row.operationalState}'.tr()),
              const VgrGap.hSm(),
              VgrDropdown<String>(
                key: Key('jurisdiction-state-${row.code}'),
                value: row.operationalState,
                options: [
                  for (final state in _states)
                    VgrOption(value: state, label: 'legal.state.$state'.tr()),
                ],
                onChanged: !canUpdate
                    ? null
                    : (state) {
                        if (state == row.operationalState) return;
                        context.read<JurisdictionsBloc>().add(JurisdictionStateRequested(row.code, state));
                      },
              ),
            ]),
            if (row.pendingState != null) ...[
              // Loosening waits here (107): the proposer's own confirm is
              // refused server-side.
              VgrText.caption(
                'legal.jurisdictions.pending'.tr(namedArgs: {
                  'state': 'legal.state.${row.pendingState}'.tr(),
                  'user': '${row.pendingBy}',
                }),
                key: Key('jurisdiction-pending-${row.code}'),
              ),
              const VgrGap.xs(),
              VgrPrimaryButton(
                key: Key('jurisdiction-confirm-${row.code}'),
                label: 'legal.jurisdictions.confirm'.tr(),
                onPressed: !canConfirm
                    ? null
                    : () => context.read<JurisdictionsBloc>().add(JurisdictionStateConfirmed(row.code)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
