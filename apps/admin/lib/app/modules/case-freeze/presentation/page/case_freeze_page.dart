import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/case_freeze_state_entity.dart';
import '../bloc/case_freeze_bloc.dart';
import '../bloc/case_freeze_event.dart';
import '../bloc/case_freeze_state.dart';

/// THE one panel screen of the report front (decision 142): look a case
/// up by id, freeze it with a mandatory reason ("we cannot destroy
/// evidence", 141), request/approve unfreeze under dual control (141d).
/// Everything shown comes from the server state — the page never guesses
/// a transition.
class CaseFreezePage extends StatefulWidget {
  const CaseFreezePage({super.key});

  @override
  State<CaseFreezePage> createState() => _CaseFreezePageState();
}

class _CaseFreezePageState extends State<CaseFreezePage> {
  final _caseIdController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _reasonError;

  @override
  void dispose() {
    _caseIdController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _lookup() {
    final id = int.tryParse(_caseIdController.text);
    if (id == null) return;
    _reasonController.clear();
    setState(() => _reasonError = null);
    context.read<CaseFreezeBloc>().add(CaseLookupRequested(id));
  }

  /// The reason is MANDATORY (141) — mirror the API's minimum so the
  /// admin learns it before the round trip; the server stays authority.
  String? _validReason() {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() => _reasonError = 'caseFreeze.reasonRequired'.tr());
      return null;
    }
    setState(() => _reasonError = null);
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'caseFreeze.title'.tr(),
      body: BlocBuilder<CaseFreezeBloc, CaseFreezeState>(
        builder: (context, state) {
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _searchForm(busy: state is CaseFreezeLoading),
                const VgrGap.md(),
                ...switch (state) {
                  CaseFreezeInitial() => const [],
                  CaseFreezeLoading() => const [VgrLoading()],
                  CaseFreezeLookupError(:final failure) => [
                      VgrText.error(failureText(failure),
                          key: const Key('case-lookup-error')),
                    ],
                  CaseFreezeLoaded() => _caseView(state),
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
            key: const Key('case-id-field'),
            controller: _caseIdController,
            label: 'caseFreeze.caseId'.tr(),
            keyboard: VgrKeyboard.number,
            onSubmitted: (_) => _lookup(),
          ),
        ),
        const VgrGap.hSm(),
        VgrPrimaryButton(
          key: const Key('case-lookup-button'),
          label: 'caseFreeze.lookup'.tr(),
          busy: busy,
          onPressed: _lookup,
        ),
      ],
    );
  }

  List<Widget> _caseView(CaseFreezeLoaded state) {
    final entity = state.entity;
    final canUpdate = SessionAccess.instance.can('case_freeze', Privileges.update);

    return [
      VgrCard(
        child: VgrPadding(
          child: VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrText.title('caseFreeze.caseTitle'
                  .tr(namedArgs: {'id': '${entity.reportId}'})),
              VgrText.caption(entity.status == 'resolved'
                  ? 'caseFreeze.status.resolved'.tr()
                  : 'caseFreeze.status.open'.tr()),
              const VgrGap.sm(),
              if (entity.frozen) ...[
                VgrText.error('caseFreeze.frozen'.tr(),
                    key: const Key('case-frozen-badge')),
                if (entity.frozenReason != null)
                  VgrText('caseFreeze.frozenReason'
                      .tr(namedArgs: {'reason': entity.frozenReason!})),
                if (entity.frozenAt != null)
                  VgrText.caption(_when(entity.frozenAt!)),
              ] else
                VgrText('caseFreeze.notFrozen'.tr(),
                    key: const Key('case-not-frozen-badge')),
            ],
          ),
        ),
      ),
      const VgrGap.md(),
      if (state.failure != null) ...[
        VgrText.error(failureText(state.failure!),
            key: const Key('case-action-error')),
        const VgrGap.md(),
      ],
      if (!entity.frozen)
        ..._freezeAction(state, canUpdate: canUpdate)
      else if (entity.pendingUnfreeze == null)
        ..._requestUnfreezeAction(state, canUpdate: canUpdate)
      else
        ..._approveUnfreezeAction(state, entity.pendingUnfreeze!,
            canUpdate: canUpdate),
    ];
  }

  /// Freeze: one human, mandatory reason (141). No timeline event exists
  /// for it server-side — the investigated is never tipped off.
  List<Widget> _freezeAction(CaseFreezeLoaded state, {required bool canUpdate}) {
    return [
      VgrText.title('caseFreeze.freezeTitle'.tr()),
      VgrTextField(
        key: const Key('freeze-reason-field'),
        controller: _reasonController,
        label: 'caseFreeze.reason'.tr(),
        errorText: _reasonError,
      ),
      const VgrGap.sm(),
      VgrPrimaryButton(
        key: const Key('freeze-button'),
        label: 'caseFreeze.freeze'.tr(),
        busy: state.busy,
        onPressed: !canUpdate
            ? null
            : () {
                final reason = _validReason();
                if (reason == null) return;
                context.read<CaseFreezeBloc>().add(CaseFreezeSubmitted(reason));
              },
      ),
    ];
  }

  /// Unfreeze step 1 (141d): a human REQUESTS, with a reason.
  List<Widget> _requestUnfreezeAction(CaseFreezeLoaded state,
      {required bool canUpdate}) {
    return [
      VgrText.title('caseFreeze.requestUnfreezeTitle'.tr()),
      VgrText.caption('caseFreeze.dualControlHint'.tr()),
      VgrTextField(
        key: const Key('unfreeze-reason-field'),
        controller: _reasonController,
        label: 'caseFreeze.reason'.tr(),
        errorText: _reasonError,
      ),
      const VgrGap.sm(),
      VgrPrimaryButton(
        key: const Key('request-unfreeze-button'),
        label: 'caseFreeze.requestUnfreeze'.tr(),
        busy: state.busy,
        onPressed: !canUpdate
            ? null
            : () {
                final reason = _validReason();
                if (reason == null) return;
                context
                    .read<CaseFreezeBloc>()
                    .add(UnfreezeRequestSubmitted(reason));
              },
      ),
    ];
  }

  /// Unfreeze step 2 (141d): a DIFFERENT human approves; the retention
  /// clock RESTARTS. The distinct-user rule is the server's — a same-user
  /// attempt renders its 422 here.
  List<Widget> _approveUnfreezeAction(
    CaseFreezeLoaded state,
    PendingUnfreezeEntity pending, {
    required bool canUpdate,
  }) {
    return [
      VgrText.title('caseFreeze.approveUnfreezeTitle'.tr()),
      VgrListTile(
        key: const Key('pending-unfreeze-tile'),
        dense: true,
        leadingIcon: VgrIconName.person,
        title: 'caseFreeze.pendingBy'
            .tr(namedArgs: {'user': '${pending.requestedBy}'}),
        subtitle: '${pending.reason} · ${_when(pending.requestedAt)}',
      ),
      VgrText.caption('caseFreeze.approveHint'.tr()),
      const VgrGap.sm(),
      VgrPrimaryButton(
        key: const Key('approve-unfreeze-button'),
        label: 'caseFreeze.approveUnfreeze'.tr(),
        busy: state.busy,
        onPressed: !canUpdate
            ? null
            : () => context
                .read<CaseFreezeBloc>()
                .add(const UnfreezeApproveSubmitted()),
      ),
    ];
  }

  String _when(String iso) =>
      iso.length >= 16 ? iso.replaceFirst('T', ' ').substring(0, 16) : iso;
}
