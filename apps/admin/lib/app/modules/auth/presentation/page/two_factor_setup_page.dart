import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

import '../../domain/login_result.dart';
import '../bloc/two_factor_bloc.dart';

/// Mandatory TOTP enrollment (decision 114). Reached only from the login
/// flow, holding the short-lived enroll token — there is no session yet.
///
/// The secret is shown as text plus the otpauth URI: no QR package is
/// pulled in for this (decision 118 — dependencies in the auth path pay
/// their way or stay out), and every authenticator accepts manual entry.
class TwoFactorSetupPage extends StatefulWidget {
  const TwoFactorSetupPage({
    super.key,
    required this.enrollToken,
    required this.onActivated,
  });

  final String enrollToken;

  /// Called with the session JWT once the user confirms they stored the
  /// recovery codes — the login bloc opens the session from there.
  final void Function(String jwt) onActivated;

  @override
  State<TwoFactorSetupPage> createState() => _TwoFactorSetupPageState();
}

class _TwoFactorSetupPageState extends State<TwoFactorSetupPage> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TwoFactorBloc>().add(TwoFactorSetupRequested(widget.enrollToken));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.twoFactor.setupTitle'.tr(),
      body: VgrScrollView(
        child: BlocBuilder<TwoFactorBloc, TwoFactorState>(
          builder: (context, state) => switch (state) {
            TwoFactorLoading() => const VgrLoading(),
            TwoFactorError(:final message) => VgrText.error(
                message,
                key: const Key('two-factor-error'),
              ),
            TwoFactorSetupReady(:final setup, :final invalidCode) =>
              _buildSetup(context, setup, invalidCode),
            TwoFactorActivated(:final activation) => _buildRecoveryCodes(context, activation),
          },
        ),
      ),
    );
  }

  Widget _buildSetup(BuildContext context, TwoFactorSetup setup, bool invalidCode) {
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrText('auth.twoFactor.setupHint'.tr()),
        const VgrGap.md(),
        VgrSelectableText(
          setup.secret,
          key: const Key('two-factor-secret'),
          role: VgrTextRole.headline,
        ),
        VgrTextButton(
          key: const Key('two-factor-copy-secret'),
          icon: VgrIconName.copy,
          label: 'auth.twoFactor.copySecret'.tr(),
          onPressed: () => Clipboard.setData(ClipboardData(text: setup.secret)),
        ),
        const VgrGap.sm(),
        VgrSelectableText(setup.otpauthUri, key: const Key('two-factor-uri')),
        const VgrGap.lg(),
        VgrTextField(
          key: const Key('two-factor-code-field'),
          controller: _codeController,
          label: 'auth.twoFactor.code'.tr(),
          keyboard: VgrKeyboard.number,
          maxLength: 6,
          errorText: invalidCode ? 'auth.twoFactor.invalidCode'.tr() : null,
        ),
        VgrPrimaryButton(
          key: const Key('two-factor-activate-button'),
          label: 'auth.twoFactor.activate'.tr(),
          onPressed: () => context.read<TwoFactorBloc>().add(
                TwoFactorCodeSubmitted(
                  enrollToken: widget.enrollToken,
                  code: _codeController.text,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildRecoveryCodes(BuildContext context, TwoFactorActivation activation) {
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrText.title('auth.twoFactor.recoveryCodesTitle'.tr()),
        const VgrGap.sm(),
        // Shown exactly once — the API stores them hashed and cannot show
        // them again (decision 114).
        VgrText('auth.twoFactor.recoveryCodesHint'.tr()),
        const VgrGap.md(),
        VgrSelectableText(
          activation.recoveryCodes.join('\n'),
          key: const Key('two-factor-recovery-codes'),
          monospace: true,
        ),
        VgrTextButton(
          key: const Key('two-factor-copy-codes'),
          icon: VgrIconName.copy,
          label: 'auth.twoFactor.copyCodes'.tr(),
          onPressed: () => Clipboard.setData(
            ClipboardData(text: activation.recoveryCodes.join('\n')),
          ),
        ),
        const VgrGap.lg(),
        VgrPrimaryButton(
          key: const Key('two-factor-confirm-saved-button'),
          label: 'auth.twoFactor.confirmSaved'.tr(),
          onPressed: () => widget.onActivated(activation.jwt),
        ),
      ],
    );
  }
}
