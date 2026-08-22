/// Port for native social sign-in SDKs (decision 143 — no provider SDK
/// touches the domain/presentation layers; same pattern as
/// `report/domain/gateway/photo_gateway.dart`). Returns the raw ID token
/// the API verifies server-side (`shared/auth/social-verifier.ts`) — this
/// port never verifies anything itself, it only collects the token.
abstract class SocialSignInGateway {
  /// Null return means the user cancelled the native flow — not a failure,
  /// same contract as `PhotoGateway.pickFromCamera`.
  Future<String?> signInWithGoogle();
}
