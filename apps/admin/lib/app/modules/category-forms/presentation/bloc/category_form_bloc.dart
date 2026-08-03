import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/category_form_schema_entity.dart';
import '../../domain/repository/category_form_repository.dart';
import 'category_form_event.dart';
import 'category_form_state.dart';

class CategoryFormBloc extends Bloc<CategoryFormEvent, CategoryFormState> {
  CategoryFormBloc(this._repository) : super(const CategoryFormLoading()) {
    on<FetchRequested>(_onFetchRequested);
    on<FieldAdded>(_onFieldAdded);
  }

  final CategoryFormRepository _repository;

  Future<void> _onFetchRequested(
    FetchRequested event,
    Emitter<CategoryFormState> emit,
  ) async {
    emit(const CategoryFormLoading());
    final result = await _repository.list();
    result.fold(
      (failure) => emit(CategoryFormError(failure.message)),
      (schemas) => emit(CategoryFormLoaded(schemas)),
    );
  }

  /// Persists the field via upsert() and updates local state directly —
  /// same "no full page reload" guarantee as RiskConfigBloc.
  Future<void> _onFieldAdded(
    FieldAdded event,
    Emitter<CategoryFormState> emit,
  ) async {
    final current = state;
    if (current is! CategoryFormLoaded) return;

    final target = current.schemas.firstWhere((s) => s.category == event.category);
    final updatedSchema = CategoryFormSchemaEntity(
      category: target.category,
      fields: [...target.fields, event.field],
    );

    final result = await _repository.upsert(updatedSchema);
    result.fold(
      (failure) => emit(CategoryFormError(failure.message)),
      (_) => emit(CategoryFormLoaded([
        for (final schema in current.schemas)
          if (schema.category == event.category) updatedSchema else schema,
      ])),
    );
  }
}
