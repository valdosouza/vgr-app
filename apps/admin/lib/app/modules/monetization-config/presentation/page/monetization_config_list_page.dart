import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/fee_rule_entity.dart';
import '../bloc/monetization_config_bloc.dart';
import '../bloc/monetization_config_event.dart';
import '../bloc/monetization_config_state.dart';

class MonetizationConfigListPage extends StatelessWidget {
  const MonetizationConfigListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monetization Config')),
      body: BlocBuilder<MonetizationConfigBloc, MonetizationConfigState>(
        builder: (context, state) {
          return switch (state) {
            MonetizationConfigLoading() => const Center(child: CircularProgressIndicator()),
            MonetizationConfigError(:final message) => Center(child: Text(message)),
            MonetizationConfigLoaded(:final rules, :final isHighTier) => ListView(
                children: [
                  for (final rule in rules)
                    _FeeRuleRow(rule: rule, isHighTier: rule.category != null && isHighTier(rule.category!)),
                ],
              ),
          };
        },
      ),
    );
  }
}

class _FeeRuleRow extends StatefulWidget {
  const _FeeRuleRow({required this.rule, required this.isHighTier});

  final FeeRuleEntity rule;
  final bool isHighTier;

  @override
  State<_FeeRuleRow> createState() => _FeeRuleRowState();
}

class _FeeRuleRowState extends State<_FeeRuleRow> {
  late final TextEditingController _feePercentController;
  late bool _peerToPeerAllowed;

  @override
  void initState() {
    super.initState();
    _feePercentController = TextEditingController(text: widget.rule.feePercent.toString());
    _peerToPeerAllowed = widget.rule.paymentModeAllowed.contains(PaymentMode.peerToPeer);
  }

  @override
  void dispose() {
    _feePercentController.dispose();
    super.dispose();
  }

  String get _label => widget.rule.category ?? 'Global default';
  String get _key => widget.rule.category ?? 'global';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_label),
      subtitle: Row(
        children: [
          SizedBox(
            width: 80,
            child: TextField(
              key: Key('fee-percent-field-$_key'),
              controller: _feePercentController,
              decoration: const InputDecoration(labelText: 'Fee %'),
            ),
          ),
          Checkbox(
            key: Key('peer-to-peer-checkbox-$_key'),
            value: _peerToPeerAllowed,
            onChanged: widget.isHighTier
                ? null
                : (value) => setState(() => _peerToPeerAllowed = value ?? false),
          ),
          const Text('Allow peer-to-peer'),
        ],
      ),
      trailing: ElevatedButton(
        key: Key('save-button-$_key'),
        onPressed: () {
          final feePercent = double.tryParse(_feePercentController.text);
          if (feePercent == null) return;
          context.read<MonetizationConfigBloc>().add(RuleEdited(
                category: widget.rule.category,
                feePercent: feePercent,
                paymentModeAllowed: {
                  PaymentMode.intermediated,
                  if (_peerToPeerAllowed) PaymentMode.peerToPeer,
                },
              ));
        },
        child: const Text('Save'),
      ),
    );
  }
}
