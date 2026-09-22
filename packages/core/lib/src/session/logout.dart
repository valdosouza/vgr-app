import 'package:flutter_modular/flutter_modular.dart';

import '../identity/presentation/identity_bloc.dart';
import '../identity/presentation/identity_event.dart';
import '../menu/session_access.dart';
import '../network/api_client.dart';
import '../storage/local_prefs.dart';

/// Ends the panel session (decision 215): every place a session lives is
/// cleared, in this order — persisted token (and the "keep me signed in"
/// choice, so a refresh cannot resurrect it), in-memory token, the UX
/// privilege cache, the identity — then the router goes to the login
/// page. The API side needs nothing: the JWT is stateless (decision 73).
Future<void> logoutAdminSession({String loginRoute = '/login'}) async {
  final prefs = Modular.get<LocalPrefs>();
  await prefs.clearSession();
  await prefs.setKeepConnected(false);
  Modular.get<ApiClient>().setToken(null);
  SessionAccess.instance.clear();
  Modular.get<IdentityBloc>().add(const SessionCleared());
  Modular.to.navigate(loginRoute);
}
