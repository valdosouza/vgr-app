import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/rating_entities.dart';
import '../repository/rating_repository.dart';

/// The signed-in helper's own aggregate reputation (decisions 184/185) —
/// nobody, including this usecase's caller, can read anyone else's.
class GetMyReputationUsecase {
  const GetMyReputationUsecase(this._repository);

  final RatingRepository _repository;

  Future<Either<Failure, ReputationEntity>> call() => _repository.getMyReputation();
}
