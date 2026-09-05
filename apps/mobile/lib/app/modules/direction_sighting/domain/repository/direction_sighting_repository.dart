import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/direction_sighting_entities.dart';

/// Contract of the DS2 write path (decisions 200-207; API contract in
/// `api/docs/feature/direction-sightings.md`). Bound module-scoped INSIDE
/// `ReportModule` (unlike `RatingRepository`/`PanicRepository`, which are
/// bound at `AppModule` level because 2+ modules need them): the ONLY
/// consumer here is `ReportDetailBloc`, which already lives in the
/// `report` module — no other module needs this repository, so there is
/// nothing to justify promoting it.
abstract class DirectionSightingRepository {
  /// `POST /app-direction-sightings` — any viewer of the OPEN report,
  /// anonymous or identified, EXCEPT the report's own identified reporter
  /// (decision 200 — enforced server-side; the app only hides the
  /// affordance for the owner as a UX courtesy, since it would always
  /// fail server-side anyway). A transport failure falls back to the
  /// offline queue (decision 28's same posture as every other write in
  /// this app); an API rejection (404/422
  /// DIRECTION_SIGHTING_NOT_ELIGIBLE/422 BUSINESS_RULE/451) is a Left and
  /// is NEVER enqueued — a retry would fail identically.
  Future<Either<Failure, SightOutcome>> logSighting({
    required int reportId,
    required Direction direction,
  });
}
