import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/report_repository.dart';

/// Owner-only close (decisions 18/131/179) — no "outcome" field, just the
/// confirmation dialog the page shows BEFORE calling this.
class ResolveReportUsecase {
  const ResolveReportUsecase(this._repository);

  final ReportRepository _repository;

  Future<Either<Failure, void>> call(int reportId) => _repository.resolve(reportId);
}
