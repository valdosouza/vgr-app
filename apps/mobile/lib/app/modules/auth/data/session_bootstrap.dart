import 'package:core/core.dart';

import '../domain/usecase/restore_session_usecase.dart';
import 'auth_repository_impl.dart';

/// Silently restores the app-plane session at boot from the persisted
/// refresh token (decision 122) — without this, every relaunch would force
/// a fresh login despite the 90-day refresh window existing. A missing or
/// dead token is swallowed: the app just starts anonymous, the same
/// outcome as any other expired-session case the API already answers with
/// a 401 for.
Future<void> restoreAppSession({
  required ApiClient apiClient,
  required LocalPrefs localPrefs,
  required IdentityBloc identityBloc,
}) async {
  final refreshToken = await localPrefs.getAppRefreshToken();
  if (refreshToken == null) return;

  final restore = RestoreSessionUsecase(AuthRepositoryImpl(apiClient));
  final result = await restore(refreshToken);
  await result.fold(
    (_) => localPrefs.clearAppSession(),
    (session) async {
      await localPrefs.setAppRefreshToken(session.refreshToken);
      identityBloc.add(ProviderLoginCompleted(
        role: Role.reporter,
        anonymityMode: AnonymityMode.identifiedNoReward,
        token: session.accessToken,
      ));
    },
  );
}
