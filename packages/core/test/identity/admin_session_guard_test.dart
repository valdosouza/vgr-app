import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core/src/identity/admin_session_guard.dart';
import 'package:core/src/identity/domain/anonymity_mode.dart';
import 'package:core/src/identity/domain/role.dart';
import 'package:core/src/identity/presentation/identity_bloc.dart';
import 'package:core/src/identity/presentation/identity_event.dart';

void main() {
  final route = ChildRoute('/', child: (_, __) => Container());

  test('non-admin session is redirected away from an admin route', () async {
    final bloc = IdentityBloc();
    final guard = AdminSessionGuard(bloc);

    final allowed = await guard.canActivate('/admin', route);

    expect(allowed, isFalse);
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
