import 'package:equatable/equatable.dart';

/// Privilege catalog row (tb_privilege — decision 71). `description` is the
/// stable UPPER_SNAKE_CASE identifier; the app translates it via
/// `menu.privileges.[description]` with the identifier as fallback.
class PrivilegeEntity extends Equatable {
  const PrivilegeEntity({required this.id, required this.description});

  final int id;
  final String description;

  factory PrivilegeEntity.fromJson(Map<String, dynamic> json) =>
      PrivilegeEntity(id: json['id'] as int, description: json['description'] as String);

  @override
  List<Object?> get props => [id, description];
}
