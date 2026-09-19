import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/help_offer_entity.dart';
import '../repository/help_offer_repository.dart';

/// UpdateHelpOfferTypes (decision 211): the helper who made the offer
/// swaps its whole set of fronts while the report is open. The server is
/// the authority on ownership (404 for anyone else's offer) and on the
/// case being open (422) — this side only refuses the one thing it can
/// know: an empty set (208, minimum one front).
class UpdateHelpOfferTypesUsecase {
  const UpdateHelpOfferTypesUsecase(this._repository);

  final HelpOfferRepository _repository;

  Future<Either<Failure, Set<HelpType>>> call(int helpOfferId, Set<HelpType> helpTypes) {
    if (helpTypes.isEmpty) {
      return Future.value(const Left(Failure(
        message: 'At least one help type is required',
        code: 'VALIDATION',
        statusCode: 422,
      )));
    }
    return _repository.updateTypes(helpOfferId, helpTypes);
  }
}
