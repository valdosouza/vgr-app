import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

import '../../domain/repository/auth_repository.dart';

/// "Lost my phone" (decision 114): password + one unused recovery code
/// opens a session and clears TOTP, so the next login re-enrolls. An admin
/// with neither device nor codes is unlocked by ANOTHER admin through the
/// dual-control reset — never by a shortcut here (decision 70).
class TwoFactorRecoverPage extends StatefulWidget {
  const TwoFactorRecoverPage({
    super.key,
    required this.repository,
    required this.onRecovered,
    this.initialEmail,
  });

  final AuthRepository repository;
  final void Function(String jwt) onRecovered;
  final String? initialEmail;

  @override
  State<TwoFactorRecoverPage> createState() => _TwoFactorRecoverPageState();
}

class _TwoFactorRecoverPageState extends State<TwoFactorRecoverPage> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.repository.recoverWithBackupCode(
      _emailController.text,
      _passwordController.text,
      _codeController.text,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loading = false;
        _error = failureText(failure);
      }),
      (jwt) {
        setState(() => _loading = false);
        widget.onRecovered(jwt);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.twoFactor.recoverTitle'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('auth.twoFactor.recoverHint'.tr()),
            const SizedBox(height: 16),
            TextField(
              key: const Key('recover-email-field'),
              controller: _emailController,
              decoration: InputDecoration(labelText: 'auth.email'.tr()),
            ),
            TextField(
              key: const Key('recover-password-field'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password'.tr()),
            ),
            TextField(
              key: const Key('recover-code-field'),
              controller: _codeController,
              decoration: InputDecoration(labelText: 'auth.twoFactor.recoveryCode'.tr()),
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, key: const Key('recover-error')),
            ElevatedButton(
              key: const Key('recover-submit-button'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator())
                  : Text('auth.twoFactor.recoverAction'.tr()),
            ),
            TextButton(
              key: const Key('recover-back-to-login-link'),
              onPressed: () => Modular.to.navigate('/login'),
              child: Text('auth.backToLogin'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
