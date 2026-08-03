import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vgr_admin/app/app_module.dart';
import 'package:vgr_admin/app/app_widget.dart';

import '../../../helpers/pump_localized.dart';

void main() {
  tearDown(Modular.destroy);

  testWidgets(
    'non-admin session is redirected to the login page from every admin route',
    (tester) async {
      await pumpLocalizedApp(tester, ModularApp(module: AppModule(), child: const AppWidget()));

      expect(find.byKey(const Key('login-email-field')), findsOneWidget);
      expect(find.text('VGR Admin'), findsNothing);
    },
  );
}
