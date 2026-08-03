import 'package:equatable/equatable.dart';

/// Screen catalog row (tb_interface — decision 71). `i18nKey` is the stable
/// key shared by the API guard, the menu tree and the app's route map.
class InterfaceEntity extends Equatable {
  const InterfaceEntity({
    required this.id,
    required this.description,
    required this.i18nKey,
    required this.groupDefault,
    this.kind = 'T',
    this.position = 0,
    this.privilegeIds = const [],
  });

  final int id;
  final String description;
  final String i18nKey;
  final String groupDefault;

  /// 'T' screen goes to menu / 'R' reserved (round-1 pending assumption:
  /// MVP only uses 'T' — the field is carried, not edited).
  final String kind;
  final int position;
  final List<int> privilegeIds;

  factory InterfaceEntity.fromJson(Map<String, dynamic> json) => InterfaceEntity(
        id: json['id'] as int,
        description: json['description'] as String,
        i18nKey: json['i18nKey'] as String,
        groupDefault: json['groupDefault'] as String,
        kind: json['kind'] as String? ?? 'T',
        position: json['position'] as int? ?? 0,
        privilegeIds: (json['privilegeIds'] as List<dynamic>? ?? const []).cast<int>(),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'i18nKey': i18nKey,
        'groupDefault': groupDefault,
        'kind': kind,
        'position': position,
        'privilegeIds': privilegeIds,
      };

  @override
  List<Object?> get props => [id, description, i18nKey, groupDefault, kind, position, privilegeIds];
}

/// Privilege option for the screen's checkbox list. Duplicated from the
/// privileges module ON PURPOSE — a module never imports another module
/// (same documented duplication exists in setes).
class PrivilegeOption extends Equatable {
  const PrivilegeOption({required this.id, required this.description});

  final int id;
  final String description;

  factory PrivilegeOption.fromJson(Map<String, dynamic> json) =>
      PrivilegeOption(id: json['id'] as int, description: json['description'] as String);

  @override
  List<Object?> get props => [id, description];
}
