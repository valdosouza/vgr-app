import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_validators/vgr_validators.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/entity/reward_recipient_profile_entity.dart';
import '../bloc/reward_onboarding_bloc.dart';

/// Helper onboarding to receive reward payouts (KYC straight to the rail,
/// decisions 104/143). Reached once the helper decides to become eligible
/// for a payout — nothing here nor its result names a specific case.
class RewardOnboardingPage extends StatefulWidget {
  const RewardOnboardingPage({super.key, this.onDone});

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onDone;

  @override
  State<RewardOnboardingPage> createState() => _RewardOnboardingPageState();
}

class _RewardOnboardingPageState extends State<RewardOnboardingPage> {
  final _legalName = TextEditingController();
  final _email = TextEditingController();
  final _taxId = TextEditingController();
  final _mobilePhone = TextEditingController();
  final _monthlyIncome = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _neighborhood = TextEditingController();
  final _postalCode = TextEditingController();
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    context.read<RewardOnboardingBloc>().add(const OnboardingStarted());
  }

  @override
  void dispose() {
    _legalName.dispose();
    _email.dispose();
    _taxId.dispose();
    _mobilePhone.dispose();
    _monthlyIncome.dispose();
    _street.dispose();
    _number.dispose();
    _neighborhood.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  void _done() => widget.onDone != null ? widget.onDone!() : Modular.to.pop(true);

  /// Local format check (decisions 153–155): the same rules the API's
  /// `onboardRecipientDto` applies, so a typo is caught before the
  /// round-trip — the API still revalidates everything (decision 47).
  /// Codes are translated through the same key a server field error uses
  /// (`core.fieldErrors.<code>`, decision 83).
  bool _validate() {
    final errors = VgrValidators.validate({
      'legalName': (_legalName.text, [VgrValidators.required]),
      'email': (_email.text, [VgrValidators.email]),
      'taxId': (_taxId.text, [VgrValidators.brTaxId]),
      'mobilePhone': (_mobilePhone.text, [VgrValidators.brPhone]),
      'monthlyIncome': (_monthlyIncome.text, [VgrValidators.positiveNumber]),
      'street': (_street.text, [VgrValidators.required]),
      'number': (_number.text, [VgrValidators.required]),
      'neighborhood': (_neighborhood.text, [VgrValidators.required]),
      'postalCode': (_postalCode.text, [VgrValidators.cep]),
    });
    setState(() => _fieldErrors = {
          for (final e in errors.entries)
            e.key: fieldFailureText(FieldFailure(
              field: e.key,
              message: e.value.code,
              code: e.value.code,
              params: e.value.params,
            )),
        });
    return errors.isEmpty;
  }

  void _submit() {
    if (!_validate()) return;
    context.read<RewardOnboardingBloc>().add(OnboardingSubmitPressed(
          RewardRecipientProfileEntity(
            legalName: _legalName.text.trim(),
            email: _email.text.trim(),
            taxId: unmask(_taxId.text),
            mobilePhone: unmask(_mobilePhone.text),
            monthlyIncome: num.parse(_monthlyIncome.text.trim()),
            street: _street.text.trim(),
            number: _number.text.trim(),
            neighborhood: _neighborhood.text.trim(),
            postalCode: unmask(_postalCode.text),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'rewardOnboarding.title'.tr(),
      body: BlocBuilder<RewardOnboardingBloc, RewardOnboardingState>(
        builder: (context, state) => switch (state) {
          OnboardingLoading() => const VgrLoading(),
          OnboardingLoadError(failure: final failure) => _loadError(failure),
          OnboardingAlreadyDone() => _alreadyDone(),
          OnboardingSuccess() => _success(),
          OnboardingForm() || OnboardingSubmitting() => _form(state),
        },
      ),
    );
  }

  Widget _loadError(Failure failure) => VgrCenter(
        child: VgrColumn(children: [
          VgrText.error(failureText(failure), key: const Key('reward-onboarding-load-error')),
          const VgrGap.md(),
          VgrSecondaryButton(
            key: const Key('reward-onboarding-retry-button'),
            label: 'rewardOnboarding.retry'.tr(),
            onPressed: () =>
                context.read<RewardOnboardingBloc>().add(const OnboardingStarted()),
          ),
        ]),
      );

  Widget _alreadyDone() => VgrCenter(
        child: VgrColumn(
          key: const Key('reward-onboarding-already-done-view'),
          children: [
            const VgrIcon(VgrIconName.check, size: 48),
            const VgrGap.md(),
            VgrText.headline('rewardOnboarding.alreadyDone.title'.tr()),
            const VgrGap.sm(),
            VgrText('rewardOnboarding.alreadyDone.message'.tr()),
            const VgrGap.lg(),
            VgrSecondaryButton(
              key: const Key('reward-onboarding-done-button'),
              label: 'rewardOnboarding.back'.tr(),
              onPressed: _done,
            ),
          ],
        ),
      );

  Widget _success() => VgrCenter(
        child: VgrColumn(
          key: const Key('reward-onboarding-success-view'),
          children: [
            const VgrIcon(VgrIconName.check, size: 48),
            const VgrGap.md(),
            VgrText.headline('rewardOnboarding.success.title'.tr()),
            const VgrGap.sm(),
            VgrText('rewardOnboarding.success.message'.tr()),
            const VgrGap.lg(),
            VgrPrimaryButton(
              key: const Key('reward-onboarding-done-button'),
              label: 'rewardOnboarding.back'.tr(),
              onPressed: _done,
            ),
          ],
        ),
      );

  Widget _form(RewardOnboardingState state) {
    final submitting = state is OnboardingSubmitting;
    final failure = state is OnboardingForm ? state.failure : null;

    return VgrScrollView(
      child: VgrColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VgrText.caption('rewardOnboarding.intro'.tr()),
          const VgrGap.md(),
          VgrTextField(
            key: const Key('reward-onboarding-legal-name-field'),
            controller: _legalName,
            label: 'rewardOnboarding.form.legalName'.tr(),
            enabled: !submitting,
            errorText: _fieldErrors['legalName'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-email-field'),
            controller: _email,
            label: 'rewardOnboarding.form.email'.tr(),
            keyboard: VgrKeyboard.email,
            enabled: !submitting,
            errorText: _fieldErrors['email'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-tax-id-field'),
            controller: _taxId,
            label: 'rewardOnboarding.form.taxId'.tr(),
            keyboard: VgrKeyboard.number,
            mask: VgrMask.cpfCnpj,
            enabled: !submitting,
            errorText: _fieldErrors['taxId'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-mobile-phone-field'),
            controller: _mobilePhone,
            label: 'rewardOnboarding.form.mobilePhone'.tr(),
            keyboard: VgrKeyboard.phone,
            mask: VgrMask.phoneBr,
            enabled: !submitting,
            errorText: _fieldErrors['mobilePhone'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-monthly-income-field'),
            controller: _monthlyIncome,
            label: 'rewardOnboarding.form.monthlyIncome'.tr(),
            keyboard: VgrKeyboard.number,
            enabled: !submitting,
            errorText: _fieldErrors['monthlyIncome'],
          ),
          const VgrGap.md(),
          VgrText.title('rewardOnboarding.form.addressTitle'.tr()),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-street-field'),
            controller: _street,
            label: 'rewardOnboarding.form.street'.tr(),
            enabled: !submitting,
            errorText: _fieldErrors['street'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-number-field'),
            controller: _number,
            label: 'rewardOnboarding.form.number'.tr(),
            enabled: !submitting,
            errorText: _fieldErrors['number'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-neighborhood-field'),
            controller: _neighborhood,
            label: 'rewardOnboarding.form.neighborhood'.tr(),
            enabled: !submitting,
            errorText: _fieldErrors['neighborhood'],
          ),
          const VgrGap.sm(),
          VgrTextField(
            key: const Key('reward-onboarding-postal-code-field'),
            controller: _postalCode,
            label: 'rewardOnboarding.form.postalCode'.tr(),
            keyboard: VgrKeyboard.number,
            mask: VgrMask.cep,
            enabled: !submitting,
            errorText: _fieldErrors['postalCode'],
          ),
          if (failure != null) ...[
            const VgrGap.md(),
            VgrText.error(failureText(failure), key: const Key('reward-onboarding-error')),
          ],
          const VgrGap.lg(),
          VgrPrimaryButton(
            key: const Key('reward-onboarding-submit-button'),
            label: 'rewardOnboarding.submit'.tr(),
            busy: submitting,
            onPressed: submitting ? null : _submit,
          ),
          const VgrGap.lg(),
        ],
      ),
    );
  }
}
