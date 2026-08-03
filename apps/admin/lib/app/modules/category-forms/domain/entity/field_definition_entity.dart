import 'package:equatable/equatable.dart';

enum FieldType { string, number, boolean, date }

extension FieldTypeJson on FieldType {
  static FieldType fromJson(String value) => FieldType.values.byName(value);
  String toJson() => name;
}

class FieldDefinitionEntity extends Equatable {
  const FieldDefinitionEntity({
    required this.name,
    required this.type,
    required this.required,
  });

  final String name;
  final FieldType type;
  final bool required;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.toJson(),
        'required': required,
      };

  @override
  List<Object?> get props => [name, type, required];
}
