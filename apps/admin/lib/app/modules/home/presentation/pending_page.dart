import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;
import 'package:vgr_widgets/vgr_widgets.dart';

/// Placeholder for interfaces cataloged in tb_interface whose screen has
/// not been built yet (setes' pending rule).
class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return VgrScaffold(
      title: 'home.pendingTitle'.tr(),
      body: VgrCenter(
        child: VgrColumn(
          children: [
            VgrText('home.pendingMessage'.tr()),
            const VgrGap.md(),
            VgrPrimaryButton(
              label: 'home.backToMenu'.tr(),
              onPressed: () => Modular.to.navigate('/'),
            ),
          ],
        ),
      ),
    );
  }
}
