import 'package:core/core.dart';
import 'package:dartz/dartz.dart';

import '../../../../shared/register/register_repository.dart';
import '../entity/interface_entity.dart';

/// The screen catalog as the register factory consumes it (PS3): paged
/// list filtered on description / i18n key (PS0, decision 220) + writes,
/// plus the privilege catalog the form's checklist offers.
abstract interface class InterfaceRepository
    implements RegisterRepository<InterfaceEntity, InterfaceDraft> {
  /// The whole privilege catalog (a handful of rows — the API's unpaged
  /// form of the list).
  Future<Either<Failure, List<PrivilegeOption>>> listPrivilegeOptions();
}
