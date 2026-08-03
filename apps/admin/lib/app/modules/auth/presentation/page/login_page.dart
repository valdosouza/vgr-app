import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

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
    return Scaffold(
      // No session yet — the switch is local only; the choice is persisted
      // post-login by the Home's selector.
      appBar: AppBar(
        title: Text('auth.loginTitle'.tr()),
        actions: const [LanguageSelector(persist: false)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocConsumer<LoginBloc, LoginState>(
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('login-email-field'),
                  controller: _emailController,
                  enabled: twoFactor == null,
                  decoration: InputDecoration(labelText: 'auth.email'.tr()),
                ),
                TextField(
                  key: const Key('login-password-field'),
                  controller: _passwordController,
                  obscureText: true,
                  enabled: twoFactor == null,
                  onSubmitted: (_) => state is LoginLoading ? null : _submit(context),
                  decoration: InputDecoration(labelText: 'auth.password'.tr()),
                ),
                // Second step (decision 114): credentials were accepted and
                // the account is enrolled — only the code is missing.
                if (twoFactor != null) ...[
                  const SizedBox(height: 8),
                  Text('auth.twoFactor.loginHint'.tr()),
                  TextField(
                    key: const Key('login-totp-field'),
                    controller: _totpController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    onSubmitted: (_) => _submit(context, totpCode: _totpController.text),
                    decoration: InputDecoration(
                      labelText: 'auth.twoFactor.code'.tr(),
                      errorText:
                          twoFactor.invalidCode ? 'auth.twoFactor.invalidCode'.tr() : null,
                    ),
                  ),
                  TextButton(
                    key: const Key('login-use-recovery-code-link'),
                    onPressed: () => Modular.to.pushNamed(
                      '/two-factor-recover',
                      arguments: _emailController.text,
                    ),
                    child: Text('auth.twoFactor.useRecoveryCode'.tr()),
                  ),
                ],
                CheckboxListTile(
                  key: const Key('login-keep-connected-checkbox'),
                  value: _keepConnected,
                  onChanged: (value) => setState(() => _keepConnected = value ?? false),
                  title: Text('auth.keepConnected'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                CheckboxListTile(
                  key: const Key('login-remember-email-checkbox'),
                  value: _rememberEmail,
                  onChanged: (value) => setState(() => _rememberEmail = value ?? false),
                  title: Text('auth.rememberEmail'.tr()),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                const SizedBox(height: 16),
                if (state is LoginError) Text(state.message),
                ElevatedButton(
                  key: const Key('login-submit-button'),
                  onPressed: state is LoginLoading
                      ? null
                      : () => _submit(
                            context,
                            totpCode: twoFactor != null ? _totpController.text : null,
                          ),
                  child: state is LoginLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                      : Text(twoFactor != null ? 'auth.twoFactor.verify'.tr() : 'auth.login'.tr()),
                ),
                TextButton(
                  key: const Key('login-forgot-password-link'),
                  onPressed: () => Modular.to.pushNamed('/recovery-password'),
                  child: Text('auth.forgotPassword'.tr()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
