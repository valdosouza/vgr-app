import 'package:core/core.dart';
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../report/data/my_reports_store.dart';
import '../domain/entity/rating_entities.dart';
import '../domain/repository/rating_repository.dart';
import 'rating_queue_tasks.dart';

class RatingRepositoryImpl implements RatingRepository {
  RatingRepositoryImpl(
    this._apiClient,
    this._queue,
    this._myReports, {
    String Function()? clientKeyFactory,
  }) : _newClientKey = clientKeyFactory ?? (() => const Uuid().v4());

  final ApiClient _apiClient;
  final OfflineQueueService _queue;
  final MyReportsStore _myReports;
  final String Function() _newClientKey;

  /// Bearer ownership of the anonymous reporter (134) — header, never
  /// URL; absent for a helper/owner whose session rides `ApiClient`'s
  /// bearer.
  Future<Map<String, String>?> _ownerHeaders(int reportId) async {
    final clientKey = await _myReports.clientKeyOf(reportId);
    return clientKey == null ? null : {'x-client-key': clientKey};
  }

  @override
  Future<Either<Failure, RateOutcome>> rateOffer({
    required int reportId,
    required int offerId,
    required int score,
  }) async {
    // A fresh idempotency key per ATTEMPT (137): a genuine retry after a
    // real refusal is its own new attempt, never a replay of a stale one.
    final clientKey = _newClientKey();
    try {
      final response = await _apiClient.post(
        '/app-reports/$reportId/offers/$offerId/rating',
        {'score': score, 'clientKey': clientKey},
        headers: await _ownerHeaders(reportId),
      );
      return Right(RateOutcome.online(RatingEntity.fromJson(response)));
    } on Failure catch (failure) {
      // The API judged (404/409 ALREADY_RATED/409 RATING_CLOSED/422/451):
      // a queued retry would fail identically — surface it, never enqueue
      // (same rule as report submit/resolve).
      return Left(failure);
    } catch (_) {
      // Transport failure: the rating survives offline (decision 181 lets
      // it happen any time after resolution, including right when the
      // device just came back online) under this clientKey.
      await _queue.enqueue(RatingQueueTasks.submit, {
        'reportId': reportId,
        'offerId': offerId,
        'score': score,
        'clientKey': clientKey,
      });
      // Fire-and-forget: kick the flush now, the periodic retry self-heals.
      // ignore: unawaited_futures
      _queue.flush();
      return const Right(RateOutcome.queued());
    }
  }

  @override
  Future<Either<Failure, ReputationEntity>> getMyReputation() async {
    try {
      final response = await _apiClient.get('/app-ratings/me');
      return Right(ReputationEntity.fromJson(response));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(Failure(message: 'No connection', code: 'OFFLINE'));
    }
  }
}
