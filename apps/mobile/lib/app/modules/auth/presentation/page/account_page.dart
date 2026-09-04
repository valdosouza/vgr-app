import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

import '../bloc/account_bloc.dart';

/// Small hub for an identified account — reached from the feed's account
/// action. Everything here is optional (decision 123): the app works
/// fully without ever visiting this screen.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.onSignedOut});

  /// Test seam — default navigation goes through Modular.
  final VoidCallback? onSignedOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(const AccountStarted());
  }

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'auth.account.title'.tr(),
      body: BlocConsumer<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is AccountSignedOut) {
            widget.onSignedOut != null ? widget.onSignedOut!() : Modular.to.navigate('/');
          }
        },
        builder: (context, state) {
          final signingOut = state is AccountSigningOut;
          final reputation = state is AccountReady ? state.reputation : null;
          return VgrScrollView(
            child: VgrColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VgrListTile(
                  key: const Key('account-verify-email-tile'),
                  leadingIcon: VgrIconName.check,
                  title: 'auth.account.verifyEmail'.tr(),
                  subtitle: 'auth.account.verifyEmailHint'.tr(),
                  onTap: () => Modular.to.pushNamed('/auth/verify-email/'),
                ),
                if (reputation != null) ...[
                  const VgrGap.lg(),
                  VgrText.title('auth.account.reputationTitle'.tr()),
                  const VgrGap.sm(),
                  // My OWN aggregate only (184/185) — count always,
                  // average exactly as served: null below the API's own
                  // k-anonymity floor, which this screen never recomputes.
                  VgrText(
                    'auth.account.reputationCount'
                        .tr(namedArgs: {'count': '${reputation.count}'}),
                    key: const Key('account-reputation-count'),
                  ),
                  const VgrGap.sm(),
                  if (reputation.average != null)
                    VgrText(
                      'auth.account.reputationAverage'.tr(
                          namedArgs: {'average': reputation.average!.toStringAsFixed(2)}),
                      key: const Key('account-reputation-average'),
                    )
                  else
                    VgrText.caption(
                      'auth.account.reputationNotEnough'.tr(),
                      key: const Key('account-reputation-not-enough'),
                    ),
                ],
                const VgrGap.lg(),
                VgrSecondaryButton(
                  key: const Key('account-sign-out-button'),
                  label: 'auth.account.signOut'.tr(),
                  onPressed: signingOut
                      ? null
                      : () => context.read<AccountBloc>().add(const AccountSignOutPressed()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
