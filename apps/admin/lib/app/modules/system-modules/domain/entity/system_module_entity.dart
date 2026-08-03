import 'package:equatable/equatable.dart';

/// Menu module (tb_module — decision 71): Admin-managed grouping of screens.
/// The CRUD that setes never implemented. `interfaceIds` order = menu order.
class SystemModuleEntity extends Equatable {
  const SystemModuleEntity({
    required this.id,
    required this.description,
    this.i18nKey,
    this.imageIcon,
    this.position = 0,
    this.interfaceIds = const [],
  });

  final int id;
  final String description;
  final String? i18nKey;
  final String? imageIcon;
  final int position;
  final List<int> interfaceIds;

  factory SystemModuleEntity.fromJson(Map<String, dynamic> json) => SystemModuleEntity(
        id: json['id'] as int,
        description: json['description'] as String,
        i18nKey: json['i18nKey'] as String?,
        imageIcon: json['imageIcon'] as String?,
        position: json['position'] as int? ?? 0,
        interfaceIds: (json['interfaceIds'] as List<dynamic>? ?? const []).cast<int>(),
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'i18nKey': i18nKey,
        'imageIcon': imageIcon,
        'position': position,
        'interfaceIds': interfaceIds,
      };

  @override
  List<Object?> get props => [id, description, i18nKey, imageIcon, position, interfaceIds];
}

/// Screen option for the module's link list (own lookup — a module never
/// imports another module).
class InterfaceOption extends Equatable {
  const InterfaceOption({required this.id, required this.description, required this.i18nKey});

  final int id;
  final String description;
  final String i18nKey;

  factory InterfaceOption.fromJson(Map<String, dynamic> json) => InterfaceOption(
        id: json['id'] as int,
        description: json['description'] as String,
        i18nKey: json['i18nKey'] as String,
      );

  @override
  List<Object?> get props => [id, description, i18nKey];
}
