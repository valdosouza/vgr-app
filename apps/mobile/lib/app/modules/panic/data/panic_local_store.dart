import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One device's currently-unresolved triggered alert — `alertId` is what
/// `resolve` needs, `clientKey` is the anonymous triggerer's bearer secret
/// (mirrors `MyReportsStore`'s `clientKeyOf`, decision 134's same idiom
/// applied to `x-client-key` ownership) sent when the trigger was
/// anonymous. Absent (null `clientKey`) for an identified trigger, whose
/// session already carries ownership.
class ActivePanicAlert {
  const ActivePanicAlert({required this.alertId, this.clientKey});

  final int alertId;
  final String? clientKey;
}

/// Local-only PP2 state (decisions 62/65/191/198) — no server endpoint
/// exists to read "my own triggered alert" or "my own responder-membership
/// status" (a known, accepted PP1 gap, see `app/docs/feature/panic.md`),
/// so this is the ONLY record of either fact. Same shape as
/// `MyReportsStore`: `SharedPreferences`-backed, `_storageKey`, `_load`
/// via `jsonDecode`.
class PanicLocalStore {
  PanicLocalStore({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  static const _storageKey = 'panic_local_v1';

  final SharedPreferences? _injectedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _load() async {
    final raw = (await _prefs).getString(_storageKey);
    return raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _persist(Map<String, dynamic> map) async {
    await (await _prefs).setString(_storageKey, jsonEncode(map));
  }

  /// Only one active alert per device at a time by construction (mirrors
  /// the server's own cooldown, 198) — a new save REPLACES any previous
  /// record rather than accumulating a map.
  Future<void> saveActiveAlert({required int alertId, String? clientKey}) async {
    final map = await _load();
    map['activeAlert'] = {'alertId': alertId, 'clientKey': clientKey};
    await _persist(map);
  }

  Future<ActivePanicAlert?> activeAlert() async {
    final raw = (await _load())['activeAlert'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return ActivePanicAlert(alertId: raw['alertId'] as int, clientKey: raw['clientKey'] as String?);
  }

  /// Called after a successful resolve — back to offering the trigger
  /// button.
  Future<void> clearActiveAlert() async {
    final map = await _load();
    map.remove('activeAlert');
    await _persist(map);
  }

  /// Pure UX nicety: the API has no uniqueness constraint stopping a
  /// second `POST /app-panic/responder-pool` (see `panic.md`'s "Plane
  /// fix" section), so this flag is the only guard against the account
  /// tile inviting an accidental duplicate.
  Future<void> markResponderRequestSent() async {
    final map = await _load();
    map['responderRequestSent'] = true;
    await _persist(map);
  }

  Future<bool> responderRequestSent() async =>
      (await _load())['responderRequestSent'] as bool? ?? false;
}
