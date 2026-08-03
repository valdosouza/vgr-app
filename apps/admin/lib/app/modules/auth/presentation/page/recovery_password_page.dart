import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

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
    return VgrScaffold(
      title: 'auth.recoveryTitle'.tr(),
      body: BlocConsumer<RecoveryBloc, RecoveryState>(
        listener: (context, state) {
          if (state is RecoveryCodeSent) {
            Modular.to.pushReplacementNamed('/change-password', arguments: state.email);
          }
        },
        builder: (context, state) {
          return VgrColumn(
            children: [
              VgrText('auth.recoveryHint'.tr()),
              VgrTextField(
                key: const Key('recovery-email-field'),
                controller: _emailController,
                label: 'auth.email'.tr(),
                keyboard: VgrKeyboard.email,
              ),
              const VgrGap.md(),
              if (state is RecoveryError) VgrText.error(state.message),
              VgrPrimaryButton(
                key: const Key('recovery-submit-button'),
                label: 'auth.sendCode'.tr(),
                busy: state is RecoveryLoading,
                onPressed: () =>
                    context.read<RecoveryBloc>().add(RecoveryCodeRequested(_emailController.text)),
              ),
              VgrTextButton(
                key: const Key('recovery-back-to-login-link'),
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
