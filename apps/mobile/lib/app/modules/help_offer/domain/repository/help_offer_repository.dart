import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/help_offer_entity.dart';

/// Contract of the help-offer data layer (spec task 09 as amended MA10 —
/// no listByReport: offers are only ever read inside the report view).
abstract class HelpOfferRepository {
  /// Posts the offer; Right carries the created helpOfferId.
  Future<Either<Failure, int>> submit(HelpOfferEntity offer);

  /// Replaces the set of fronts of the caller's OWN offer while the
  /// report is open (decision 211); Right carries the set the server
  /// stored.
  Future<Either<Failure, Set<HelpType>>> updateTypes(int helpOfferId, Set<HelpType> helpTypes);
}
