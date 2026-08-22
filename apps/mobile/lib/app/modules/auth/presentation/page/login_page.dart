import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/login_bloc.dart';

/// Email+password login (decisions 119/122/124).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onDone});

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onDone;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  void _submit({String? totpCode}) {
    context.read<LoginBloc>().add(LoginSubmitted(
          email: _email.text.trim(),
          password: _password.text,
          totpCode: totpCode,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.login.title'.tr(),
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            widget.onDone != null ? widget.onDone!() : Modular.to.navigate('/');
          }
        },
        builder: (context, state) {
          final twoFactor = state is LoginTwoFactorRequired ? state : null;
          final submitting = state is LoginSubmitting;
          final failure = state is LoginReady ? state.failure : null;

          return VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VgrTextField(
                key: const Key('login-email-field'),
                controller: _email,
                label: 'auth.email'.tr(),
                keyboard: VgrKeyboard.email,
                enabled: twoFactor == null && !submitting,
              ),
              const VgrGap.sm(),
              VgrTextField(
                key: const Key('login-password-field'),
                controller: _password,
                label: 'auth.password'.tr(),
                obscure: true,
                enabled: twoFactor == null && !submitting,
                onSubmitted: (_) => submitting ? null : _submit(),
              ),
              if (twoFactor != null) ...[
                const VgrGap.sm(),
                VgrText('auth.login.twoFactorHint'.tr()),
                VgrTextField(
                  key: const Key('login-totp-field'),
                  controller: _totp,
                  label: 'auth.login.twoFactorCode'.tr(),
                  keyboard: VgrKeyboard.number,
                  maxLength: 6,
                  autofocus: true,
                  errorText: twoFactor.invalidCode ? 'auth.login.invalidCode'.tr() : null,
                  onSubmitted: (_) => _submit(totpCode: _totp.text),
                ),
              ],
              if (failure != null) ...[
                const VgrGap.md(),
                VgrText.error(failureText(failure), key: const Key('login-error')),
              ],
              const VgrGap.lg(),
              VgrPrimaryButton(
                key: const Key('login-submit-button'),
                label: twoFactor != null ? 'auth.login.verify'.tr() : 'auth.login.submit'.tr(),
                busy: submitting,
                onPressed: () => _submit(totpCode: twoFactor != null ? _totp.text : null),
              ),
              if (twoFactor == null) ...[
                const VgrGap.md(),
                VgrSecondaryButton(
                  key: const Key('login-google-button'),
                  label: 'auth.login.google'.tr(),
                  onPressed: submitting
                      ? null
                      : () => context.read<LoginBloc>().add(const LoginWithGooglePressed()),
                ),
              ],
              const VgrGap.md(),
              VgrTextButton(
                key: const Key('login-go-to-register-link'),
                label: 'auth.login.noAccount'.tr(),
                onPressed: submitting ? null : () => Modular.to.pushNamed('/auth/register/'),
              ),
            ],
          );
        },
      ),
    );
  }
}
