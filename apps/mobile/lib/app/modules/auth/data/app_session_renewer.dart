import 'package:core/core.dart';

import '../domain/usecase/restore_session_usecase.dart';
import 'auth_repository_impl.dart';

/// App-plane silent renewal, plugged into `ApiClient.renewToken`.
///
/// The shared client's default exchange is the PANEL's `/api/auth/renew`,
/// which rejects app tokens by design (decision 119 — separate audiences).
/// The app plane renews with its refresh token instead (decision 122):
/// `POST /app-auth/refresh` rotates the pair, so the new refresh token is
/// persisted and the identity gets the fresh access token. A dead refresh
/// token clears the stored session and answers null — the call then
/// proceeds and the API's 401 is handled as "session over", exactly as
/// before this existed.
class AppSessionRenewer {
  AppSessionRenewer({
    required ApiClient apiClient,
    required LocalPrefs localPrefs,
    required IdentityBloc identityBloc,
  })  : _apiClient = apiClient,
        _localPrefs = localPrefs,
        _identityBloc = identityBloc;

  final ApiClient _apiClient;
  final LocalPrefs _localPrefs;
  final IdentityBloc _identityBloc;

  Future<String?> call(String currentJwt) async {
    final refreshToken = await _localPrefs.getAppRefreshToken();
    if (refreshToken == null) return null;

    final restore = RestoreSessionUsecase(AuthRepositoryImpl(_apiClient));
    final result = await restore(refreshToken);
    return result.fold(
      (_) async {
        await _localPrefs.clearAppSession();
        return null;
      },
      (session) async {
        await _localPrefs.setAppRefreshToken(session.refreshToken);
        _identityBloc.add(ProviderLoginCompleted(
          role: Role.reporter,
          anonymityMode: AnonymityMode.identifiedNoReward,
          token: session.accessToken,
        ));
        return session.accessToken;
      },
    );
  }
}
