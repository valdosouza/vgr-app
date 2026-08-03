import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

import '../bloc/recovery_bloc.dart';

class RecoveryPasswordPage extends StatefulWidget {
  const RecoveryPasswordPage({super.key});

  @override
  State<RecoveryPasswordPage> createState() => _RecoveryPasswordPageState();
}

class _RecoveryPasswordPageState extends State<RecoveryPasswordPage> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.recoveryTitle'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocConsumer<RecoveryBloc, RecoveryState>(
          listener: (context, state) {
            if (state is RecoveryCodeSent) {
              Modular.to.pushReplacementNamed('/change-password', arguments: state.email);
            }
          },
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('auth.recoveryHint'.tr()),
                TextField(
                  key: const Key('recovery-email-field'),
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'auth.email'.tr()),
                ),
                const SizedBox(height: 16),
                if (state is RecoveryError) Text(state.message),
                ElevatedButton(
                  key: const Key('recovery-submit-button'),
                  onPressed: state is RecoveryLoading
                      ? null
                      : () => context
                          .read<RecoveryBloc>()
                          .add(RecoveryCodeRequested(_emailController.text)),
                  child: state is RecoveryLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                      : Text('auth.sendCode'.tr()),
                ),
                TextButton(
                  key: const Key('recovery-back-to-login-link'),
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
