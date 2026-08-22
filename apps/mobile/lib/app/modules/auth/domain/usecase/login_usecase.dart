import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/app_session_entity.dart';
import '../repository/auth_repository.dart';

class LoginUsecase {
  const LoginUsecase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AppSessionEntity>> call({
    required String email,
    required String password,
    String? totpCode,
  }) =>
      _repository.login(email: email, password: password, totpCode: totpCode);
}
