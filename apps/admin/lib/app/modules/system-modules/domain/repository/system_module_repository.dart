import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/register_repository.dart';
import '../entity/system_module_entity.dart';

/// Menu modules as the register factory consumes them (PS3): paged list
/// filtered on description (PS0, decision 220) + writes, plus the screen
/// catalog the form's ordered checklist offers.
abstract interface class SystemModuleRepository
    implements RegisterRepository<SystemModuleEntity, SystemModuleDraft> {
  /// Every screen (a few dozen rows — the API's unpaged form of the list).
  Future<Either<Failure, List<InterfaceOption>>> listInterfaceOptions();
}
