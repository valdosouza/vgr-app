import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/app_session_entity.dart';
import '../repository/auth_repository.dart';

/// Rotates the persisted refresh token into a fresh session at app boot
/// (decision 122) — the app has no "keep me signed in" choice, so a
/// stored refresh token always means "restore this session".
class RestoreSessionUsecase {
  const RestoreSessionUsecase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AppSessionEntity>> call(String refreshToken) =>
      _repository.refresh(refreshToken);
}
