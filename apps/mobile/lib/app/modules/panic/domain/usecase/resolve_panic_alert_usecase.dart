import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/panic_repository.dart';

/// Only the triggerer resolves (decision 197) — the page dispatches this
/// only from the "I'm safe now" action on the active-alert status view.
class ResolvePanicAlertUsecase {
  const ResolvePanicAlertUsecase(this._repository);

  final PanicRepository _repository;

  Future<Either<Failure, void>> call(int alertId) => _repository.resolve(alertId);
}
