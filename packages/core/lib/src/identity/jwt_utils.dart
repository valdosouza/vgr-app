import 'dart:convert';

/// Decodes the JWT payload WITHOUT validating the signature — client-side
/// this is only used to know whether a stored session is worth restoring
/// (the API remains the authority and rejects bad tokens with 401).
/// Ported from setes-app's jwt_utils.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}

/// True when the token is malformed or its `exp` has passed (30s slack so a
/// token about to expire is not restored just to fail on the first call).
bool isJwtExpired(String token) => _expiresWithin(token, const Duration(seconds: 30));

/// True when the token is close enough to expiry that it should be renewed
/// before the next call (decision 112: sessions are 15 minutes, so the app
/// renews silently instead of asking the user to sign in again).
bool shouldRenewJwt(String token, {Duration window = const Duration(minutes: 2)}) =>
    _expiresWithin(token, window);

bool _expiresWithin(String token, Duration slack) {
  final payload = decodeJwtPayload(token);
  final exp = payload?['exp'];
  if (exp is! num) return true;
  final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
  return expiry.isBefore(DateTime.now().add(slack));
}
