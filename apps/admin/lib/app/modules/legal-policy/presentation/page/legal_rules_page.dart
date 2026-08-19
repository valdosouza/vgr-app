import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/legal_policy_entities.dart';
import '../bloc/rules_bloc.dart';

const _statuses = ['allowed', 'restricted', 'blocked'];
const _reasons = ['no_control', 'legislation', 'self_preservation'];

/// Rule administration (decisions 107/108): versioned history per
/// capability×jurisdiction, proposal form, approve/reject on proposed
/// rows. Approving needs a DIFFERENT user than the proposer — the server
/// judges it; this screen renders its refusal.
class LegalRulesPage extends StatefulWidget {
  const LegalRulesPage({super.key});

  @override
  State<LegalRulesPage> createState() => _LegalRulesPageState();
}

class _LegalRulesPageState extends State<LegalRulesPage> {
  final _filterCapabilityController = TextEditingController();
  final _filterJurisdictionController = TextEditingController();
  final _capabilityController = TextEditingController();
  final _jurisdictionController = TextEditingController();
  final _legalBasisController = TextEditingController();
  String _status = 'allowed';
  String _reason = 'no_control';

  @override
  void initState() {
    super.initState();
    context.read<RulesBloc>().add(const RulesRequested());
  }

  @override
  void dispose() {
    _filterCapabilityController.dispose();
    _filterJurisdictionController.dispose();
    _capabilityController.dispose();
    _jurisdictionController.dispose();
    _legalBasisController.dispose();
    super.dispose();
  }

  void _filter() {
    context.read<RulesBloc>().add(RulesRequested(
          capability: _filterCapabilityController.text.trim(),
          jurisdiction: _filterJurisdictionController.text.trim().toUpperCase(),
        ));
  }

  void _propose() {
    final capability = _capabilityController.text.trim();
    final jurisdiction = _jurisdictionController.text.trim().toUpperCase();
    if (capability.length < 3 || jurisdiction.length < 2) return;
    final legalBasis = _legalBasisController.text.trim();
    context.read<RulesBloc>().add(RuleProposed(LegalRuleProposal(
          capability: capability,
          jurisdictionCode: jurisdiction,
          status: _status,
          // Decision 78: a non-allowed status ALWAYS carries a typified
          // reason; allowed never does.
          reason: _status == 'allowed' ? null : _reason,
          legalBasis: legalBasis.isEmpty ? null : legalBasis,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final canPropose = SessionAccess.instance.can('legal_rules', Privileges.insert);
    final canDecide = SessionAccess.instance.can('legal_rules', Privileges.update);
    final canApprove = canDecide &&
        SessionAccess.instance.can('dual_control_approval', Privileges.update);

    return VgrScaffold(
      title: 'legal.rules.title'.tr(),
      body: BlocBuilder<RulesBloc, RulesState>(
        builder: (context, state) => switch (state) {
          RulesLoading() => const VgrLoading(),
          RulesError(:final failure) => VgrCenter(
              child: VgrColumn(children: [
                VgrText.error(failureText(failure), key: const Key('rules-error')),
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('rules-retry-button'),
                  label: 'legal.retry'.tr(),
                  onPressed: _filter,
                ),
              ]),
            ),
          RulesLoaded(:final rows, :final failure) => VgrScrollView(
              child: VgrColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (failure != null) ...[
                    VgrText.error(failureText(failure),
                        key: const Key('rules-action-error')),
                    const VgrGap.sm(),
                  ],
                  ..._proposalForm(canPropose),
                  const VgrGap.md(),
                  ..._filterForm(),
                  const VgrGap.md(),
                  ..._history(rows, canDecide: canDecide, canApprove: canApprove),
                  const VgrGap.lg(),
                ],
              ),
            ),
        },
      ),
    );
  }

  List<Widget> _proposalForm(bool canPropose) {
    return [
      VgrText.title('legal.rules.proposeTitle'.tr()),
      VgrTextField(
        key: const Key('rule-capability-field'),
        controller: _capabilityController,
        label: 'legal.rules.capability'.tr(),
      ),
      VgrTextField(
        key: const Key('rule-jurisdiction-field'),
        controller: _jurisdictionController,
        label: 'legal.rules.jurisdiction'.tr(),
      ),
      VgrDropdownField<String>(
        key: const Key('rule-status-field'),
        label: 'legal.rules.status'.tr(),
        value: _status,
        options: [
          for (final status in _statuses)
            VgrOption(value: status, label: 'legal.status.$status'.tr()),
        ],
        onChanged: (status) =>
            setState(() => _status = status ?? 'allowed'),
      ),
      if (_status != 'allowed')
        VgrDropdownField<String>(
          key: const Key('rule-reason-field'),
          label: 'legal.rules.reason'.tr(),
          value: _reason,
          options: [
            for (final reason in _reasons)
              VgrOption(value: reason, label: 'legal.reason.$reason'.tr()),
          ],
          onChanged: (reason) =>
              setState(() => _reason = reason ?? 'no_control'),
        ),
      VgrTextField(
        key: const Key('rule-legal-basis-field'),
        controller: _legalBasisController,
        label: 'legal.rules.legalBasis'.tr(),
      ),
      const VgrGap.sm(),
      VgrPrimaryButton(
        key: const Key('rule-propose-button'),
        label: 'legal.rules.propose'.tr(),
        onPressed: canPropose ? _propose : null,
      ),
    ];
  }

  List<Widget> _filterForm() {
    return [
      VgrText.title('legal.rules.historyTitle'.tr()),
      VgrRow(children: [
        VgrExpanded(
          child: VgrTextField(
            key: const Key('rules-filter-capability'),
            controller: _filterCapabilityController,
            label: 'legal.rules.capability'.tr(),
          ),
        ),
        const VgrGap.hSm(),
        VgrExpanded(
          child: VgrTextField(
            key: const Key('rules-filter-jurisdiction'),
            controller: _filterJurisdictionController,
            label: 'legal.rules.jurisdiction'.tr(),
          ),
        ),
        const VgrGap.hSm(),
        VgrSecondaryButton(
          key: const Key('rules-filter-button'),
          label: 'legal.rules.filter'.tr(),
          onPressed: _filter,
        ),
      ]),
    ];
  }

  List<Widget> _history(
    List<LegalRuleEntity> rows, {
    required bool canDecide,
    required bool canApprove,
  }) {
    if (rows.isEmpty) {
      return [VgrText.caption('legal.rules.empty'.tr())];
    }
    return [
      for (final rule in rows)
        VgrCard(
          child: VgrPadding(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VgrText.title(
                    '${rule.capability} · ${rule.jurisdictionCode} · v${rule.version}'),
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
                    'from': rule.effectiveFrom == null
                        ? '—'
                        : _when(rule.effectiveFrom!),
                    'until':
                        rule.expiresAt == null ? '—' : _when(rule.expiresAt!),
                  }),
                ),
                if (rule.ruleState == 'proposed') ...[
                  const VgrGap.sm(),
                  VgrRow(children: [
                    VgrPrimaryButton(
                      key: Key('rule-approve-${rule.id}'),
                      label: 'legal.rules.approve'.tr(),
                      onPressed: !canApprove
                          ? null
                          : () => context
                              .read<RulesBloc>()
                              .add(RuleApproved(rule.id)),
                    ),
                    const VgrGap.hSm(),
                    VgrSecondaryButton(
                      key: Key('rule-reject-${rule.id}'),
                      label: 'legal.rules.reject'.tr(),
                      onPressed: !canDecide
                          ? null
                          : () => context
                              .read<RulesBloc>()
                              .add(RuleRejected(rule.id)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  String _when(String iso) =>
      iso.length >= 10 ? iso.replaceFirst('T', ' ').substring(0, 10) : iso;
}
