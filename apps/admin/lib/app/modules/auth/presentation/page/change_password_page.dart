import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

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
    return VgrScaffold(
      title: 'auth.changeTitle'.tr(),
      body: BlocConsumer<RecoveryBloc, RecoveryState>(
        listener: (context, state) {
          if (state is PasswordChanged) {
            showVgrMessage(context, 'auth.passwordChanged'.tr());
            Modular.to.navigate('/login');
          }
        },
        builder: (context, state) {
          return VgrColumn(
            children: [
              VgrText('auth.codeSent'.tr()),
              VgrTextField(
                key: const Key('change-email-field'),
                controller: _emailController,
                label: 'auth.email'.tr(),
                keyboard: VgrKeyboard.email,
              ),
              VgrTextField(
                key: const Key('change-code-field'),
                controller: _codeController,
                label: 'auth.code'.tr(),
                keyboard: VgrKeyboard.number,
                maxLength: 6,
              ),
              VgrTextField(
                key: const Key('change-new-password-field'),
                controller: _newPasswordController,
                label: 'auth.newPassword'.tr(),
                obscure: true,
              ),
              const VgrGap.md(),
              if (state is RecoveryError) VgrText.error(state.message),
              VgrPrimaryButton(
                key: const Key('change-submit-button'),
                label: 'auth.changePassword'.tr(),
                busy: state is RecoveryLoading,
                onPressed: () => context.read<RecoveryBloc>().add(ChangePasswordSubmitted(
                      email: _emailController.text,
                      code: _codeController.text,
                      newPassword: _newPasswordController.text,
                    )),
              ),
              VgrTextButton(
                key: const Key('change-back-to-login-link'),
                label: 'auth.backToLogin'.tr(),
                onPressed: () => Modular.to.navigate('/login'),
              ),
            ],
          );
        },
      ),
    );
  }
}
