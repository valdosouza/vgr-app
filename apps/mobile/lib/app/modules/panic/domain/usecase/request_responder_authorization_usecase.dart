import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/panic_repository.dart';

/// The now-reachable responder-authorization request (decision 190) — an
/// identified account's own request to join the Authorized Responder
/// pool. Eligibility is free human judgment by an admin, not codified.
class RequestResponderAuthorizationUsecase {
  const RequestResponderAuthorizationUsecase(this._repository);

  final PanicRepository _repository;

  Future<Either<Failure, void>> call() => _repository.requestResponderAuthorization();
}
