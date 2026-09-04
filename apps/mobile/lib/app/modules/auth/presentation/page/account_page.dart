import 'package:core/core.dart';
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

  /// The responder request is a real commitment (decision 190 — an admin
  /// will judge it) — confirmed here, same posture as the panic trigger,
  /// BEFORE the bloc ever sees `AccountResponderRequestPressed`.
  Future<void> _requestResponder() async {
    final confirmed = await showVgrConfirm(
      context,
      title: 'auth.account.becomeResponderConfirmTitle'.tr(),
      message: 'auth.account.becomeResponderConfirmMessage'.tr(),
      confirmLabel: 'auth.account.becomeResponderConfirmConfirm'.tr(),
      cancelLabel: 'auth.account.becomeResponderConfirmCancel'.tr(),
      confirmKey: const Key('account-become-responder-confirm'),
      cancelKey: const Key('account-become-responder-cancel'),
    );
    if (confirmed && mounted) {
      context.read<AccountBloc>().add(const AccountResponderRequestPressed());
    }
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
          final responderRequestSent = state is AccountReady && state.responderRequestSent;
          final responderRequestSending = state is AccountReady && state.responderRequestSending;
          final responderRequestFailure =
              state is AccountReady ? state.responderRequestFailure : null;
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
                // The now-reachable responder-authorization request
                // (decision 190, PP2) — a local flag is the ONLY guard
                // against re-inviting a duplicate `POST`, since no PP1
                // endpoint reads membership status back (see
                // `panic_repository.dart`'s doc comment): once sent, this
                // tile never re-invites a tap.
                VgrListTile(
                  key: const Key('account-become-responder-tile'),
                  leadingIcon: VgrIconName.panic,
                  title: 'auth.account.becomeResponder'.tr(),
                  subtitle: responderRequestSent
                      ? 'auth.account.becomeResponderSent'.tr()
                      : responderRequestSending
                          ? 'auth.account.becomeResponderSending'.tr()
                          : 'auth.account.becomeResponderHint'.tr(),
                  onTap: responderRequestSent || responderRequestSending
                      ? null
                      : _requestResponder,
                ),
                if (responderRequestFailure != null)
                  VgrText.error(
                    failureText(responderRequestFailure),
                    key: const Key('account-become-responder-error'),
                  ),
                VgrListTile(
                  key: const Key('account-my-alerts-tile'),
                  leadingIcon: VgrIconName.alert,
                  title: 'auth.account.myAlerts'.tr(),
                  subtitle: 'auth.account.myAlertsHint'.tr(),
                  onTap: () => Modular.to.pushNamed('/panic/alerts'),
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
