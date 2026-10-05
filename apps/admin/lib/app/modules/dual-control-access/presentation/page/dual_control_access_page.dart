import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/register_field.dart';
import '../../../../shared/register/register_screen.dart';
import '../../../../shared/register/register_search_page.dart' show RegisterRow;
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/dual_control_request_entity.dart';
import '../bloc/dual_control_bloc.dart';

/// The decision 45 gate on the register factory (decision 227 — the design
/// of the Legal Gate rules): the requests paged newest first and filtered
/// by legal basis (220); "new" opens the request form (INSERT) — what is
/// asked and why, never who asks; a pending row carries "Approve" (UPDATE
/// on the screen AND the `dual_control_approval` resource, 45/93). Rows
/// never open: a request is never edited.
///
/// Both people come from the session (223): "Approve" is disabled on the
/// requests [sessionUserId] opened — one approval by ANOTHER user grants
/// (224). UX only: the API judges the same session and refuses with 422,
/// which would arrive through the bridge.
class DualControlAccessPage extends StatelessWidget {
  const DualControlAccessPage({super.key, required this.sessionUserId});

  /// The signed-in user as the API sees them (`sessionUserIdOf` the
  /// session token); null when unknown — the API still decides.
  final int? sessionUserId;

  static const screen = CurrentInterface('dual_control_access');
  static const approval = CurrentInterface('dual_control_approval');

  /// The panel team by name (227); a blank name (the seed bootstrap leaves
  /// it empty) or a voided request with no requester reads as a dash —
  /// never an e-mail.
  static String _name(String? name) => name == null || name.trim().isEmpty ? '—' : name;

  @override
  Widget build(BuildContext context) {
    final canApprove = screen.canUpdate && approval.canUpdate;

    return RegisterScreen<DualControlRequestEntity, DualControlRequestDraft>(
      title: 'dualControl.title'.tr(),
      screen: screen,
      openRows: false,
      rowId: (request) => request.id,
      rowBuilder: (context, request) {
        final ownRequest = sessionUserId != null && request.requestedBy == sessionUserId;
        return RegisterRow(
          title: 'dualControl.rowTitle'.tr(namedArgs: {
            'id': '${request.id}',
            'entry': '${request.accountabilityLogEntryId}',
          }),
          leadingIcon: VgrIconName.security,
          subtitleWidget: VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrText(
                'dualControl.status.${request.status}'.tr(),
                key: Key('dual-control-status-${request.id}'),
              ),
              VgrText.caption(request.legalBasis),
              VgrText.caption(
                'dualControl.requestedBy'.tr(namedArgs: {
                  'name': _name(request.requestedByName),
                  'when': formatLocalDateTime(request.createdAt),
                }),
                key: Key('dual-control-requested-${request.id}'),
              ),
              if (request.approvedBy != null)
                VgrText.caption(
                  'dualControl.approvedBy'.tr(namedArgs: {
                    'name': _name(request.approvedByName),
                    'when': formatLocalDateTime(request.approvedAt),
                  }),
                  key: Key('dual-control-approved-${request.id}'),
                ),
              if (request.isPending) ...[
                VgrPrimaryButton(
                  key: Key('dual-control-approve-${request.id}'),
                  label: 'dualControl.approve'.tr(),
                  onPressed: !canApprove || ownRequest
                      ? null
                      : () => context.read<DualControlRegisterBloc>().add(DualControlApproved(request.id)),
                ),
                if (ownRequest)
                  VgrText.caption(
                    'dualControl.ownRequest'.tr(),
                    key: Key('dual-control-own-${request.id}'),
                  ),
              ],
            ],
          ),
        );
      },
      formTitle: (_) => 'dualControl.requestTitle'.tr(),
      fields: (_) => [
        // Mirrors dualControlCreateDto (decision 154).
        RegisterTextField(
          name: 'accountabilityLogEntryId',
          label: 'dualControl.logEntryId'.tr(),
          keyboard: VgrKeyboard.number,
          validators: [VgrValidators.positiveInteger],
        ),
        RegisterTextField(
          name: 'legalBasis',
          label: 'dualControl.legalBasis'.tr(),
          hint: 'dualControl.legalBasisHint'.tr(),
          validators: [VgrValidators.required, VgrValidators.maxLength(500)],
        ),
      ],
      draftOf: (_, values) => DualControlRequestDraft(
        accountabilityLogEntryId: int.parse(values.text('accountabilityLogEntryId').trim()),
        legalBasis: values.text('legalBasis').trim(),
      ),
    );
  }
}
