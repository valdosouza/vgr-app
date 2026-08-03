import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'presentation/home_page.dart';

/// Every route in this module requires Role=admin (decision 56).
class HomeModule extends Module {
  @override
  List<ModularRoute> get routes => [
        ChildRoute(
          '/',
          child: (_, __) => const HomePage(),
          guards: [AdminSessionGuard(Modular.get<IdentityBloc>())],
        ),
      ];
}
