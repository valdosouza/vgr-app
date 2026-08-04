import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/feed_item_entity.dart';
import '../gateway/location_gateway.dart';
import '../repository/report_repository.dart';

/// Paginated, ordered nearby feed (spec task 07).
class ListNearbyReportsUsecase {
  const ListNearbyReportsUsecase(this._repository);

  final ReportRepository _repository;

  Future<Either<Failure, FeedPageEntity>> call(
    GeoPoint position,
    int page,
    FeedOrder order,
  ) =>
      _repository.listNearby(position, page, order);
}
