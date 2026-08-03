import 'package:equatable/equatable.dart';

/// Team user (tb_user — decisions 70/74/75): created directly by an Admin;
/// what they can do is decided by privilege grants, never by a role.
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.active = 'S',
    this.locale,
    this.lastLoginAt,
  });

  final int id;
  final String name;
  final String email;
  final String active;
  final String? locale;
  final String? lastLoginAt;

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        active: json['active'] as String? ?? 'S',
        locale: json['locale'] as String?,
        lastLoginAt: json['lastLoginAt'] as String?,
      );

  @override
  List<Object?> get props => [id, name, email, active, locale, lastLoginAt];
}

/// One privilege cell of the user's matrix.
class UserPrivilegeCell extends Equatable {
  const UserPrivilegeCell({
    required this.privilegeId,
    required this.description,
    required this.granted,
  });

  final int privilegeId;
  final String description;
  final bool granted;

  factory UserPrivilegeCell.fromJson(Map<String, dynamic> json) => UserPrivilegeCell(
        privilegeId: json['privilegeId'] as int,
        description: json['description'] as String,
        granted: json['granted'] as bool,
      );

  @override
  List<Object?> get props => [privilegeId, description, granted];
}

/// One screen row of the matrix (GET /api/users/:id/privileges).
class UserInterfaceGrants extends Equatable {
  const UserInterfaceGrants({
    required this.interfaceId,
    required this.interfaceKey,
    required this.description,
    required this.groupDefault,
    required this.privileges,
  });

  final int interfaceId;
  final String interfaceKey;
  final String description;
  final String groupDefault;
  final List<UserPrivilegeCell> privileges;

  factory UserInterfaceGrants.fromJson(Map<String, dynamic> json) => UserInterfaceGrants(
        interfaceId: json['interfaceId'] as int,
        interfaceKey: json['interfaceKey'] as String,
        description: json['description'] as String,
        groupDefault: json['groupDefault'] as String,
        privileges: (json['privileges'] as List<dynamic>? ?? const [])
            .map((p) => UserPrivilegeCell.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [interfaceId, interfaceKey, description, groupDefault, privileges];
}
