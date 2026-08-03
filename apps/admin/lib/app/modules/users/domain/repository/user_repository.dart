import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/user_entity.dart';

abstract class UserRepository {
  Future<Either<Failure, List<UserEntity>>> list();
  Future<Either<Failure, UserEntity>> create({
    required String name,
    required String email,
    required String active,
    required String password,
  });

  /// Null/absent password keeps the current one (decision 75 flow).
  Future<Either<Failure, UserEntity>> update({
    required int id,
    required String name,
    required String email,
    required String active,
    String? password,
  });
  Future<Either<Failure, Unit>> delete(int id);

  Future<Either<Failure, List<UserInterfaceGrants>>> privilegeMatrix(int userId);

  /// Grants the listed privileges on one screen and revokes the rest
  /// (the API implies VIEW on any grant — setes rule kept by name).
  Future<Either<Failure, Unit>> syncPrivileges(int userId, int interfaceId, List<int> privilegeIds);
}
