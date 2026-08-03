import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

import '../bloc/recovery_bloc.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.email});

  /// Prefilled when arriving from the recovery page.
  final String? email;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.changeTitle'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocConsumer<RecoveryBloc, RecoveryState>(
          listener: (context, state) {
            if (state is PasswordChanged) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('auth.passwordChanged'.tr())),
              );
              Modular.to.navigate('/login');
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('auth.codeSent'.tr()),
                TextField(
                  key: const Key('change-email-field'),
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'auth.email'.tr()),
                ),
                TextField(
                  key: const Key('change-code-field'),
                  controller: _codeController,
                  decoration: InputDecoration(labelText: 'auth.code'.tr()),
                ),
                TextField(
                  key: const Key('change-new-password-field'),
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'auth.newPassword'.tr()),
                ),
                const SizedBox(height: 16),
                if (state is RecoveryError) Text(state.message),
                ElevatedButton(
                  key: const Key('change-submit-button'),
                  onPressed: state is RecoveryLoading
                      ? null
                      : () => context.read<RecoveryBloc>().add(ChangePasswordSubmitted(
                            email: _emailController.text,
                            code: _codeController.text,
                            newPassword: _newPasswordController.text,
                          )),
                  child: state is RecoveryLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                      : Text('auth.changePassword'.tr()),
                ),
                TextButton(
                  key: const Key('change-back-to-login-link'),
                  onPressed: () => Modular.to.navigate('/login'),
                  child: Text('auth.backToLogin'.tr()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
