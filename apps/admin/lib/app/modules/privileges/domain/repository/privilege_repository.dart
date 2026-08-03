import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/privilege_entity.dart';

abstract class PrivilegeRepository {
  Future<Either<Failure, List<PrivilegeEntity>>> list();
  Future<Either<Failure, PrivilegeEntity>> create(String description);
  Future<Either<Failure, PrivilegeEntity>> update(int id, String description);
  Future<Either<Failure, Unit>> delete(int id);
}
