import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';

import 'domain/role.dart';
import 'presentation/identity_bloc.dart';

/// Ensures every admin route requires Role=admin from [IdentityBloc]
/// before rendering; redirects to the login page otherwise (decision 56,
/// decision 67).
class AdminSessionGuard extends RouteGuard {
  AdminSessionGuard(this.identityBloc) : super(redirectTo: '/login');

  final IdentityBloc identityBloc;

  @override
  FutureOr<bool> canActivate(String path, ParallelRoute route) {
    return identityBloc.state.role == Role.admin;
  }
}
