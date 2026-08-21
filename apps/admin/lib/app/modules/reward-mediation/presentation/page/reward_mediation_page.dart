import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/reward_mediation_state_entity.dart';
import '../bloc/reward_mediation_bloc.dart';
import '../bloc/reward_mediation_event.dart';
import '../bloc/reward_mediation_state.dart';

/// The panel screen of the mediation discipline (decisions 98/148/149/150):
/// look a case's reward up by case id, run propose -> approve (DIFFERENT
/// user) -> contest window -> execute, close contests with a note, and
/// publish criteria versions. Everything shown comes from the server
/// state — the page never guesses a transition.
class RewardMediationPage extends StatefulWidget {
  const RewardMediationPage({super.key});

  @override
  State<RewardMediationPage> createState() => _RewardMediationPageState();
}

class _RewardMediationPageState extends State<RewardMediationPage> {
  final _caseIdController = TextEditingController();
  final _reasonController = TextEditingController();
  final _noteController = TextEditingController();
  final _criteriaVersionController = TextEditingController();
  final _criteriaBodyController = TextEditingController();
  String _outcome = 'fulfilled';
  String? _reasonError;
  String? _noteError;

  @override
  void dispose() {
    _caseIdController.dispose();
    _reasonController.dispose();
    _noteController.dispose();
    _criteriaVersionController.dispose();
    _criteriaBodyController.dispose();
    super.dispose();
  }

  void _lookup() {
    final id = int.tryParse(_caseIdController.text);
    if (id == null) return;
    _reasonController.clear();
    _noteController.clear();
    setState(() {
      _reasonError = null;
      _noteError = null;
    });
    context.read<RewardMediationBloc>().add(MediationLookupRequested(id));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'rewardMediation.title'.tr(),
      body: BlocBuilder<RewardMediationBloc, RewardMediationState>(
        builder: (context, state) {
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _searchForm(busy: state is MediationLoading),
                const VgrGap.md(),
                ...switch (state) {
                  MediationInitial() => _criteriaSection(state),
                  MediationLoading() => const [VgrLoading()],
                  MediationLookupError(:final failure) => [
                      VgrText.error(failureText(failure),
                          key: const Key('mediation-lookup-error')),
                    ],
                  MediationLoaded() => _caseView(state),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _searchForm({required bool busy}) {
    return VgrRow(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        VgrExpanded(
          child: VgrTextField(
            key: const Key('mediation-case-id-field'),
            controller: _caseIdController,
            label: 'rewardMediation.caseId'.tr(),
            keyboard: VgrKeyboard.number,
            onSubmitted: (_) => _lookup(),
          ),
        ),
        const VgrGap.hSm(),
        VgrPrimaryButton(
          key: const Key('mediation-lookup-button'),
          label: 'rewardMediation.lookup'.tr(),
          busy: busy,
          onPressed: _lookup,
        ),
      ],
    );
  }

  /// Decision 150: publishing criteria is the platform-wide precondition —
  /// without a version, no reserve exists to mediate. Shown while no case
  /// is on screen.
  List<Widget> _criteriaSection(MediationInitial state) {
    final canUpdate =
        SessionAccess.instance.can('reward_mediation', Privileges.update);

    return [
      VgrText.title('rewardMediation.criteriaTitle'.tr()),
      VgrText.caption('rewardMediation.criteriaHint'.tr()),
      VgrTextField(
        key: const Key('criteria-version-field'),
        controller: _criteriaVersionController,
        label: 'rewardMediation.criteriaVersionLabel'.tr(),
      ),
      VgrTextField(
        key: const Key('criteria-body-field'),
        controller: _criteriaBodyController,
        label: 'rewardMediation.criteriaBody'.tr(),
      ),
      const VgrGap.sm(),
      if (state.criteriaFailure != null)
        VgrText.error(failureText(state.criteriaFailure!),
            key: const Key('criteria-error')),
      if (state.criteriaPublished)
        VgrText('rewardMediation.criteriaPublished'.tr(),
            key: const Key('criteria-published')),
      VgrPrimaryButton(
        key: const Key('criteria-publish-button'),
        label: 'rewardMediation.publish'.tr(),
        busy: state.criteriaBusy,
        onPressed: !canUpdate
            ? null
            : () {
                final version = _criteriaVersionController.text.trim();
                final body = _criteriaBodyController.text.trim();
                if (version.isEmpty || body.isEmpty) return;
                context
                    .read<RewardMediationBloc>()
                    .add(CriteriaPublishSubmitted(version, body));
              },
      ),
    ];
  }

  List<Widget> _caseView(MediationLoaded state) {
    final entity = state.entity;
    final canUpdate =
        SessionAccess.instance.can('reward_mediation', Privileges.update);

    return [
      VgrCard(
        child: VgrPadding(
          child: VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrText.title('rewardMediation.caseTitle'
                  .tr(namedArgs: {'id': '${entity.reportId}'})),
              VgrText('rewardMediation.amount'
                  .tr(namedArgs: {'amount': _money(entity.amountCents)})),
              VgrText.caption(
                  'rewardMediation.offerStatus.${entity.offerStatus}'.tr()),
              if (entity.criteriaVersion.isNotEmpty)
                VgrText.caption('rewardMediation.criteriaStamped'
                    .tr(namedArgs: {'version': entity.criteriaVersion})),
            ],
          ),
        ),
      ),
      const VgrGap.md(),
      if (state.failure != null) ...[
        VgrText.error(failureText(state.failure!),
            key: const Key('mediation-action-error')),
        const VgrGap.md(),
      ],
      if (entity.offerStatus != 'reserved')
        VgrText('rewardMediation.notReserved'.tr(),
            key: const Key('mediation-not-reserved'))
      else if (entity.resolution == null)
        ..._proposeForm(state, canUpdate: canUpdate)
      else if (entity.resolution!.status == 'proposed')
        ..._approveSection(state, entity.resolution!, canUpdate: canUpdate)
      else
        ..._executeSection(state, entity, canUpdate: canUpdate),
      const VgrGap.md(),
      ..._logSection(entity),
    ];
  }

  /// Step 1 (decision 148): mediator A proposes, judged by the criteria
  /// version stamped at reserve (decision 150).
  List<Widget> _proposeForm(MediationLoaded state, {required bool canUpdate}) {
    return [
      VgrText.title('rewardMediation.proposeTitle'.tr()),
      VgrDropdownField<String>(
        key: const Key('outcome-field'),
        label: 'rewardMediation.outcome'.tr(),
        value: _outcome,
        options: [
          VgrOption(
              value: 'fulfilled', label: 'rewardMediation.fulfilled'.tr()),
          VgrOption(
              value: 'not_fulfilled',
              label: 'rewardMediation.notFulfilled'.tr()),
        ],
        onChanged: (value) => setState(() => _outcome = value ?? 'fulfilled'),
      ),
      VgrTextField(
        key: const Key('propose-reason-field'),
        controller: _reasonController,
        label: 'rewardMediation.reason'.tr(),
        errorText: _reasonError,
      ),
      const VgrGap.sm(),
      VgrPrimaryButton(
        key: const Key('propose-button'),
        label: 'rewardMediation.propose'.tr(),
        busy: state.busy,
        onPressed: !canUpdate
            ? null
            : () {
                final reason = _reasonController.text.trim();
                if (reason.isEmpty) {
                  setState(() =>
                      _reasonError = 'rewardMediation.reasonRequired'.tr());
                  return;
                }
                setState(() => _reasonError = null);
                context
                    .read<RewardMediationBloc>()
                    .add(ResolutionProposed(_outcome, reason));
              },
      ),
    ];
  }

  /// Step 2 (decision 148): a DIFFERENT mediator approves — the
  /// distinct-user rule is the server's; a same-user attempt renders its
  /// 422 here. Approval opens the window, it does not touch the rail.
  List<Widget> _approveSection(
    MediationLoaded state,
    RewardResolutionEntity resolution, {
    required bool canUpdate,
  }) {
    return [
      VgrText.title('rewardMediation.approveTitle'.tr()),
      VgrListTile(
        key: const Key('proposed-tile'),
        dense: true,
        leadingIcon: VgrIconName.person,
        title: 'rewardMediation.proposedBy'
            .tr(namedArgs: {'user': '${resolution.proposedBy}'}),
        subtitle:
            '${'rewardMediation.${resolution.outcome == 'fulfilled' ? 'fulfilled' : 'notFulfilled'}'.tr()} · ${resolution.reason}',
      ),
      VgrText.caption('rewardMediation.approveHint'.tr()),
      const VgrGap.sm(),
      VgrRow(
        children: [
          VgrPrimaryButton(
            key: const Key('approve-button'),
            label: 'rewardMediation.approve'.tr(),
            busy: state.busy,
            onPressed: !canUpdate
                ? null
                : () => context
                    .read<RewardMediationBloc>()
                    .add(const ResolutionApproved()),
          ),
          const VgrGap.hSm(),
          VgrTextButton(
            key: const Key('cancel-button'),
            label: 'rewardMediation.cancel'.tr(),
            onPressed: !canUpdate || state.busy
                ? null
                : () => context
                    .read<RewardMediationBloc>()
                    .add(const ResolutionCancelled()),
          ),
        ],
      ),
    ];
  }

  /// Decision 149: execution is the later human act — allowed only with
  /// the window elapsed and no open contest (the server judges both; a
  /// premature attempt renders its 422 here).
  List<Widget> _executeSection(
    MediationLoaded state,
    RewardMediationStateEntity entity, {
    required bool canUpdate,
  }) {
    final resolution = entity.resolution!;
    return [
      VgrText.title('rewardMediation.executeTitle'.tr()),
      VgrListTile(
        key: const Key('approved-tile'),
        dense: true,
        leadingIcon: VgrIconName.person,
        title: 'rewardMediation.approvedBy'
            .tr(namedArgs: {'user': '${resolution.approvedBy ?? '?'}'}),
        subtitle:
            '${'rewardMediation.${resolution.outcome == 'fulfilled' ? 'fulfilled' : 'notFulfilled'}'.tr()} · ${resolution.reason}',
      ),
      if (resolution.windowEndsAt != null)
        VgrText('rewardMediation.windowEnds'
            .tr(namedArgs: {'when': _when(resolution.windowEndsAt!)})),
      VgrText.caption('rewardMediation.executeHint'.tr()),
      const VgrGap.sm(),
      if (entity.openContests.isNotEmpty) ...[
        VgrText.title('rewardMediation.contestsTitle'.tr()),
        for (final contest in entity.openContests)
          VgrListTile(
            key: Key('contest-tile-${contest.id}'),
            dense: true,
            leadingIcon: VgrIconName.warning,
            title: 'rewardMediation.contestBy'
                .tr(namedArgs: {'account': '${contest.accountId}'}),
            subtitle: contest.body,
          ),
        VgrTextField(
          key: const Key('contest-note-field'),
          controller: _noteController,
          label: 'rewardMediation.closeNote'.tr(),
          errorText: _noteError,
        ),
        const VgrGap.sm(),
        VgrSecondaryButton(
          key: const Key('close-contest-button'),
          label: 'rewardMediation.closeContest'.tr(),
          onPressed: !canUpdate || state.busy
              ? null
              : () {
                  final note = _noteController.text.trim();
                  if (note.isEmpty) {
                    setState(() =>
                        _noteError = 'rewardMediation.noteRequired'.tr());
                    return;
                  }
                  setState(() => _noteError = null);
                  context.read<RewardMediationBloc>().add(
                      ContestCloseSubmitted(entity.openContests.first.id, note));
                },
        ),
        const VgrGap.sm(),
      ],
      VgrRow(
        children: [
          VgrPrimaryButton(
            key: const Key('execute-button'),
            label: 'rewardMediation.execute'.tr(),
            busy: state.busy,
            onPressed: !canUpdate
                ? null
                : () => context
                    .read<RewardMediationBloc>()
                    .add(const ResolutionExecuted()),
          ),
          const VgrGap.hSm(),
          VgrTextButton(
            key: const Key('cancel-button'),
            label: 'rewardMediation.cancel'.tr(),
            onPressed: !canUpdate || state.busy
                ? null
                : () => context
                    .read<RewardMediationBloc>()
                    .add(const ResolutionCancelled()),
          ),
        ],
      ),
    ];
  }

  /// The append-only trail (decisions 98/76) — rendered as served.
  List<Widget> _logSection(RewardMediationStateEntity entity) {
    if (entity.log.isEmpty) return const [];
    return [
      VgrText.title('rewardMediation.logTitle'.tr()),
      for (final entry in entity.log)
        VgrListTile(
          dense: true,
          leadingIcon: VgrIconName.check,
          title: 'rewardMediation.log.${entry.event}'.tr(),
          subtitle: [
            entry.actorRef,
            if (entry.details != null) entry.details!,
            if (entry.createdAt != null) _when(entry.createdAt!),
          ].join(' · '),
        ),
    ];
  }

  String _money(int cents) {
    final value = (cents / 100).toStringAsFixed(2).replaceFirst('.', ',');
    return 'R\$ $value';
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
