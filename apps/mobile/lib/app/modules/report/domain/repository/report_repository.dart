import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/category_form_schema_entity.dart';
import '../entity/feed_item_entity.dart';
import '../entity/report_input.dart';
import '../entity/report_view_entity.dart';
import '../gateway/location_gateway.dart';

abstract class ReportRepository {
  /// Submits the report. Transport failure (device offline, API down)
  /// falls back to the offline queue and answers `queued` (decisions
  /// 28/123); an API rejection (validation, legal gate) is a Left and is
  /// NEVER enqueued — a retry would fail identically.
  Future<Either<Failure, SubmitOutcome>> submit(ReportInput input);

  /// The whole category-form catalog in one read, cached locally so the
  /// dynamic form renders offline (decision 47; API `category-forms`).
  Future<Either<Failure, List<CategoryFormSchemaEntity>>> getCategoryForms();

  /// Anonymous nearby feed (`GET /app-feed`, decisions 2/21/135). The
  /// viewer position is used transiently by the API and never stored.
  Future<Either<Failure, FeedPageEntity>> listNearby(
    GeoPoint position,
    int page,
    FeedOrder order,
  );

  /// One report as THIS viewer may see it (`GET /app-reports/:id`,
  /// decision 50). Sends the stored clientKey as `x-client-key` when this
  /// device submitted the report (decision 134 — bearer ownership).
  Future<Either<Failure, ReportViewEntity>> getReport(int reportId);
}
