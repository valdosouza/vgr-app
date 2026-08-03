import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/interface_entity.dart';

abstract class InterfaceRepository {
  Future<Either<Failure, List<InterfaceEntity>>> list();
  Future<Either<Failure, List<PrivilegeOption>>> listPrivilegeOptions();
  Future<Either<Failure, InterfaceEntity>> create(InterfaceEntity input);
  Future<Either<Failure, InterfaceEntity>> update(InterfaceEntity input);
  Future<Either<Failure, Unit>> delete(int id);
}
