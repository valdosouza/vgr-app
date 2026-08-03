import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('auth.twoFactor.setupTitle'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: BlocBuilder<TwoFactorBloc, TwoFactorState>(
            builder: (context, state) => switch (state) {
              TwoFactorLoading() => const Center(child: CircularProgressIndicator()),
              TwoFactorError(:final message) => Text(
                  message,
                  key: const Key('two-factor-error'),
                ),
              TwoFactorSetupReady(:final setup, :final invalidCode) =>
                _buildSetup(context, setup, invalidCode),
              TwoFactorActivated(:final activation) => _buildRecoveryCodes(context, activation),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSetup(BuildContext context, setup, bool invalidCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('auth.twoFactor.setupHint'.tr()),
        const SizedBox(height: 16),
        SelectableText(
          setup.secret,
          key: const Key('two-factor-secret'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextButton.icon(
          key: const Key('two-factor-copy-secret'),
          onPressed: () => Clipboard.setData(ClipboardData(text: setup.secret)),
          icon: const Icon(Icons.copy),
          label: Text('auth.twoFactor.copySecret'.tr()),
        ),
        const SizedBox(height: 8),
        SelectableText(setup.otpauthUri, key: const Key('two-factor-uri')),
        const SizedBox(height: 24),
        TextField(
          key: const Key('two-factor-code-field'),
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'auth.twoFactor.code'.tr(),
            errorText: invalidCode ? 'auth.twoFactor.invalidCode'.tr() : null,
          ),
        ),
        ElevatedButton(
          key: const Key('two-factor-activate-button'),
          onPressed: () => context.read<TwoFactorBloc>().add(
                TwoFactorCodeSubmitted(
                  enrollToken: widget.enrollToken,
                  code: _codeController.text,
                ),
              ),
          child: Text('auth.twoFactor.activate'.tr()),
        ),
      ],
    );
  }

  Widget _buildRecoveryCodes(BuildContext context, activation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'auth.twoFactor.recoveryCodesTitle'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Shown exactly once — the API stores them hashed and cannot show
        // them again (decision 114).
        Text('auth.twoFactor.recoveryCodesHint'.tr()),
        const SizedBox(height: 16),
        SelectableText(
          activation.recoveryCodes.join('\n'),
          key: const Key('two-factor-recovery-codes'),
          style: const TextStyle(fontFamily: 'monospace', height: 1.6),
        ),
        TextButton.icon(
          key: const Key('two-factor-copy-codes'),
          onPressed: () => Clipboard.setData(
            ClipboardData(text: activation.recoveryCodes.join('\n')),
          ),
          icon: const Icon(Icons.copy),
          label: Text('auth.twoFactor.copyCodes'.tr()),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('two-factor-confirm-saved-button'),
          onPressed: () => widget.onActivated(activation.jwt),
          child: Text('auth.twoFactor.confirmSaved'.tr()),
        ),
      ],
    );
  }
}
