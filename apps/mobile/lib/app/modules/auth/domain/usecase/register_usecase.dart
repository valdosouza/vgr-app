import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/app_session_entity.dart';
import '../repository/auth_repository.dart';

class RegisterUsecase {
  const RegisterUsecase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AppSessionEntity>> call({
    required String displayName,
    required String email,
    required String password,
    required String consentVersion,
  }) =>
      _repository.register(
        displayName: displayName,
        email: email,
        password: password,
        consentVersion: consentVersion,
      );
}
