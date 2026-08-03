import 'package:equatable/equatable.dart';

/// One operable screen on the menu (ported from setes-app's MenuInterface).
/// The tree arrives from GET /api/core/menus already filtered by the
/// session user's VIEW grants — the app renders it as-is (decision 71).
class MenuInterface extends Equatable {
  const MenuInterface({
    required this.id,
    required this.description,
    required this.i18nKey,
    this.privileges = const [],
  });

  final int id;
  final String description;

  /// Stable key: same value as tb_interface.i18n_key, shared with the API
  /// guard and the app's route map.
  final String i18nKey;

  /// Privileges the user holds on this screen — feeds [can] (the hook that
  /// was dead in setes, wired in VGR).
  final List<String> privileges;

  bool can(String privilege) => privileges.contains(privilege);

  factory MenuInterface.fromJson(Map<String, dynamic> json) => MenuInterface(
        id: json['id'] as int,
        description: json['description'] as String,
        i18nKey: json['i18nKey'] as String,
        privileges:
            (json['privileges'] as List<dynamic>? ?? const []).cast<String>(),
      );

  @override
  List<Object?> get props => [id, description, i18nKey, privileges];
}

/// A menu grouping: an Admin-managed module (id != null) or a pseudo-module
/// derived from group_default (id == null).
class MenuModule extends Equatable {
  const MenuModule({
    required this.id,
    required this.description,
    this.i18nKey,
    this.imageIcon,
    this.interfaces = const [],
  });

  final int? id;
  final String description;
  final String? i18nKey;
  final String? imageIcon;
  final List<MenuInterface> interfaces;

  factory MenuModule.fromJson(Map<String, dynamic> json) => MenuModule(
        id: json['id'] as int?,
        description: json['description'] as String,
        i18nKey: json['i18nKey'] as String?,
        imageIcon: json['imageIcon'] as String?,
        interfaces: (json['interfaces'] as List<dynamic>? ?? const [])
            .map((i) => MenuInterface.fromJson(i as Map<String, dynamic>))
            .toList(),
      );

  @override
  List<Object?> get props => [id, description, i18nKey, imageIcon, interfaces];
}
