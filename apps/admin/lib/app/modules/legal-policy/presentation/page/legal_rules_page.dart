import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../../../shared/register/register_field.dart';
import '../../../../shared/register/register_screen.dart';
import '../../../../shared/register/register_search_page.dart';
import '../../../../shared/session/current_interface.dart';
import '../../domain/entity/legal_policy_entities.dart';
import '../bloc/rules_bloc.dart';

const _statuses = ['allowed', 'restricted', 'blocked'];
const _reasons = ['no_control', 'legislation', 'self_preservation'];

/// Rule administration (decisions 107/108) on the register factory: the
/// versioned history paged and filtered by capability / jurisdiction /
/// legal basis (decision 220), "new" opens the PROPOSAL form (INSERT), and
/// a proposed row carries approve (a DIFFERENT user — the server judges
/// it, the refusal arrives through the bridge) and reject (UPDATE). Rows
/// never open: a change to a rule is a new proposal.
class LegalRulesPage extends StatelessWidget {
  const LegalRulesPage({super.key});

  static const screen = CurrentInterface('legal_rules');
  static const dualControl = CurrentInterface('dual_control_approval');

  @override
  Widget build(BuildContext context) {
    final canDecide = screen.canUpdate;
    final canApprove = canDecide && dualControl.canUpdate;

    return RegisterScreen<LegalRuleEntity, LegalRuleProposal>(
      title: 'legal.rules.title'.tr(),
      screen: screen,
      openRows: false,
      rowId: (rule) => rule.id,
      rowBuilder: (context, rule) => RegisterRow(
        title: '${rule.capability} · ${rule.jurisdictionCode} · v${rule.version}',
        subtitleWidget: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The line a litigator asks about (plan §6): what applied,
            // since when, until when, decided by whom.
            VgrText(
              '${'legal.status.${rule.status}'.tr()}'
              '${rule.reason == null ? '' : ' · ${'legal.reason.${rule.reason}'.tr()}'}'
              ' · ${'legal.ruleState.${rule.ruleState}'.tr()}'
              ' · ${'legal.review.${rule.reviewState}'.tr()}',
              key: Key('rule-summary-${rule.id}'),
            ),
            if (rule.legalBasis != null) VgrText.caption(rule.legalBasis!),
            VgrText.caption(
              'legal.rules.window'.tr(namedArgs: {
                'from': formatLocalDate(rule.effectiveFrom),
                'until': formatLocalDate(rule.expiresAt),
              }),
            ),
            if (rule.ruleState == 'proposed')
              VgrRow(children: [
                VgrPrimaryButton(
                  key: Key('rule-approve-${rule.id}'),
                  label: 'legal.rules.approve'.tr(),
                  onPressed: !canApprove
                      ? null
                      : () => context.read<RulesRegisterBloc>().add(RuleApproved(rule.id)),
                ),
                const VgrGap.hSm(),
                VgrSecondaryButton(
                  key: Key('rule-reject-${rule.id}'),
                  label: 'legal.rules.reject'.tr(),
                  onPressed: !canDecide
                      ? null
                      : () => context.read<RulesRegisterBloc>().add(RuleRejected(rule.id)),
                ),
              ]),
          ],
        ),
      ),
      formTitle: (_) => 'legal.rules.proposeTitle'.tr(),
      fields: (_) => [
        RegisterTextField(
          name: 'capability',
          label: 'legal.rules.capability'.tr(),
          validators: [VgrValidators.minLength(3), VgrValidators.maxLength(80)],
        ),
        RegisterTextField(
          name: 'jurisdictionCode',
          label: 'legal.rules.jurisdiction'.tr(),
          validators: [VgrValidators.minLength(2), VgrValidators.maxLength(10)],
        ),
        RegisterChoiceField(
          name: 'status',
          label: 'legal.rules.status'.tr(),
          initialValue: 'allowed',
          required: true,
          options: [
            for (final status in _statuses)
              VgrOption(value: status, label: 'legal.status.$status'.tr()),
          ],
        ),
        // Decision 78: a non-allowed status ALWAYS carries a typified
        // reason; allowed never does.
        RegisterChoiceField(
          name: 'reason',
          label: 'legal.rules.reason'.tr(),
          required: true,
          visibleWhen: (values) => values.choice('status') != 'allowed',
          options: [
            for (final reason in _reasons)
              VgrOption(value: reason, label: 'legal.reason.$reason'.tr()),
          ],
        ),
        RegisterTextField(
          name: 'legalBasis',
          label: 'legal.rules.legalBasis'.tr(),
          validators: [VgrValidators.maxLength(4000)],
        ),
      ],
      draftOf: (_, values) {
        final status = values.choice('status') ?? 'allowed';
        final legalBasis = values.text('legalBasis').trim();
        return LegalRuleProposal(
          capability: values.text('capability').trim(),
          jurisdictionCode: values.text('jurisdictionCode').trim().toUpperCase(),
          status: status,
          reason: status == 'allowed' ? null : values.choice('reason'),
          legalBasis: legalBasis.isEmpty ? null : legalBasis,
        );
      },
    );
  }
}
