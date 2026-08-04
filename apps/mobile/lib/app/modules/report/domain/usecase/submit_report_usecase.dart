import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/report_input.dart';
import '../repository/report_repository.dart';

/// Coordinates submission (spec task 05). The repository already decides
/// online-vs-queued; this usecase is the seam where future cross-cutting
/// rules (fricção da decisão 123) attach without touching the bloc.
class SubmitReportUsecase {
  const SubmitReportUsecase(this._repository);

  final ReportRepository _repository;

  Future<Either<Failure, SubmitOutcome>> call(ReportInput input) =>
      _repository.submit(input);
}
