import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('dualControl.title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<DualControlAccessBloc, DualControlAccessState>(
          builder: (context, state) {
            return switch (state) {
              DualControlInitial() => _RequestForm(
                  accountabilityLogEntryIdController: _accountabilityLogEntryIdController,
                  legalBasisController: _legalBasisController,
                ),
              DualControlError(:final message) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message),
                    _RequestForm(
                      accountabilityLogEntryIdController: _accountabilityLogEntryIdController,
                      legalBasisController: _legalBasisController,
                      approverIdController: _approverIdController,
                      showApprovalSection: true,
                    ),
                  ],
                ),
              DualControlProgress(:final entity) => _ApprovalProgress(
                  entity: entity,
                  approverIdController: _approverIdController,
                ),
              DualControlActionSuccess(:final entity) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('dualControl.granted'.tr()),
                    Text('dualControl.legalBasis'.tr(args: [entity.legalBasis])),
                    Text('dualControl.approvers'.tr(args: [entity.approverIds.join(', ')])),
                  ],
                ),
            };
          },
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.accountabilityLogEntryIdController,
    required this.legalBasisController,
    this.approverIdController,
    this.showApprovalSection = false,
  });

  final TextEditingController accountabilityLogEntryIdController;
  final TextEditingController legalBasisController;
  final TextEditingController? approverIdController;
  final bool showApprovalSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('accountability-log-entry-id-field'),
          controller: accountabilityLogEntryIdController,
          decoration: InputDecoration(labelText: 'dualControl.logEntryId'.tr()),
        ),
        TextField(
          key: const Key('legal-basis-field'),
          controller: legalBasisController,
          decoration: InputDecoration(labelText: 'dualControl.legalBasisField'.tr()),
        ),
        ElevatedButton(
          key: const Key('start-request-button'),
          // Starting a request inserts it; approving (below) updates it.
          onPressed: !SessionAccess.instance
                  .can('dual_control_access', Privileges.insert)
              ? null
              : () {
            final id = int.tryParse(accountabilityLogEntryIdController.text);
            if (id == null || legalBasisController.text.isEmpty) return;
            context.read<DualControlAccessBloc>().add(
                  RequestSubmitted(accountabilityLogEntryId: id, legalBasis: legalBasisController.text),
                );
          },
          child: Text('dualControl.startRequest'.tr()),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('dualControl.legalBasis'.tr(args: [entity.legalBasis])),
        Text('dualControl.approvals'.tr(args: ['${entity.approverIds.length}'])),
        TextField(
          key: const Key('approver-id-field'),
          controller: approverIdController,
          decoration: InputDecoration(labelText: 'dualControl.approverId'.tr()),
        ),
        ElevatedButton(
          key: const Key('add-approval-button'),
          // Layered like the API (decisions 45/93): approving needs the
          // screen's UPDATE and the approver kind-'R' resource.
          onPressed: !SessionAccess.instance
                      .can('dual_control_access', Privileges.update) ||
                  !SessionAccess.instance
                      .can('dual_control_approval', Privileges.update)
              ? null
              : () {
            if (approverIdController.text.isEmpty) return;
            context.read<DualControlAccessBloc>().add(ApprovalSubmitted(approverId: approverIdController.text));
          },
          child: Text('dualControl.approve'.tr()),
        ),
      ],
    );
  }
}
