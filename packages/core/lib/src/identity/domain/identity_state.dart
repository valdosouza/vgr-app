import 'package:equatable/equatable.dart';

import 'anonymity_mode.dart';
import 'role.dart';

class IdentityState extends Equatable {
  const IdentityState({
    this.role = Role.anonymous,
    this.anonymityMode = AnonymityMode.anonymous,
    this.token,
  });

  final Role role;
  final AnonymityMode anonymityMode;

  /// The JWT issued at login, if any — null for anonymous sessions.
  final String? token;

  @override
  List<Object?> get props => [role, anonymityMode, token];
}
