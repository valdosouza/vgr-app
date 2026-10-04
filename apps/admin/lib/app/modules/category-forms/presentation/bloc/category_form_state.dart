import 'package:core/core.dart';
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

/// The catalog could not be LOADED — translated by code (80/83), with a
/// retry. An action failure never lands here: it is [CategoryFormActionFailed].
class CategoryFormError extends CategoryFormState {
  const CategoryFormError(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// One-shot (decision 221): an edit was refused — the page hands it to the
/// feedback bridge and keeps showing the schemas it had.
class CategoryFormActionFailed extends CategoryFormState {
  const CategoryFormActionFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// One-shot: an edit was saved.
class CategoryFormActionSucceeded extends CategoryFormState {
  const CategoryFormActionSucceeded();
}
