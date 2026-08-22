import 'package:google_sign_in/google_sign_in.dart';

import '../domain/gateway/social_sign_in_gateway.dart';

/// google_sign_in-backed adapter (decision 152). `serverClientId` is the
/// Web-type OAuth client id from Google Cloud Console — it is what makes
/// the SDK issue an ID token whose `aud` the API can verify (see
/// `GOOGLE_OAUTH_CLIENT_ID` in the API's `.env`).
class GoogleSignInGatewayImpl implements SocialSignInGateway {
  GoogleSignInGatewayImpl({required String serverClientId})
      : _serverClientId = serverClientId;

  final String _serverClientId;
  Future<void>? _initialization;

  /// `GoogleSignIn.instance.initialize` must run exactly once and complete
  /// before any other call — shared across concurrent sign-in attempts the
  /// same way `ApiClient._ensureFreshToken` shares one in-flight renewal.
  Future<void> _ensureInitialized() {
    return _initialization ??=
        GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
  }

  @override
  Future<String?> signInWithGoogle() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
