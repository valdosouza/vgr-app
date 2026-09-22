import 'package:equatable/equatable.dart';

/// The signed-in team user as `GET /api/core/me` returns it — what the
/// shell's badge shows (decision 215). Never a password, never a role:
/// what this user may do is decided per privilege (decision 70).
class CurrentUser extends Equatable {
  const CurrentUser({required this.id, required this.name, required this.email, this.locale});

  final int id;
  final String name;
  final String email;
  final String? locale;

  /// The badge label: the name, or the e-mail while the name is blank
  /// (the seed bootstrap leaves it empty).
  String get displayName => name.trim().isEmpty ? email : name;

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        locale: json['locale'] as String?,
      );

  @override
  List<Object?> get props => [id, name, email, locale];
}
