import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_form_schema_entity.dart';
import '../entity/report_input.dart';

abstract class ReportRepository {
  /// Submits the report. Transport failure (device offline, API down)
  /// falls back to the offline queue and answers `queued` (decisions
  /// 28/123); an API rejection (validation, legal gate) is a Left and is
  /// NEVER enqueued — a retry would fail identically.
  Future<Either<Failure, SubmitOutcome>> submit(ReportInput input);

  /// The whole category-form catalog in one read, cached locally so the
  /// dynamic form renders offline (decision 47; API `category-forms`).
  Future<Either<Failure, List<CategoryFormSchemaEntity>>> getCategoryForms();
}
