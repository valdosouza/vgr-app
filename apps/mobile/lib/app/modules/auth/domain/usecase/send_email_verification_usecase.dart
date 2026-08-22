import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../repository/auth_repository.dart';

class SendEmailVerificationUsecase {
  const SendEmailVerificationUsecase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, void>> call() => _repository.sendEmailVerification();
}
