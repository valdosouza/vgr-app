import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/rating_entities.dart';
import '../repository/rating_repository.dart';

/// Rates a resolved case's helper offer (RT2 — decisions 48/178-189).
class RateOfferUsecase {
  const RateOfferUsecase(this._repository);

  final RatingRepository _repository;

  Future<Either<Failure, RateOutcome>> call({
    required int reportId,
    required int offerId,
    required int score,
  }) =>
      _repository.rateOffer(reportId: reportId, offerId: offerId, score: score);
}
