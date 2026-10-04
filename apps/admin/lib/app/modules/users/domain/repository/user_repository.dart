import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/register_repository.dart';
import '../entity/user_entity.dart';

/// Team users as the register factory consumes them (PS2): paged list
/// filtered on name / email (PS0, decision 220) + writes, plus the
/// privilege matrix of the kind-'R' `user_privileges` resource (93).
abstract interface class UserRepository implements RegisterRepository<UserEntity, UserDraft> {
  Future<Either<Failure, List<UserInterfaceGrants>>> privilegeMatrix(int userId);

  /// Grants the listed privileges on one screen and revokes the rest
  /// (the API implies VIEW on any grant — setes rule kept by name).
  Future<Either<Failure, Unit>> syncPrivileges(int userId, int interfaceId, List<int> privilegeIds);
}
