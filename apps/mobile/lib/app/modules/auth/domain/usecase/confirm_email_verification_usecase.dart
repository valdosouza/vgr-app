import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/auth_repository.dart';

class ConfirmEmailVerificationUsecase {
  const ConfirmEmailVerificationUsecase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, void>> call(String code) => _repository.confirmEmailVerification(code);
}
