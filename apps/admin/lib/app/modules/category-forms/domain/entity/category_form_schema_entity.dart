import 'package:equatable/equatable.dart';

import 'field_definition_entity.dart';

class CategoryFormSchemaEntity extends Equatable {
  const CategoryFormSchemaEntity({required this.category, required this.fields});

  final String category;
  final List<FieldDefinitionEntity> fields;

  @override
  List<Object?> get props => [category, fields];
}
