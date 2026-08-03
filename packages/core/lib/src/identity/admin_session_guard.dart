import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';

import '../network/api_client.dart';
import '../storage/local_prefs.dart';
import 'domain/anonymity_mode.dart';
import 'domain/role.dart';
import 'jwt_utils.dart';
import 'presentation/identity_bloc.dart';
import 'presentation/identity_event.dart';

/// Ensures every admin route has a live session before rendering; redirects
/// to the login page otherwise (decisions 56, 67).
///
/// Since decision 73 it also restores a persisted session: with "keep me
/// signed in" the JWT survives a page refresh in LocalPrefs — the guard
/// rehydrates ApiClient/IdentityBloc from it and drops it when expired.
/// Client-side expiry check only decides whether to restore; the API is the
/// authority (401 on any bad token).
class AdminSessionGuard extends RouteGuard {
  AdminSessionGuard(this.identityBloc) : super(redirectTo: '/login');

  final IdentityBloc identityBloc;

  @override
  FutureOr<bool> canActivate(String path, ParallelRoute route) async {
    if (identityBloc.state.role == Role.admin) return true;

    final prefs = Modular.get<LocalPrefs>();
    final token = await prefs.getSessionToken();
    if (token == null) return false;

    if (isJwtExpired(token)) {
      await prefs.clearSession();
      return false;
    }

    Modular.get<ApiClient>().setToken(token);
    identityBloc.add(ProviderLoginCompleted(
      role: Role.admin,
      anonymityMode: AnonymityMode.anonymous,
      token: token,
    ));
    return true;
  }
}
