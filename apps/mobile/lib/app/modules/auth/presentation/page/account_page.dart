import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/account_bloc.dart';

/// Small hub for an identified account — reached from the feed's account
/// action. Everything here is optional (decision 123): the app works
/// fully without ever visiting this screen.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, this.onSignedOut});

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onSignedOut;

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.account.title'.tr(),
      body: BlocConsumer<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is AccountSignedOut) {
            onSignedOut != null ? onSignedOut!() : Modular.to.navigate('/');
          }
        },
        builder: (context, state) {
          final signingOut = state is AccountSigningOut;
          return VgrColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VgrListTile(
                key: const Key('account-verify-email-tile'),
                leadingIcon: VgrIconName.check,
                title: 'auth.account.verifyEmail'.tr(),
                subtitle: 'auth.account.verifyEmailHint'.tr(),
                onTap: () => Modular.to.pushNamed('/auth/verify-email/'),
              ),
              const VgrGap.lg(),
              VgrSecondaryButton(
                key: const Key('account-sign-out-button'),
                label: 'auth.account.signOut'.tr(),
                onPressed: signingOut
                    ? null
                    : () => context.read<AccountBloc>().add(const AccountSignOutPressed()),
              ),
            ],
          );
        },
      ),
    );
  }
}
