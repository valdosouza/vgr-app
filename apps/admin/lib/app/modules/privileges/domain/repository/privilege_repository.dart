import '../../../../shared/register/register_repository.dart';
import '../entity/privilege_entity.dart';

/// The privilege catalog as the register factory consumes it (PS2):
/// paged list filtered on `description` (PS0, decision 220) + writes.
abstract interface class PrivilegeRepository
    implements RegisterRepository<PrivilegeEntity, PrivilegeDraft> {}
