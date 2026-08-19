import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/help_offer_entity.dart';
import '../repository/help_offer_repository.dart';

/// How the domain asks "did this device report this case?" without
/// knowing about MyReportsStore (amendment MA8): the mobile MVP has no
/// login, so clientKey possession (decision 134) IS the ownership signal.
typedef OwnsReport = Future<bool> Function(int reportId);

/// SubmitHelpOffer (spec task 09, decisions 6/10/20/34/35). The
/// self-dealing guard (20) runs HERE, before any network call — the
/// reporter never helps their own report; the server re-checks for
/// identified users.
class SubmitHelpOfferUsecase {
  const SubmitHelpOfferUsecase(this._repository, {required OwnsReport ownsReport})
      : _ownsReport = ownsReport;

  final HelpOfferRepository _repository;
  final OwnsReport _ownsReport;

  Future<Either<Failure, int>> call(HelpOfferEntity offer) async {
    if (await _ownsReport(offer.reportId)) {
      return const Left(Failure(
        message: 'The reporter cannot be a helper on their own report',
        code: 'SELF_DEALING',
      ));
    }
    return _repository.submit(offer);
  }
}
