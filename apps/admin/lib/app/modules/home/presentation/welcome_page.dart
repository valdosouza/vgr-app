import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:vgr_widgets/vgr_widgets.dart';

/// Outlet content right after login, or whenever no screen is picked
/// (decision 215 — setes' `WelcomeFrame`). Nothing to do here: the menu
/// columns beside it are the way in.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return VgrPage(
      title: 'home.welcomeTitle'.tr(),
      body: VgrCenter(
        child: VgrText('home.welcomeMessage'.tr(), key: const Key('home-welcome')),
      ),
    );
  }
}
