import '../../../../shared/register/register_bloc.dart';
import '../../../../shared/register/register_lookup.dart';
import '../../domain/entity/system_module_entity.dart';

export '../../../../shared/register/register_bloc.dart';
export '../../../../shared/register/register_lookup.dart';

/// The menu-module screen's bloc IS the factory's (decision 217).
typedef SystemModuleBloc = RegisterBloc<SystemModuleEntity, SystemModuleDraft>;

/// The screen catalog the form's ordered checklist offers.
typedef InterfaceOptionsCubit = RegisterLookupCubit<InterfaceOption>;
