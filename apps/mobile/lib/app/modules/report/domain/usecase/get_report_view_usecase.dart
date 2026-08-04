import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/report_view_entity.dart';
import '../repository/report_repository.dart';

/// Server-resolved visibility view of one report (spec task 22,
/// decision 50).
class GetReportViewUsecase {
  const GetReportViewUsecase(this._repository);

  final ReportRepository _repository;

  Future<Either<Failure, ReportViewEntity>> call(int reportId) =>
      _repository.getReport(reportId);
}
