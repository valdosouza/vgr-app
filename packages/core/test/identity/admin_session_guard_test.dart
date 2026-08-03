import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/identity/admin_session_guard.dart';
import 'package:core/src/identity/domain/anonymity_mode.dart';
import 'package:core/src/identity/domain/role.dart';
import 'package:core/src/identity/presentation/identity_bloc.dart';
import 'package:core/src/identity/presentation/identity_event.dart';
import 'package:core/src/network/api_client.dart';
import 'package:core/src/storage/local_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The guard falls back to the stored session when the bloc has no admin
/// yet (decision 73), so it resolves LocalPrefs/ApiClient from Modular —
/// the test needs a module providing both.
class _GuardTestModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.singleton((i) => LocalPrefs()),
        Bind.singleton((i) => ApiClient(baseUrl: '')),
      ];
}

void main() {
  final route = ChildRoute('/', child: (_, __) => Container());

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    Modular.init(_GuardTestModule());
  });

  tearDown(Modular.destroy);

  test('non-admin session with no stored token is redirected away from an admin route', () async {
    final bloc = IdentityBloc();
    final guard = AdminSessionGuard(bloc);

    final allowed = await guard.canActivate('/admin', route);

    expect(allowed, isFalse);
    bloc.close();
  });

  test('an expired stored token is cleared instead of restoring the session', () async {
    SharedPreferences.setMockInitialValues({
      LocalPrefs.sessionToken: 'header.${base64Url.encode(utf8.encode(jsonEncode({
            'userId': 1,
            'exp': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000,
          })))}.signature',
    });
    final bloc = IdentityBloc();

    final allowed = await AdminSessionGuard(bloc).canActivate('/admin', route);

    expect(allowed, isFalse);
    expect(await LocalPrefs().getSessionToken(), isNull);
    bloc.close();
  });

  test('admin session is allowed to activate an admin route', () async {
    final bloc = IdentityBloc();
    bloc.add(const ProviderLoginCompleted(
      role: Role.admin,
      anonymityMode: AnonymityMode.identifiedNoReward,
    ));
    await Future<void>.delayed(Duration.zero);

    final guard = AdminSessionGuard(bloc);
    final allowed = await guard.canActivate('/admin', route);

    expect(allowed, isTrue);
    bloc.close();
  });
}
