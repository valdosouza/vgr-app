import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/feedback/feedback.dart';
import '../../domain/entity/dual_control_access_request_entity.dart';
import '../bloc/dual_control_access_bloc.dart';
import '../bloc/dual_control_access_event.dart';
import '../bloc/dual_control_access_state.dart';

class DualControlRequestPage extends StatefulWidget {
  const DualControlRequestPage({super.key});

  @override
  State<DualControlRequestPage> createState() => _DualControlRequestPageState();
}

class _DualControlRequestPageState extends State<DualControlRequestPage> {
  final _accountabilityLogEntryIdController = TextEditingController();
  final _legalBasisController = TextEditingController();
  final _approverIdController = TextEditingController();

  @override
  void dispose() {
    _accountabilityLogEntryIdController.dispose();
    _legalBasisController.dispose();
    _approverIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VgrPage(
      title: 'dualControl.title'.tr(),
      body: BlocConsumer<DualControlAccessBloc, DualControlAccessState>(
        // Refusals go through the feedback bridge (decision 221); the screen
        // stays on the step it was on.
        listenWhen: (_, state) => state is DualControlActionFailed,
        listener: (context, state) => showFailureFeedback(context, (state as DualControlActionFailed).failure),
        buildWhen: (_, state) => state is! DualControlActionFailed,
        builder: (context, state) {
          return switch (state) {
            DualControlInitial() => _RequestForm(
                accountabilityLogEntryIdController: _accountabilityLogEntryIdController,
                legalBasisController: _legalBasisController,
              ),
            // One-shot — never reaches the builder (buildWhen).
            DualControlActionFailed() => const VgrLoading(),
            DualControlProgress(:final entity) => _ApprovalProgress(
                entity: entity,
                approverIdController: _approverIdController,
              ),
            DualControlActionSuccess(:final entity) => VgrColumn(
                children: [
                  VgrText('dualControl.granted'.tr()),
                  VgrText('dualControl.legalBasis'.tr(args: [entity.legalBasis])),
                  VgrText('dualControl.approvers'.tr(args: [entity.approverIds.join(', ')])),
                ],
              ),
          };
        },
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.accountabilityLogEntryIdController,
    required this.legalBasisController,
  });

  final TextEditingController accountabilityLogEntryIdController;
  final TextEditingController legalBasisController;

  @override
  Widget build(BuildContext context) {
    return VgrColumn(
      children: [
        VgrTextField(
          key: const Key('accountability-log-entry-id-field'),
          controller: accountabilityLogEntryIdController,
          label: 'dualControl.logEntryId'.tr(),
          keyboard: VgrKeyboard.number,
        ),
        VgrTextField(
          key: const Key('legal-basis-field'),
          controller: legalBasisController,
          label: 'dualControl.legalBasisField'.tr(),
        ),
        VgrPrimaryButton(
          key: const Key('start-request-button'),
          label: 'dualControl.startRequest'.tr(),
          // Starting a request inserts it; approving (below) updates it.
          onPressed: !SessionAccess.instance.can('dual_control_access', Privileges.insert)
              ? null
              : () {
                  // Both are mandatory; a missing one used to be dropped in
                  // silence — now it is the form's one pendency.
                  final id = int.tryParse(accountabilityLogEntryIdController.text.trim());
                  final missing = id == null
                      ? 'dualControl.logEntryId'.tr()
                      : legalBasisController.text.trim().isEmpty
                          ? 'dualControl.legalBasisField'.tr()
                          : null;
                  if (missing != null) {
                    showValidationFeedback(context, '$missing: ${'core.fieldErrors.REQUIRED'.tr()}');
                    return;
                  }
                  context.read<DualControlAccessBloc>().add(
                        RequestSubmitted(
                          accountabilityLogEntryId: id!,
                          legalBasis: legalBasisController.text.trim(),
                        ),
                      );
                },
        ),
      ],
    );
  }
}

class _ApprovalProgress extends StatelessWidget {
  const _ApprovalProgress({required this.entity, required this.approverIdController});

  final DualControlAccessRequestEntity entity;
  final TextEditingController approverIdController;

  @override
  Widget build(BuildContext context) {
    // Layered like the API (decisions 45/93): approving needs the screen's
    // UPDATE and the approver kind-'R' resource.
    final canApprove = SessionAccess.instance.can('dual_control_access', Privileges.update) &&
        SessionAccess.instance.can('dual_control_approval', Privileges.update);

    return VgrColumn(
      children: [
        VgrText('dualControl.legalBasis'.tr(args: [entity.legalBasis])),
        VgrText('dualControl.approvals'.tr(args: ['${entity.approverIds.length}'])),
        VgrTextField(
          key: const Key('approver-id-field'),
          controller: approverIdController,
          label: 'dualControl.approverId'.tr(),
        ),
        VgrPrimaryButton(
          key: const Key('add-approval-button'),
          label: 'dualControl.approve'.tr(),
          onPressed: !canApprove
              ? null
              : () {
                  if (approverIdController.text.trim().isEmpty) {
                    showValidationFeedback(
                      context,
                      '${'dualControl.approverId'.tr()}: ${'core.fieldErrors.REQUIRED'.tr()}',
                    );
                    return;
                  }
                  context
                      .read<DualControlAccessBloc>()
                      .add(ApprovalSubmitted(approverId: approverIdController.text.trim()));
                },
        ),
      ],
    );
  }
}
