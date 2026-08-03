import 'package:equatable/equatable.dart';

import '../../domain/entity/category_form_schema_entity.dart';

sealed class CategoryFormState extends Equatable {
  const CategoryFormState();

  @override
  List<Object?> get props => [];
}

class CategoryFormLoading extends CategoryFormState {
  const CategoryFormLoading();
}

class CategoryFormLoaded extends CategoryFormState {
  const CategoryFormLoaded(this.schemas);

  final List<CategoryFormSchemaEntity> schemas;

  @override
  List<Object?> get props => [schemas];
}

class CategoryFormError extends CategoryFormState {
  const CategoryFormError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
