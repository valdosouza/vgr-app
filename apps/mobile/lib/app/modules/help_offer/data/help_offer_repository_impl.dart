import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../domain/entity/help_offer_entity.dart';
import '../domain/repository/help_offer_repository.dart';

class HelpOfferRepositoryImpl implements HelpOfferRepository {
  HelpOfferRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Either<Failure, int>> submit(HelpOfferEntity offer) async {
    try {
      // App plane (MA10). Unlike the report submit, an offer does NOT ride
      // the offline queue: it is a response to a live case someone else
      // owns, and a stale queued offer helps nobody — the user retries.
      final response = await _apiClient.post('/app-help-offers', {
        'reportId': offer.reportId,
        'helpType': offer.helpType.wire,
        'anonymous': offer.anonymous,
      });
      return Right(response['helpOfferId'] as int);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }
}
