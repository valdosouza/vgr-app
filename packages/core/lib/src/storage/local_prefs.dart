import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for the session (decision 73 — ported from setes-app's
/// LocalPrefs). On web, shared_preferences maps to localStorage.
///
/// Keys:
/// - [sessionToken]: the JWT — persisted ONLY when "keep me signed in" is
///   checked; otherwise the token lives in memory (ApiClient) only.
/// - [keepConnected]: remembers the checkbox's last choice.
/// - [rememberedEmail]: "remember my email" stores the email, NEVER the
///   password.
/// - [appRefreshToken]: the APP plane's rotating refresh token (decision
///   122) — unlike the panel's JWT, always persisted (no "keep me signed
///   in" choice exists for the app); the short-lived access token itself
///   never touches disk, only `ApiClient`'s memory.
class LocalPrefs {
  static const sessionToken = 'session_token';
  static const keepConnected = 'keep_connected';
  static const rememberedEmail = 'remembered_email';
  static const appRefreshToken = 'app_refresh_token';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> getSessionToken() async => (await _prefs).getString(sessionToken);

  Future<void> setSessionToken(String? token) async {
    final prefs = await _prefs;
    if (token == null) {
      await prefs.remove(sessionToken);
    } else {
      await prefs.setString(sessionToken, token);
    }
  }

  Future<bool> getKeepConnected() async => (await _prefs).getBool(keepConnected) ?? false;

  Future<void> setKeepConnected(bool value) async =>
      (await _prefs).setBool(keepConnected, value);

  Future<String?> getRememberedEmail() async => (await _prefs).getString(rememberedEmail);

  Future<void> setRememberedEmail(String? email) async {
    final prefs = await _prefs;
    if (email == null || email.isEmpty) {
      await prefs.remove(rememberedEmail);
    } else {
      await prefs.setString(rememberedEmail, email);
    }
  }

  Future<void> clearSession() => setSessionToken(null);

  Future<String?> getAppRefreshToken() async => (await _prefs).getString(appRefreshToken);

  Future<void> setAppRefreshToken(String? token) async {
    final prefs = await _prefs;
    if (token == null) {
      await prefs.remove(appRefreshToken);
    } else {
      await prefs.setString(appRefreshToken, token);
    }
  }

  Future<void> clearAppSession() => setAppRefreshToken(null);
}
