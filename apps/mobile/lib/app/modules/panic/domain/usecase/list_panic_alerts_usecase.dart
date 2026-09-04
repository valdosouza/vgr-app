import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../report/domain/gateway/location_gateway.dart';
import '../entity/panic_entities.dart';
import '../repository/panic_repository.dart';

/// The responder's own alerts inbox (192 — polling only, no push).
class ListPanicAlertsUsecase {
  const ListPanicAlertsUsecase(this._repository);

  final PanicRepository _repository;

  Future<Either<Failure, List<ResponderAlertEntity>>> call({
    required int after,
    required int limit,
    required GeoPoint position,
  }) =>
      _repository.listAlerts(after: after, limit: limit, position: position);
}
