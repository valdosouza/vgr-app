import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/fee_rule_entity.dart';
import '../../../../shared/feedback/feedback.dart';
import '../bloc/monetization_config_bloc.dart';
import '../bloc/monetization_config_event.dart';
import '../bloc/monetization_config_state.dart';

class MonetizationConfigListPage extends StatelessWidget {
  const MonetizationConfigListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return VgrPage(
      title: 'monetization.title'.tr(),
      padded: false,
      body: BlocConsumer<MonetizationConfigBloc, MonetizationConfigState>(
        // Edits answer through the feedback bridge (decision 221); the
        // list never gives way to an error screen because of one.
        listenWhen: (_, state) => state is MonetizationConfigActionFailed || state is MonetizationConfigActionSucceeded,
        listener: (context, state) => switch (state) {
          MonetizationConfigActionFailed(:final failure) => showFailureFeedback(context, failure),
          _ => showSuccessFeedback(context, 'register.saved'.tr()),
        },
        buildWhen: (_, state) => state is! MonetizationConfigActionFailed && state is! MonetizationConfigActionSucceeded,
        builder: (context, state) {
          return switch (state) {
            MonetizationConfigLoading() => const VgrLoading(),
            MonetizationConfigError(:final failure) => VgrCenter(
                child: VgrColumn(children: [
                  VgrText.error(failureText(failure), key: const Key('catalog-load-error')),
                  const VgrGap.md(),
                  VgrSecondaryButton(
                    key: const Key('catalog-retry-button'),
                    label: 'register.retry'.tr(),
                    onPressed: () => context.read<MonetizationConfigBloc>().add(const FetchRequested()),
                  ),
                ]),
              ),
            // One-shots never reach the builder (buildWhen).
            MonetizationConfigActionFailed() || MonetizationConfigActionSucceeded() => const VgrLoading(),
            MonetizationConfigLoaded(:final rules, :final isHighTier) => VgrListView(
                children: [
                  for (final rule in rules)
                    _FeeRuleRow(
                      rule: rule,
                      isHighTier: rule.category != null && isHighTier(rule.category!),
                    ),
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

  String get _label => widget.rule.category ?? 'monetization.globalDefault'.tr();
  String get _key => widget.rule.category ?? 'global';

  @override
  Widget build(BuildContext context) {
    return VgrListTile(
      title: _label,
      subtitleWidget: VgrRow(
        children: [
          VgrFixedWidth(
            width: 80,
            child: VgrTextField(
              key: Key('fee-percent-field-$_key'),
              controller: _feePercentController,
              label: 'monetization.feePercent'.tr(),
            ),
          ),
          VgrCheckbox(
            key: Key('peer-to-peer-checkbox-$_key'),
            value: _peerToPeerAllowed,
            // Decision 58: a high-tier Category can never allow
            // peer-to-peer — disabled here, and refused by the API too.
            onChanged: widget.isHighTier
                ? null
                : (value) => setState(() => _peerToPeerAllowed = value),
          ),
          VgrText('monetization.allowPeerToPeer'.tr()),
        ],
      ),
      trailing: VgrPrimaryButton(
        key: Key('save-button-$_key'),
        label: 'monetization.save'.tr(),
        onPressed: !SessionAccess.instance.can('monetization_config', Privileges.update)
            ? null
            : () {
                // Mirrors feeRuleUpdateDto.feePercent (0..100); a wrong value
                // used to be dropped in silence.
                final feePercent = double.tryParse(_feePercentController.text.trim().replaceAll(',', '.'));
                if (feePercent == null || feePercent < 0 || feePercent > 100) {
                  showValidationFeedback(
                    context,
                    '${'monetization.feePercent'.tr()}: ${'monetization.feePercentRange'.tr()}',
                  );
                  return;
                }
                context.read<MonetizationConfigBloc>().add(RuleEdited(
                      category: widget.rule.category,
                      feePercent: feePercent,
                      paymentModeAllowed: {
                        PaymentMode.intermediated,
                        if (_peerToPeerAllowed) PaymentMode.peerToPeer,
                      },
                    ));
              },
      ),
    );
  }
}
