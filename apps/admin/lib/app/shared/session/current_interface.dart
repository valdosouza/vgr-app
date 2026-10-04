import 'package:core/core.dart';

/// The screen being drawn and what this session may do on it — setes'
/// `CurrentInterface`, which the register factory reads to decide the
/// "new" button (INSERT), save (INSERT/UPDATE) and delete (DELETE).
///
/// Unlike setes, it is not a global the navigation writes: each module
/// names its own `tb_interface.i18n_key`. The shell's `MenuBloc` already
/// owns "which screen is selected", and a global would go stale on a
/// refresh or a deep link that never passed through the menu. The answer
/// still comes from [SessionAccess] — UX only; the API decides (72).
class CurrentInterface {
  const CurrentInterface(this.key);

  /// `tb_interface.i18n_key` — the same key as `interfaceRoutes`.
  final String key;

  bool can(String privilege) => SessionAccess.instance.can(key, privilege);

  bool get canView => can(Privileges.view);
  bool get canInsert => can(Privileges.insert);
  bool get canUpdate => can(Privileges.update);
  bool get canDelete => can(Privileges.delete);
}
