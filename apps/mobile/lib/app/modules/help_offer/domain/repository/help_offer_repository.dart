import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/help_offer_entity.dart';

/// Contract of the help-offer data layer (spec task 09 as amended MA10 —
/// no listByReport: offers are only ever read inside the report view).
abstract class HelpOfferRepository {
  /// Posts the offer; Right carries the created helpOfferId.
  Future<Either<Failure, int>> submit(HelpOfferEntity offer);
}
