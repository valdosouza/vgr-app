import 'package:core/core.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/register_bloc.dart';

/// Placeholder consent version until the real legal text clears the
/// lawyer review (pendency of decisions 25/30/45/57, via the Legal Gate —
/// decision 8/task 13 only requires that SOME version is recorded).
const _consentVersion = 'v1';

/// Email+password sign-up (decisions 119/123). Reachable from the feed's
/// account action — never required to report (decision 123).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.onDone});

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onDone;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _consentAccepted = false;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_consentAccepted) return;
    context.read<RegisterBloc>().add(RegisterSubmitted(
          displayName: _displayName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          consentVersion: _consentVersion,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.register.title'.tr(),
      body: BlocConsumer<RegisterBloc, RegisterState>(
        listener: (context, state) {
          if (state is RegisterSuccess) {
            widget.onDone != null ? widget.onDone!() : Modular.to.navigate('/');
          }
        },
        builder: (context, state) {
          final submitting = state is RegisterSubmitting;
          final failure = state is RegisterReady ? state.failure : null;

          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VgrTextField(
                  key: const Key('register-display-name-field'),
                  controller: _displayName,
                  label: 'auth.register.displayName'.tr(),
                  enabled: !submitting,
                ),
                const VgrGap.sm(),
                VgrTextField(
                  key: const Key('register-email-field'),
                  controller: _email,
                  label: 'auth.email'.tr(),
                  keyboard: VgrKeyboard.email,
                  enabled: !submitting,
                ),
                const VgrGap.sm(),
                VgrTextField(
                  key: const Key('register-password-field'),
                  controller: _password,
                  label: 'auth.password'.tr(),
                  obscure: true,
                  helperText: 'auth.register.passwordHint'.tr(),
                  enabled: !submitting,
                ),
                const VgrGap.md(),
                VgrCheckboxTile(
                  key: const Key('register-consent-checkbox'),
                  label: 'auth.register.consent'.tr(),
                  value: _consentAccepted,
                  onChanged: submitting
                      ? null
                      : (value) => setState(() => _consentAccepted = value),
                ),
                if (failure != null) ...[
                  const VgrGap.md(),
                  VgrText.error(failureText(failure), key: const Key('register-error')),
                ],
                const VgrGap.lg(),
                VgrPrimaryButton(
                  key: const Key('register-submit-button'),
                  label: 'auth.register.submit'.tr(),
                  busy: submitting,
                  onPressed: !_consentAccepted || submitting ? null : _submit,
                ),
                const VgrGap.md(),
                VgrTextButton(
                  key: const Key('register-go-to-login-link'),
                  label: 'auth.register.haveAccount'.tr(),
                  onPressed: submitting
                      ? null
                      : () => Modular.to.pushNamed('/auth/login/'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
