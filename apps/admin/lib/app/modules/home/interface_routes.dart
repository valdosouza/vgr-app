import 'package:core/core.dart';
import 'package:flutter_modular/flutter_modular.dart' hide ModularWatchExtension;

/// Central map i18nKey → route (mirrors setes-app's interface_routes rule:
/// registering a new screen = one entry here + one ModularRoute in
/// `home_module.dart`). Keys must match tb_interface.i18n_key (migration
/// 019). A MODULE root ends with `/` — the canonical form flutter_modular
/// wants (it warned on every click without it); a plain child route inside
/// a module does not.
const interfaceRoutes = <String, String>{
  'case_freeze': '/case-freeze/',
  'reports': '/reports/',
  'report_stats': '/report-stats/',
  'admin_audit': '/admin-audit/',
  'reward_mediation': '/reward-mediation/',
  // Legal Gate screens are plain child routes of one module, so no
  // trailing slash (see pendingRoute below for the rule).
  'legal_jurisdictions': '/legal/jurisdictions',
  'legal_capabilities': '/legal/capabilities',
  'legal_rules': '/legal/rules',
  'risk_config': '/risk-config/',
  'category_forms': '/category-forms/',
  'panic_responders': '/panic-responders/',
  'dual_control_access': '/dual-control-access/',
  'monetization_config': '/monetization-config/',
  'privileges': '/privileges/',
  'interfaces': '/interfaces/',
  'system_modules': '/system-modules/',
  'users': '/users/',
};

/// Cataloged interface without a screen yet → pending placeholder. Plain
/// child routes (not module roots) are registered WITHOUT the trailing
/// slash by flutter_modular 5.0.3, and only a missing slash is forgiven —
/// so these two must be navigated exactly like this.
const pendingRoute = '/pending';

/// Outlet content when no screen is picked (decision 215).
const welcomeRoute = '/welcome';

void navigateToInterface(MenuInterface screen) {
  Modular.to.navigate(interfaceRoutes[screen.i18nKey] ?? pendingRoute);
}

/// The reverse lookup the shell needs after a refresh (decision 215): the
/// i18nKey whose route is a prefix of [path], so the columns highlight the
/// screen the URL already shows. Longest match wins (`/legal/rules/`
/// before any shorter `/legal...`). Null for `/`, `/welcome/`, `/pending/`
/// and unknown paths.
String? interfaceKeyForPath(String path) {
  final normalized = path.endsWith('/') ? path : '$path/';
  String? bestKey;
  var bestLength = 0;
  for (final entry in interfaceRoutes.entries) {
    if (normalized.startsWith(entry.value) && entry.value.length > bestLength) {
      bestKey = entry.key;
      bestLength = entry.value.length;
    }
  }
  return bestKey;
}
