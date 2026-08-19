import 'package:core/core.dart';

/// Grants every privilege on every admin screen AND kind-'R' resource
/// (decision 93) — page tests exercise the actions themselves;
/// privilege-denied rendering has its own tests.
void grantAllPrivileges() {
  const all = [
    Privileges.view,
    Privileges.insert,
    Privileges.update,
    Privileges.delete,
  ];
  SessionAccess.instance.applyPermissions(const {
    'case_freeze': [Privileges.view, Privileges.update],
    'legal_jurisdictions': all,
    'legal_capabilities': all,
    'legal_rules': all,
    'risk_config': all,
    'category_forms': all,
    'panic_responders': all,
    'dual_control_access': all,
    'monetization_config': all,
    'users': all,
    'system_modules': all,
    'interfaces': all,
    'privileges': all,
    // kind 'R' resources — never on the menu, granted like any interface.
    'user_privileges': [Privileges.view, Privileges.update],
    'dual_control_approval': [Privileges.update],
  });
}

void revokeAllPrivileges() => SessionAccess.instance.clear();
