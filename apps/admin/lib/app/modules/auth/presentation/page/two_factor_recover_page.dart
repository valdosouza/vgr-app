import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

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
    return VgrScaffold(
      title: 'auth.twoFactor.recoverTitle'.tr(),
      body: VgrColumn(
        children: [
          VgrText('auth.twoFactor.recoverHint'.tr()),
          const VgrGap.md(),
          VgrTextField(
            key: const Key('recover-email-field'),
            controller: _emailController,
            label: 'auth.email'.tr(),
            keyboard: VgrKeyboard.email,
          ),
          VgrTextField(
            key: const Key('recover-password-field'),
            controller: _passwordController,
            label: 'auth.password'.tr(),
            obscure: true,
          ),
          VgrTextField(
            key: const Key('recover-code-field'),
            controller: _codeController,
            label: 'auth.twoFactor.recoveryCode'.tr(),
          ),
          const VgrGap.md(),
          if (_error != null) VgrText.error(_error!, key: const Key('recover-error')),
          VgrPrimaryButton(
            key: const Key('recover-submit-button'),
            label: 'auth.twoFactor.recoverAction'.tr(),
            busy: _loading,
            onPressed: _submit,
          ),
          VgrTextButton(
            key: const Key('recover-back-to-login-link'),
            label: 'auth.backToLogin'.tr(),
            onPressed: () => Modular.to.navigate('/login'),
          ),
        ],
      ),
    );
  }
}
