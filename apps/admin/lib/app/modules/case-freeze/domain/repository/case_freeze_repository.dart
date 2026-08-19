import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/case_freeze_state_entity.dart';

/// Contract of the case-freeze data layer (decisions 141/142). Every
/// mutation answers nothing — the bloc reloads the state afterwards, so
/// the screen only ever renders what the SERVER says the case is.
abstract class CaseFreezeRepository {
  Future<Either<Failure, CaseFreezeStateEntity>> getState(int reportId);
  Future<Either<Failure, void>> freeze(int reportId, String reason);
  Future<Either<Failure, void>> requestUnfreeze(int reportId, String reason);
  Future<Either<Failure, void>> approveUnfreeze(int reportId);
}
