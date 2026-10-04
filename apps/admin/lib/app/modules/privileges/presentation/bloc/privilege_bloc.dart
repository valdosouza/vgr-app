import '../../../../shared/register/register_bloc.dart';
import '../../domain/entity/privilege_entity.dart';

export '../../../../shared/register/register_bloc.dart';

/// The privilege screen's bloc IS the factory's (decision 217) — an alias,
/// so the route's provider and `RegisterScreen`'s lookup are one type.
typedef PrivilegeBloc = RegisterBloc<PrivilegeEntity, PrivilegeDraft>;
