import 'dart:convert';

import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only "did THIS device already sight this report, and with which
/// direction" record (DS2 — decisions 200-207). There is NO server
/// endpoint to read "did I already sight this report" or "what did I
/// pick" — the API contract's own documented gap, the same class as the
/// panic front's local-only records (`panic_local_store.dart`) — so this
/// is the ONLY record of either fact. Mirrors `PanicLocalStore`'s exact
/// shape: `SharedPreferences`-backed, `_storageKey`, `_load`/`_persist`
/// via `jsonDecode`/`jsonEncode`.
///
/// A SOFT, UX-level spam mitigation, NOT a real security boundary: the
/// schema has no unique constraint on (account/device, report) — only on
/// the sighting's own `clientKey` — so a reinstall or a second device
/// bypasses this entirely. It exists only so THIS device's picker stops
/// re-offering itself after a first successful tap, and never re-invites
/// a second, different-direction sighting from the same device — same
/// posture as `PanicLocalStore.responderRequestSent`.
class DirectionSightingLocalStore {
  DirectionSightingLocalStore({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  static const _storageKey = 'direction_sighting_local_v1';

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

  /// Records this device's own sighting for [reportId]. Called as soon as
  /// the write is known to have happened (online success) OR is durably
  /// promised (enqueued for offline retry) — never only after the queue
  /// eventually flushes, since a revisit before that flush must not
  /// re-offer the picker (see `DirectionSightingRepositoryImpl`).
  Future<void> saveSighting({required int reportId, required Direction direction}) async {
    final map = await _load();
    map['$reportId'] = direction.wire;
    await _persist(map);
  }

  /// Null if this device never logged (or queued) a sighting for
  /// [reportId].
  Future<Direction?> sightingFor(int reportId) async {
    final wire = (await _load())['$reportId'] as String?;
    return wire == null ? null : DirectionJson.fromJson(wire);
  }
}
