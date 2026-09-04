import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/rating_entities.dart';

/// Contract of the helper-rating write and the caller's own reputation
/// read (RT2 — decisions 48/178-189; API contract in
/// `api/docs/feature/rating.md`). Bound once in `AppModule` (like
/// `MyReportsStore`) because it is reachable from both the report module
/// (rating an offer) and the auth module (reading "my reputation").
abstract class RatingRepository {
  /// `POST /app-reports/:reportId/offers/:offerId/rating` — owner only
  /// (account match OR the report's clientKey, same ownership rule as
  /// every other app-plane report call). [score] is 1..5 (182). A
  /// transport failure falls back to the offline queue (181/28); an API
  /// rejection (404/409 ALREADY_RATED/409 RATING_CLOSED/422/451) is a
  /// Left and is NEVER enqueued — a retry would fail identically.
  Future<Either<Failure, RateOutcome>> rateOffer({
    required int reportId,
    required int offerId,
    required int score,
  });

  /// `GET /app-ratings/me` — the caller's OWN aggregate only (184/185);
  /// requires a real session (the API answers 401 anonymous, never
  /// optional). No per-case or per-other-user variant exists anywhere.
  Future<Either<Failure, ReputationEntity>> getMyReputation();
}
