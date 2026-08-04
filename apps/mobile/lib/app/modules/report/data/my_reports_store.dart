import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local map reportId → clientKey. The clientKey is the anonymous
/// reporter's bearer secret (decision 134): presenting it in the
/// `x-client-key` header is what makes this device the report's OWNER on
/// reads and edits. Saved on every successful submit (inline or from the
/// offline queue), never sent anywhere except that header.
class MyReportsStore {
  MyReportsStore({SharedPreferences? prefs}) : _injectedPrefs = prefs;

  static const _storageKey = 'my_reports_v1';

  final SharedPreferences? _injectedPrefs;

  Future<SharedPreferences> get _prefs async =>
      _injectedPrefs ?? await SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _load() async {
    final raw = (await _prefs).getString(_storageKey);
    return raw == null ? {} : (jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(int reportId, String clientKey) async {
    final map = await _load();
    map['$reportId'] = clientKey;
    await (await _prefs).setString(_storageKey, jsonEncode(map));
  }

  Future<String?> clientKeyOf(int reportId) async => (await _load())['$reportId'] as String?;
}
