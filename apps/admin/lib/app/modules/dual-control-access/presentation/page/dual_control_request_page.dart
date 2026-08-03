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
      appBar: AppBar(title: const Text('Dual Control Access')),
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
                    const Text('Granted'),
                    Text('Legal basis: ${entity.legalBasis}'),
                    Text('Approvers: ${entity.approverIds.join(', ')}'),
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
          decoration: const InputDecoration(labelText: 'AccountabilityLogEntry id'),
        ),
        TextField(
          key: const Key('legal-basis-field'),
          controller: legalBasisController,
          decoration: const InputDecoration(labelText: 'Legal basis'),
        ),
        ElevatedButton(
          key: const Key('start-request-button'),
          onPressed: () {
            final id = int.tryParse(accountabilityLogEntryIdController.text);
            if (id == null || legalBasisController.text.isEmpty) return;
            context.read<DualControlAccessBloc>().add(
                  RequestSubmitted(accountabilityLogEntryId: id, legalBasis: legalBasisController.text),
                );
          },
          child: const Text('Start Request'),
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
        Text('Legal basis: ${entity.legalBasis}'),
        Text('${entity.approverIds.length} of 2 approvals'),
        TextField(
          key: const Key('approver-id-field'),
          controller: approverIdController,
          decoration: const InputDecoration(labelText: 'Approver id'),
        ),
        ElevatedButton(
          key: const Key('add-approval-button'),
          onPressed: () {
            if (approverIdController.text.isEmpty) return;
            context.read<DualControlAccessBloc>().add(ApprovalSubmitted(approverId: approverIdController.text));
          },
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
