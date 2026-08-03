import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/category_form_schema_entity.dart';
import '../domain/entity/field_definition_entity.dart';
import '../domain/repository/category_form_repository.dart';

class CategoryFormRepositoryImpl implements CategoryFormRepository {
  CategoryFormRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, List<CategoryFormSchemaEntity>>> list() async {
    try {
      final json = await _apiClient.get('/api/category-forms');
      final rows = json['data'] as List<dynamic>;
      return Right(rows.map(_fromJson).toList());
    } on Failure catch (f) {
      return Left(f);
    }
  }

  @override
  Future<Either<Failure, Unit>> upsert(CategoryFormSchemaEntity schema) async {
    try {
      await _apiClient.put(
        '/api/category-forms/${schema.category}',
        {'fields': schema.fields.map((f) => f.toJson()).toList()},
      );
      return const Right(unit);
    } on Failure catch (f) {
      return Left(f);
    }
  }

  CategoryFormSchemaEntity _fromJson(dynamic row) {
    final fields = (row['fields'] as List<dynamic>)
        .map((f) => FieldDefinitionEntity(
              name: f['name'] as String,
              type: FieldTypeJson.fromJson(f['type'] as String),
              required: f['required'] as bool,
            ))
        .toList();
    return CategoryFormSchemaEntity(category: row['category'] as String, fields: fields);
  }
}
