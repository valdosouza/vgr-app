import 'package:core/core.dart';

/// Grants every privilege on every admin screen AND kind-'R' resource
/// (decision 93) — page tests exercise the actions themselves;
/// privilege-denied rendering has its own tests.
void grantAllPrivileges() => SessionAccess.instance.applyPermissions(_allGrants);

/// Everything above PLUS `chat_evidence` VIEW (C3, decision 175). The chat
/// grant has NO bootstrap in the API and is deliberately NOT part of
/// [grantAllPrivileges]: only the tests that exercise the audited chat read
/// ask for it, so every other page test proves the section stays absent.
void grantChatEvidence() => SessionAccess.instance.applyPermissions({
      ..._allGrants,
      'chat_evidence': const [Privileges.view],
    });

const _all = [
  Privileges.view,
  Privileges.insert,
  Privileges.update,
  Privileges.delete,
];

const Map<String, List<String>> _allGrants = {
    'case_freeze': [Privileges.view, Privileges.update],
    'reward_mediation': [Privileges.view, Privileges.update],
    // Report search/detail (B1, decision 165); UPDATE reserved for B2/B3.
    'reports': [Privileges.view, Privileges.update],
    // Aggregated statistics, own interface, VIEW only (B4, decision 165).
    'report_stats': [Privileges.view],
    // Admin audit trail, own interface, VIEW only (B5, decision 165).
    'admin_audit': [Privileges.view],
    'legal_jurisdictions': _all,
    'legal_capabilities': _all,
    'legal_rules': _all,
    'risk_config': _all,
    'category_forms': _all,
    'panic_responders': _all,
    'dual_control_access': _all,
    'monetization_config': _all,
    'users': _all,
    'system_modules': _all,
    'interfaces': _all,
    'privileges': _all,
    // kind 'R' resources — never on the menu, granted like any interface.
    'user_privileges': [Privileges.view, Privileges.update],
    'dual_control_approval': [Privileges.update],
    // No bootstrap in the API (159) — granted here so page tests exercise the reveal.
    'report_exact_position': [Privileges.view],
};

void revokeAllPrivileges() => SessionAccess.instance.clear();
