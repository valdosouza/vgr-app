import '../../../../shared/register/register_bloc.dart';
import '../../../../shared/register/register_lookup.dart';
import '../../domain/entity/interface_entity.dart';

export '../../../../shared/register/register_bloc.dart';
export '../../../../shared/register/register_lookup.dart';

/// The interfaces screen's bloc IS the factory's (decision 217).
typedef InterfaceBloc = RegisterBloc<InterfaceEntity, InterfaceDraft>;

/// The privilege catalog the form's checklist offers.
typedef PrivilegeOptionsCubit = RegisterLookupCubit<PrivilegeOption>;
