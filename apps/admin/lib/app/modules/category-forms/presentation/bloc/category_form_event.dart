import 'package:equatable/equatable.dart';

import '../../domain/entity/field_definition_entity.dart';

sealed class CategoryFormEvent extends Equatable {
  const CategoryFormEvent();

  @override
  List<Object?> get props => [];
}

class FetchRequested extends CategoryFormEvent {
  const FetchRequested();
}

/// Appends a new field to a Category's schema and persists the result —
/// the "add" half of "add/remove/reorder" (task 04); remove/reorder
/// follow the same shape when the UI grows a control for them.
class FieldAdded extends CategoryFormEvent {
  const FieldAdded({required this.category, required this.field});

  final String category;
  final FieldDefinitionEntity field;

  @override
  List<Object?> get props => [category, field];
}
