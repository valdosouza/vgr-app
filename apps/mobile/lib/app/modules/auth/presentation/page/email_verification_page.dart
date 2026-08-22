import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/email_verification_bloc.dart';

/// Confirms the account's email (decision 151) — never required to report
/// (decision 123), only before consequential actions such as offering or
/// claiming a reward.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, this.onDone});

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onDone;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _done() => widget.onDone != null ? widget.onDone!() : Modular.to.pop(true);

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.verifyEmail.title'.tr(),
      body: BlocBuilder<EmailVerificationBloc, EmailVerificationState>(
        builder: (context, state) => switch (state) {
          EmailVerificationSuccess() => _success(),
          EmailVerificationIdle() ||
          EmailVerificationSending() ||
          EmailVerificationSendFailed() =>
            _sendStep(state),
          EmailVerificationCodeSent() || EmailVerificationConfirming() => _codeStep(state),
        },
      ),
    );
  }

  Widget _sendStep(EmailVerificationState state) {
    final sending = state is EmailVerificationSending;
    final failure = state is EmailVerificationSendFailed ? state.failure : null;
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrText('auth.verifyEmail.intro'.tr()),
        if (failure != null) ...[
          const VgrGap.md(),
          VgrText.error(failureText(failure), key: const Key('verify-email-send-error')),
        ],
        const VgrGap.lg(),
        VgrPrimaryButton(
          key: const Key('verify-email-send-button'),
          label: 'auth.verifyEmail.send'.tr(),
          busy: sending,
          onPressed: sending
              ? null
              : () => context.read<EmailVerificationBloc>().add(
                    const EmailVerificationSendPressed(),
                  ),
        ),
      ],
    );
  }

  Widget _codeStep(EmailVerificationState state) {
    final confirming = state is EmailVerificationConfirming;
    final failure = state is EmailVerificationCodeSent ? state.failure : null;
    return VgrColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VgrText('auth.verifyEmail.codeSent'.tr(), key: const Key('verify-email-code-sent')),
        const VgrGap.sm(),
        VgrTextField(
          key: const Key('verify-email-code-field'),
          controller: _code,
          label: 'auth.verifyEmail.code'.tr(),
          keyboard: VgrKeyboard.number,
          maxLength: 6,
          autofocus: true,
          enabled: !confirming,
          // The API reuses the generic UNAUTHORIZED code here (decision
          // 151, same shape as the panel's recovery flow) — its code
          // translation reads "session expired", which is wrong for a
          // bad verification code. The raw English message is accurate.
          errorText: failure?.message,
        ),
        const VgrGap.lg(),
        VgrPrimaryButton(
          key: const Key('verify-email-confirm-button'),
          label: 'auth.verifyEmail.confirm'.tr(),
          busy: confirming,
          onPressed: confirming
              ? null
              : () => context
                  .read<EmailVerificationBloc>()
                  .add(EmailVerificationConfirmPressed(_code.text.trim())),
        ),
        const VgrGap.sm(),
        VgrTextButton(
          key: const Key('verify-email-resend-link'),
          label: 'auth.verifyEmail.resend'.tr(),
          onPressed: confirming
              ? null
              : () => context.read<EmailVerificationBloc>().add(
                    const EmailVerificationSendPressed(),
                  ),
        ),
      ],
    );
  }

  Widget _success() => VgrCenter(
        child: VgrColumn(
          key: const Key('verify-email-success-view'),
          children: [
            const VgrIcon(VgrIconName.check, size: 48),
            const VgrGap.md(),
            VgrText.headline('auth.verifyEmail.success.title'.tr()),
            const VgrGap.lg(),
            VgrSecondaryButton(
              key: const Key('verify-email-done-button'),
              label: 'auth.verifyEmail.success.back'.tr(),
              onPressed: _done,
            ),
          ],
        ),
      );
}
