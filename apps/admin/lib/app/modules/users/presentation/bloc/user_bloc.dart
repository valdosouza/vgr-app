import '../../../../shared/register/register_bloc.dart';
import '../../domain/entity/user_entity.dart';

export '../../../../shared/register/register_bloc.dart';

/// The users screen's bloc IS the factory's (decision 217) — an alias, so
/// the route's provider and `RegisterScreen`'s lookup are one type.
typedef UserBloc = RegisterBloc<UserEntity, UserDraft>;
