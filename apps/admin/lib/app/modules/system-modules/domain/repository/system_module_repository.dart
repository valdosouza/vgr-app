import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../entity/system_module_entity.dart';

abstract class SystemModuleRepository {
  Future<Either<Failure, List<SystemModuleEntity>>> list();
  Future<Either<Failure, List<InterfaceOption>>> listInterfaceOptions();
  Future<Either<Failure, SystemModuleEntity>> create(SystemModuleEntity input);
  Future<Either<Failure, SystemModuleEntity>> update(SystemModuleEntity input);
  Future<Either<Failure, Unit>> delete(int id);
}
