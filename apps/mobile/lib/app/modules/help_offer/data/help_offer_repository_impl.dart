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
        // Decision 213: only the list — the singular field no longer exists.
        'helpTypes': helpTypesToWire(offer.helpTypes),
        'anonymous': offer.anonymous,
      });
      return Right(response['helpOfferId'] as int);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }

  @override
  Future<Either<Failure, Set<HelpType>>> updateTypes(
    int helpOfferId,
    Set<HelpType> helpTypes,
  ) async {
    try {
      // Same posture as submit: a live edit on someone else's open case,
      // never queued — the session token rides on the client (app auth).
      final response = await _apiClient.put('/app-help-offers/$helpOfferId/types', {
        'helpTypes': helpTypesToWire(helpTypes),
      });
      final stored = (response['helpTypes'] as List<dynamic>? ?? const [])
          .map((w) => HelpType.fromWire(w as String))
          .whereType<HelpType>()
          .toSet();
      return Right(stored);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }
}
