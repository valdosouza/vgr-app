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
    super.dispose();
  }

  void _submit(BuildContext context) {
    context.read<LoginBloc>().add(LoginSubmitted(
          email: _emailController.text,
          password: _passwordController.text,
          keepConnected: _keepConnected,
          rememberEmail: _rememberEmail,
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
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('login-email-field'),
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'auth.email'.tr()),
                ),
                TextField(
                  key: const Key('login-password-field'),
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => state is LoginLoading ? null : _submit(context),
                  decoration: InputDecoration(labelText: 'auth.password'.tr()),
                ),
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
                  onPressed: state is LoginLoading ? null : () => _submit(context),
                  child: state is LoginLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                      : Text('auth.login'.tr()),
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
