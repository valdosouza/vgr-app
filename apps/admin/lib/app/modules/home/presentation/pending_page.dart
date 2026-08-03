import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

/// Placeholder for interfaces cataloged in tb_interface whose screen has
/// not been built yet (setes' pending rule).
class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('home.pendingTitle'.tr())),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('home.pendingMessage'.tr()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Modular.to.navigate('/'),
              child: Text('home.backToMenu'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
