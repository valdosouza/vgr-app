import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/panic_entities.dart';
import '../repository/panic_repository.dart';

/// The cold trigger (decisions 62/65): no prior configuration, reachable
/// from a menu at any time.
class TriggerPanicAlertUsecase {
  const TriggerPanicAlertUsecase(this._repository);

  final PanicRepository _repository;

  Future<Either<Failure, TriggerOutcome>> call() => _repository.trigger();
}
