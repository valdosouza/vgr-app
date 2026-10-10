import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/help_offer_entity.dart';
import '../bloc/help_offer_bloc.dart';

/// What the "change my fronts" route carries (decision 211): the offer
/// being edited and the fronts checked today (from the participant view's
/// `myOffer` facet).
class HelpOfferEdit {
  const HelpOfferEdit({required this.helpOfferId, required this.current});

  final int helpOfferId;
  final Set<HelpType> current;
}

/// Offer-help form (spec task 10 as amended, decisions 6/10/20/34/35;
/// 208 — several fronts per offer). Reached from the detail of an OPEN
/// report this device does not own; the bloc still blocks self-dealing
/// for crafted deep links. With [editing] set, the same form edits the
/// fronts of the helper's own existing offer (211).
class HelpOfferFormPage extends StatefulWidget {
  const HelpOfferFormPage({
    super.key,
    required this.reportId,
    this.tier,
    this.editing,
    this.onDone,
  });

  final int reportId;

  /// The case's risk tier as its detail view showed it (decision 238).
  /// Null when the form was opened without it (a bare deep link) — then
  /// there is no name choice and the offer goes hidden (fail closed).
  final String? tier;

  /// Non-null → editing an existing offer's fronts instead of creating one.
  final HelpOfferEdit? editing;

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onDone;

  @override
  State<HelpOfferFormPage> createState() => _HelpOfferFormPageState();
}

class _HelpOfferFormPageState extends State<HelpOfferFormPage> {
  bool get _editing => widget.editing != null;

  /// Decision 237: naming oneself is an explicit opt-in, unchecked.
  bool _showName = false;

  /// Decision 238: the name passes the category's risk analysis, as the
  /// reporter's does — only low/medium may offer it; high never shows it
  /// (40/60, enforced by the server too) and an unknown tier fails closed.
  bool get _nameAllowed => const {'low', 'medium'}.contains(widget.tier);

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    context.read<HelpOfferBloc>().add(editing == null
        ? HelpOfferStarted(widget.reportId)
        : HelpOfferEditStarted(helpOfferId: editing.helpOfferId, current: editing.current));
  }

  void _done() => widget.onDone != null ? widget.onDone!() : Modular.to.pop(true);

  @override
  Widget build(BuildContext context) {
    // No session = anonymous offer (decisions 32/35). With a session the
    // helper has an account but is still HIDDEN unless they choose to be
    // named (237/238) — the account is what chat, rating and reward need.
    // An edit always has an account: the server only serves `myOffer` to
    // an account-holding participant.
    final withoutAccount = !_editing && context.watch<IdentityBloc>().state.token == null;

    return VgrScaffold(
      title: (_editing ? 'offer.editTitle' : 'offer.title').tr(),
      body: BlocBuilder<HelpOfferBloc, HelpOfferState>(
        builder: (context, state) => switch (state) {
          HelpOfferBlockedSelfDealing() => _blocked(),
          HelpOfferSuccess() => _success(withoutAccount: withoutAccount),
          HelpOfferTypesUpdated() => _updated(),
          HelpOfferReady() || HelpOfferSubmitting() =>
            _form(state, withoutAccount: withoutAccount),
        },
      ),
    );
  }

  /// Disabled form, not just a rejection (spec acceptance, decision 20).
  Widget _blocked() {
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrText.error('offer.selfDealing'.tr(), key: const Key('offer-blocked')),
        const VgrGap.md(),
        VgrPrimaryButton(
          key: const Key('offer-submit-button'),
          label: 'offer.submit'.tr(),
          onPressed: null,
        ),
      ],
    );
  }

  Widget _success({required bool withoutAccount}) {
    return VgrCenter(
      child: VgrColumn(
        key: const Key('offer-success-view'),
        children: [
          const VgrIcon(VgrIconName.check, size: 48),
          const VgrGap.md(),
          VgrText.headline('offer.success.title'.tr()),
          const VgrGap.sm(),
          VgrText('offer.success.message'.tr()),
          // A helper with an account can register to receive a reward
          // payout (decisions 104/143) — named or hidden alike (237/60);
          // an offer without an account can never claim one (34/35).
          if (!withoutAccount) ...[
            const VgrGap.md(),
            VgrTextButton(
              key: const Key('offer-reward-onboarding-link'),
              label: 'offer.success.rewardOnboardingLink'.tr(),
              onPressed: () => Modular.to.pushNamed('/reward-onboarding/'),
            ),
          ],
          const VgrGap.lg(),
          VgrSecondaryButton(
            key: const Key('offer-done-button'),
            label: 'offer.success.back'.tr(),
            onPressed: _done,
          ),
        ],
      ),
    );
  }

  /// The fronts were replaced (211) — the detail reloads on return and
  /// shows the new set.
  Widget _updated() {
    return VgrCenter(
      child: VgrColumn(
        key: const Key('offer-updated-view'),
        children: [
          const VgrIcon(VgrIconName.check, size: 48),
          const VgrGap.md(),
          VgrText.headline('offer.updated.title'.tr()),
          const VgrGap.sm(),
          VgrText('offer.updated.message'.tr()),
          const VgrGap.lg(),
          VgrSecondaryButton(
            key: const Key('offer-done-button'),
            label: 'offer.success.back'.tr(),
            onPressed: _done,
          ),
        ],
      ),
    );
  }

  Widget _form(HelpOfferState state, {required bool withoutAccount}) {
    final selected = switch (state) {
      HelpOfferReady(selected: final s) => s,
      HelpOfferSubmitting(selected: final s) => s,
      _ => const <HelpType>{},
    };
    final submitting = state is HelpOfferSubmitting;
    final failure = state is HelpOfferReady ? state.failure : null;

    return VgrScrollView(
      child: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VgrText.title('offer.typeLabel'.tr()),
          const VgrGap.sm(),
          // Real multi-select (decision 208): each box toggles its own
          // front; submit stays disabled until at least one is checked.
          for (final type in HelpType.values)
            VgrCheckboxTile(
              key: Key('offer-type-${type.wire}'),
              label: 'detail.helpType.${type.wire}'.tr(),
              value: selected.contains(type),
              onChanged: submitting
                  ? null
                  : (_) => context
                      .read<HelpOfferBloc>()
                      .add(HelpOfferTypeToggled(type)),
            ),
          if (!withoutAccount && !_editing) ...[
            const VgrGap.md(),
            _nameChoice(submitting: submitting),
          ],
          if (withoutAccount) ...[
            const VgrGap.md(),
            // Decisions 34/35 (amendment MA9): anonymous help is accepted
            // in full, but can never claim a reward — say so BEFORE the
            // submit, and never block it.
            VgrCard(
              child: VgrPadding(
                child: VgrColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VgrText.caption(
                      'offer.anonymousNotice'.tr(),
                      key: const Key('offer-anonymous-notice'),
                    ),
                    const VgrGap.sm(),
                    // Decision 169: without an account there is no routable
                    // identity, so no chat with the reporter — said BEFORE
                    // the offer, never blocking it (same pattern as 34).
                    VgrText.caption(
                      'offer.anonymousNoChatNotice'.tr(),
                      key: const Key('offer-anonymous-no-chat-notice'),
                    ),
                    const VgrGap.sm(),
                    // Decision 180 (extends 169): the same missing-account
                    // reason blocks rating too — no identity to accumulate
                    // reputation on. Said BEFORE the offer, never blocking
                    // it.
                    VgrText.caption(
                      'offer.anonymousNoRatingNotice'.tr(),
                      key: const Key('offer-anonymous-no-rating-notice'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (failure != null) ...[
            const VgrGap.md(),
            VgrText.error(failureText(failure), key: const Key('offer-error')),
          ],
          const VgrGap.lg(),
          VgrPrimaryButton(
            key: const Key('offer-submit-button'),
            label: (_editing ? 'offer.save' : 'offer.submit').tr(),
            busy: submitting,
            onPressed: selected.isEmpty || submitting
                ? null
                : () => context
                    .read<HelpOfferBloc>()
                    .add(HelpOfferSubmitPressed(
                      anonymous: withoutAccount || !_nameAllowed || !_showName,
                    )),
          ),
          const VgrGap.lg(),
        ],
      ),
    );
  }

  /// Decisions 237/238: the reporter sees the helper's name only when the
  /// helper checks it AND the case's risk tier allows it. The warning says
  /// why to leave it unchecked: a report can be fake, made to find out who
  /// helps. On high tier (or an unknown one) there is nothing to choose.
  Widget _nameChoice({required bool submitting}) {
    if (!_nameAllowed) {
      final high = widget.tier == 'high';
      return VgrCard(
        child: VgrPadding(
          child: VgrText.caption(
            (high ? 'offer.highRiskNameNotice' : 'offer.hiddenNameNotice').tr(),
            key: Key(high ? 'offer-high-risk-name-notice' : 'offer-hidden-name-notice'),
          ),
        ),
      );
    }
    return VgrCard(
      child: VgrPadding(
        child: VgrColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VgrCheckboxTile(
              key: const Key('offer-show-name'),
              label: 'offer.showName'.tr(),
              value: _showName,
              onChanged: submitting ? null : (value) => setState(() => _showName = value),
            ),
            const VgrGap.sm(),
            VgrText.caption(
              'offer.showNameWarning'.tr(),
              key: const Key('offer-show-name-warning'),
            ),
          ],
        ),
      ),
    );
  }
}
