import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

/// Central map i18nKey → route (mirrors setes-app's interface_routes rule:
/// registering a new screen = one entry here + one ModularRoute).
/// Keys must match tb_interface.i18n_key (migration 019).
const interfaceRoutes = <String, String>{
  'case_freeze': '/case-freeze',
  'legal_jurisdictions': '/legal/jurisdictions',
  'legal_capabilities': '/legal/capabilities',
  'legal_rules': '/legal/rules',
  'risk_config': '/risk-config',
  'category_forms': '/category-forms',
  'panic_responders': '/panic-responders',
  'dual_control_access': '/dual-control-access',
  'monetization_config': '/monetization-config',
  'privileges': '/privileges',
  'interfaces': '/interfaces',
  'system_modules': '/system-modules',
  'users': '/users',
};

/// Cataloged interface without a screen yet → pending placeholder.
const pendingRoute = '/pending';

void navigateToInterface(MenuInterface screen) {
  Modular.to.navigate(interfaceRoutes[screen.i18nKey] ?? pendingRoute);
}
