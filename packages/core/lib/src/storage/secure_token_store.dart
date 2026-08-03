import 'local_prefs.dart';

/// Where the session token lives on the client (decision 117).
///
/// The admin panel is web: localStorage via [LocalPrefs] stays, and the
/// 15-minute TTL of decision 112 is what shrinks the XSS window — moving
/// to an httpOnly cookie would rewrite the auth contract on both clients
/// for a vector already reduced to minutes.
///
/// The mobile app must NOT use that: it swaps in a Keychain/Keystore
/// implementation of this interface (flutter_secure_storage) when the
/// first mobile feature lands. This abstraction exists so that swap is a
/// binding change, not a refactor of every caller.
abstract class SecureTokenStore {
  Future<String?> readToken();
  Future<void> writeToken(String? token);
  Future<void> clear();
}

/// Web/admin implementation: delegates to the existing LocalPrefs.
class PrefsTokenStore implements SecureTokenStore {
  PrefsTokenStore(this._prefs);

  final LocalPrefs _prefs;

  @override
  Future<String?> readToken() => _prefs.getSessionToken();

  @override
  Future<void> writeToken(String? token) => _prefs.setSessionToken(token);

  @override
  Future<void> clear() => _prefs.clearSession();
}
