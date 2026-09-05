import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/direction_sighting_entities.dart';
import '../repository/direction_sighting_repository.dart';

/// Logs one direction sighting on an open, eligible-category report
/// (DS2 — decisions 200-207).
class LogSightingUsecase {
  const LogSightingUsecase(this._repository);

  final DirectionSightingRepository _repository;

  Future<Either<Failure, SightOutcome>> call({
    required int reportId,
    required Direction direction,
  }) =>
      _repository.logSighting(reportId: reportId, direction: direction);
}
