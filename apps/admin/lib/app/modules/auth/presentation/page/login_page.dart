import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/login_bloc.dart';
import '../bloc/login_event.dart';
import '../bloc/login_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();
  bool _keepConnected = false;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    context.read<LoginBloc>().add(const LoginPrefsRequested());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context, {String? totpCode}) {
    context.read<LoginBloc>().add(LoginSubmitted(
          email: _emailController.text,
          password: _passwordController.text,
          keepConnected: _keepConnected,
          rememberEmail: _rememberEmail,
          totpCode: totpCode,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.loginTitle'.tr(),
      // No session yet — the switch is local only; the choice is persisted
      // post-login by the Home's selector.
      actions: const [LanguageSelector(persist: false)],
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            Modular.to.navigate('/');
          }
          if (state is LoginEnrollmentPending) {
            // Decision 114: no session exists until enrollment completes.
            Modular.to.pushNamed('/two-factor-setup', arguments: {
              'enrollToken': state.enrollToken,
              'keepConnected': state.keepConnected,
            });
          }
          if (state is LoginPrefsLoaded) {
            setState(() {
              _keepConnected = state.keepConnected;
              _rememberEmail = state.rememberedEmail != null;
              if (state.rememberedEmail != null) {
                _emailController.text = state.rememberedEmail!;
              }
            });
          }
        },
        builder: (context, state) {
          final twoFactor = state is LoginTwoFactorRequired ? state : null;
          return VgrColumn(
            children: [
              VgrTextField(
                key: const Key('login-email-field'),
                controller: _emailController,
                label: 'auth.email'.tr(),
                keyboard: VgrKeyboard.email,
                enabled: twoFactor == null,
              ),
              VgrTextField(
                key: const Key('login-password-field'),
                controller: _passwordController,
                label: 'auth.password'.tr(),
                obscure: true,
                enabled: twoFactor == null,
                onSubmitted: (_) => state is LoginLoading ? null : _submit(context),
              ),
              // Second step (decision 114): credentials were accepted and
              // the account is enrolled — only the code is missing.
              if (twoFactor != null) ...[
                const VgrGap.sm(),
                VgrText('auth.twoFactor.loginHint'.tr()),
                VgrTextField(
                  key: const Key('login-totp-field'),
                  controller: _totpController,
                  label: 'auth.twoFactor.code'.tr(),
                  keyboard: VgrKeyboard.number,
                  maxLength: 6,
                  autofocus: true,
                  errorText: twoFactor.invalidCode ? 'auth.twoFactor.invalidCode'.tr() : null,
                  onSubmitted: (_) => _submit(context, totpCode: _totpController.text),
                ),
                VgrTextButton(
                  key: const Key('login-use-recovery-code-link'),
                  label: 'auth.twoFactor.useRecoveryCode'.tr(),
                  onPressed: () => Modular.to.pushNamed(
                    '/two-factor-recover',
                    arguments: _emailController.text,
                  ),
                ),
              ],
              VgrCheckboxTile(
                key: const Key('login-keep-connected-checkbox'),
                value: _keepConnected,
                onChanged: (value) => setState(() => _keepConnected = value),
                label: 'auth.keepConnected'.tr(),
              ),
              VgrCheckboxTile(
                key: const Key('login-remember-email-checkbox'),
                value: _rememberEmail,
                onChanged: (value) => setState(() => _rememberEmail = value),
                label: 'auth.rememberEmail'.tr(),
              ),
              const VgrGap.md(),
              if (state is LoginError) VgrText.error(state.message),
              VgrPrimaryButton(
                key: const Key('login-submit-button'),
                label: twoFactor != null ? 'auth.twoFactor.verify'.tr() : 'auth.login'.tr(),
                busy: state is LoginLoading,
                onPressed: () => _submit(
                  context,
                  totpCode: twoFactor != null ? _totpController.text : null,
                ),
              ),
              VgrTextButton(
                key: const Key('login-forgot-password-link'),
                label: 'auth.forgotPassword'.tr(),
                onPressed: () => Modular.to.pushNamed('/recovery-password'),
              ),
            ],
          );
        },
      ),
    );
  }
}
