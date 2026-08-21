import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/help_offer_entity.dart';
import '../bloc/help_offer_bloc.dart';

/// Offer-help form (spec task 10 as amended, decisions 6/10/20/34/35).
/// Reached from the detail of an OPEN report this device does not own;
/// the bloc still blocks self-dealing for crafted deep links.
class HelpOfferFormPage extends StatefulWidget {
  const HelpOfferFormPage({super.key, required this.reportId, this.onDone});

  final int reportId;

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onDone;

  @override
  State<HelpOfferFormPage> createState() => _HelpOfferFormPageState();
}

class _HelpOfferFormPageState extends State<HelpOfferFormPage> {
  @override
  void initState() {
    super.initState();
    context.read<HelpOfferBloc>().add(HelpOfferStarted(widget.reportId));
  }

  void _done() => widget.onDone != null ? widget.onDone!() : Modular.to.pop(true);

  @override
  Widget build(BuildContext context) {
    // No session = anonymous offer (decisions 32/35); with round-6 auth
    // in place a logged-in helper will get the identification choice (6).
    final anonymous = context.watch<IdentityBloc>().state.token == null;

    return VgrScaffold(
      title: 'offer.title'.tr(),
      body: BlocBuilder<HelpOfferBloc, HelpOfferState>(
        builder: (context, state) => switch (state) {
          HelpOfferBlockedSelfDealing() => _blocked(),
          HelpOfferSuccess() => _success(anonymous: anonymous),
          HelpOfferReady() || HelpOfferSubmitting() =>
            _form(state, anonymous: anonymous),
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

  Widget _success({required bool anonymous}) {
    return VgrCenter(
      child: VgrColumn(
        key: const Key('offer-success-view'),
        children: [
          const VgrIcon(VgrIconName.check, size: 48),
          const VgrGap.md(),
          VgrText.headline('offer.success.title'.tr()),
          const VgrGap.sm(),
          VgrText('offer.success.message'.tr()),
          // Identified helpers can register to receive a reward payout
          // (decisions 104/143) — an anonymous offer can never claim one
          // (34/35), so the link only makes sense here when identified.
          if (!anonymous) ...[
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

  Widget _form(HelpOfferState state, {required bool anonymous}) {
    final selected = switch (state) {
      HelpOfferReady(selected: final s) => s,
      HelpOfferSubmitting(selected: final s) => s,
      _ => null,
    };
    final submitting = state is HelpOfferSubmitting;
    final failure = state is HelpOfferReady ? state.failure : null;

    return VgrScrollView(
      child: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VgrText.title('offer.typeLabel'.tr()),
          const VgrGap.sm(),
          for (final type in HelpType.values)
            VgrCheckboxTile(
              key: Key('offer-type-${type.wire}'),
              label: 'detail.helpType.${type.wire}'.tr(),
              value: selected == type,
              onChanged: submitting
                  ? null
                  : (_) => context
                      .read<HelpOfferBloc>()
                      .add(HelpOfferTypeSelected(type)),
            ),
          if (anonymous) ...[
            const VgrGap.md(),
            // Decisions 34/35 (amendment MA9): anonymous help is accepted
            // in full, but can never claim a reward — say so BEFORE the
            // submit, and never block it.
            VgrCard(
              child: VgrPadding(
                child: VgrText.caption(
                  'offer.anonymousNotice'.tr(),
                  key: const Key('offer-anonymous-notice'),
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
            label: 'offer.submit'.tr(),
            busy: submitting,
            onPressed: selected == null || submitting
                ? null
                : () => context
                    .read<HelpOfferBloc>()
                    .add(HelpOfferSubmitPressed(anonymous: anonymous)),
          ),
          const VgrGap.lg(),
        ],
      ),
    );
  }
}
