import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_form_schema_entity.dart';

abstract class CategoryFormRepository {
  Future<Either<Failure, List<CategoryFormSchemaEntity>>> list();
  Future<Either<Failure, Unit>> upsert(CategoryFormSchemaEntity schema);
}
