import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/app_session_entity.dart';
import '../gateway/social_sign_in_gateway.dart';
import '../repository/auth_repository.dart';

/// Google login (decision 152): collects an ID token from the native SDK
/// via the port, then hands it to the API for verification — this
/// usecase never inspects the token itself.
class LoginWithGoogleUsecase {
  const LoginWithGoogleUsecase(this._gateway, this._repository);

  final SocialSignInGateway _gateway;
  final AuthRepository _repository;

  /// Null return means the user cancelled the native flow — not a failure
  /// (same contract as `SocialSignInGateway.signInWithGoogle`).
  Future<Either<Failure, AppSessionEntity>?> call() async {
    final idToken = await _gateway.signInWithGoogle();
    if (idToken == null) return null;
    return _repository.loginWithProvider(provider: 'google', idToken: idToken);
  }
}
