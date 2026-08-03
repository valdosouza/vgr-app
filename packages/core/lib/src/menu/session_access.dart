import 'domain/menu_entity.dart';

/// UX-only privilege lookup, fed by the loaded menu tree (mirrors setes'
/// SessionContext discipline: the API is the authority — decision 72 — this
/// only decides whether buttons render enabled).
///
/// Default-deny: before the menu loads, every [can] answers false.
class SessionAccess {
  SessionAccess._();

  static final SessionAccess instance = SessionAccess._();

  final Map<String, Set<String>> _privileges = {};

  /// Preferred feed (decision 93): the full grant map from
  /// GET /api/core/permissions — includes kind 'R' resources that never
  /// appear on the menu tree.
  void applyPermissions(Map<String, List<String>> permissions) {
    _privileges.clear();
    for (final entry in permissions.entries) {
      _privileges[entry.key] = {...entry.value};
    }
  }

  /// Fallback feed when the permissions call fails: derives what it can
  /// from the menu tree (kind 'T' only — 'R' grants stay unknown and
  /// default-deny, never default-allow).
  void apply(List<MenuModule> tree) {
    _privileges.clear();
    for (final module in tree) {
      for (final screen in module.interfaces) {
        _privileges
            .putIfAbsent(screen.i18nKey, () => <String>{})
            .addAll(screen.privileges);
      }
    }
  }

  bool can(String interfaceKey, String privilege) =>
      _privileges[interfaceKey]?.contains(privilege) ?? false;

  void clear() => _privileges.clear();
}

/// Privilege names — must match tb_privilege.description (migration 019).
abstract final class Privileges {
  static const view = 'VIEW';
  static const insert = 'INSERT';
  static const update = 'UPDATE';
  static const delete = 'DELETE';
  static const print = 'PRINT';
}
